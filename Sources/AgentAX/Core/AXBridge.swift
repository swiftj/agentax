import Foundation
import ApplicationServices
import AppKit

/// Wraps the macOS Accessibility C API into Swift, providing tree capture and O(1) element lookup.
@MainActor
public final class AXBridge {

    /// Thread-safe store mapping UUID -> live AXUIElement for O(1) action resolution.
    public let elementStore = ElementStore()

    public init() {}

    // MARK: - Permissions

    /// Returns true if this process has Accessibility permission.
    public func checkPermissions() -> Bool {
        AXIsProcessTrusted()
    }

    // MARK: - State Capture

    /// Captures the full AX tree for all running apps (or a single app by name).
    public func captureState(
        appName: String? = nil,
        depthLimit: Int = AXTypes.defaultDepthLimit,
        timeout: TimeInterval = AXTypes.defaultTimeout
    ) -> SystemState {
        let start = Date()
        elementStore.clear()

        let apps = getRunningApps()
        var processes: [ProcessInfo] = []

        for app in apps {
            if let name = appName, app.name != name {
                continue
            }
            let processInfo = captureAppState(
                pid: app.pid,
                name: app.name,
                bundleID: app.bundleID,
                isActive: app.isActive,
                isHidden: app.isHidden,
                depthLimit: depthLimit,
                timeout: timeout
            )
            processes.append(processInfo)
        }

        let elapsed = Date().timeIntervalSince(start) * 1000
        return SystemState(
            processes: processes,
            capturedAt: start,
            captureTimeMs: elapsed
        )
    }

    /// Captures the AX tree for a single app by PID.
    public func captureAppState(
        pid: Int32,
        depthLimit: Int = AXTypes.defaultDepthLimit,
        timeout: TimeInterval = AXTypes.defaultTimeout
    ) -> ProcessInfo {
        let apps = getRunningApps()
        let match = apps.first { $0.pid == pid }
        return captureAppState(
            pid: pid,
            name: match?.name ?? "Unknown",
            bundleID: match?.bundleID,
            isActive: match?.isActive ?? false,
            isHidden: match?.isHidden ?? false,
            depthLimit: depthLimit,
            timeout: timeout
        )
    }

    /// O(1) lookup of a live AXUIElement by its UUID.
    public func findElement(id: UUID) -> AXUIElement? {
        elementStore.find(id: id)
    }

    /// Clears all stored element references.
    public func clearRefs() {
        elementStore.clear()
    }

    // MARK: - Internal: App Enumeration

    private func getRunningApps() -> [(pid: Int32, name: String, bundleID: String?, isActive: Bool, isHidden: Bool)] {
        let workspace = NSWorkspace.shared
        return workspace.runningApplications
            .filter { $0.activationPolicy == .regular }
            .map { app in
                (
                    pid: app.processIdentifier,
                    name: app.localizedName ?? "Unknown",
                    bundleID: app.bundleIdentifier,
                    isActive: app.isActive,
                    isHidden: app.isHidden
                )
            }
    }

    // MARK: - Internal: App Capture

    private func captureAppState(
        pid: Int32,
        name: String,
        bundleID: String?,
        isActive: Bool,
        isHidden: Bool,
        depthLimit: Int,
        timeout: TimeInterval
    ) -> ProcessInfo {
        let appRef = AXUIElementCreateApplication(pid)
        let startTime = Date()

        var windows: [UIElement] = []

        // Capture windows — try AXWindows first, filtering out non-window elements
        // (some apps return AXApplication elements in their AXWindows attribute)
        var windowRefs: [AXUIElement] = []
        if let windowElements = getChildElements(appRef, attribute: AXTypes.windows) {
            for elem in windowElements {
                let role = getStringAttribute(elem, AXTypes.role)
                // Accept AXWindow and any non-AXApplication element (sheets, drawers, etc.)
                if role != AXTypes.applicationRole {
                    windowRefs.append(elem)
                }
            }
        }

        // Fallback: if AXWindows yielded no usable windows, try AXMainWindow/AXFocusedWindow
        if windowRefs.isEmpty {
            if let mainWindow: AXUIElement = getAttribute(appRef, AXTypes.mainWindow) as CFTypeRef? as! AXUIElement? {
                windowRefs.append(mainWindow)
            }
            if let focusedWindow: AXUIElement = getAttribute(appRef, AXTypes.focusedWindow) as CFTypeRef? as! AXUIElement? {
                windowRefs.append(focusedWindow)
            }
        }

        // Last resort: scan AXChildren for window-role elements
        if windowRefs.isEmpty {
            for child in getChildren(appRef) {
                if let role = getStringAttribute(child, AXTypes.role), role == AXTypes.windowRole {
                    windowRefs.append(child)
                }
            }
        }

        for windowElement in windowRefs {
            if let uiElement = traverseElement(
                windowElement,
                appRef: appRef,
                depth: 0,
                depthLimit: depthLimit,
                isMenuBar: false,
                startTime: startTime,
                timeout: timeout
            ) {
                windows.append(uiElement)
            }
        }

        // Capture menu bar (with shorter timeout)
        if let menuBar: AXUIElement = getAttribute(appRef, AXTypes.menuBar) as CFTypeRef? as! AXUIElement? {
            if let menuElement = traverseElement(
                menuBar,
                appRef: appRef,
                depth: 0,
                depthLimit: depthLimit,
                isMenuBar: true,
                startTime: Date(),
                timeout: AXTypes.menuBarTimeout
            ) {
                windows.append(menuElement)
            }
        }

        return ProcessInfo(
            pid: pid,
            name: name,
            bundleIdentifier: bundleID,
            isActive: isActive,
            isHidden: isHidden,
            windows: windows
        )
    }

    // MARK: - Internal: Tree Traversal

    private func traverseElement(
        _ element: AXUIElement,
        appRef: AXUIElement,
        depth: Int,
        depthLimit: Int,
        isMenuBar: Bool,
        startTime: Date,
        timeout: TimeInterval
    ) -> UIElement? {
        // Check depth limit
        guard depth < depthLimit else { return nil }

        // Check timeout
        let elapsed = Date().timeIntervalSince(startTime)
        guard elapsed < timeout else { return nil }

        // Get role (required)
        guard let role = getStringAttribute(element, AXTypes.role) else {
            return nil
        }

        // Cycle detection: skip children that point back to the application element
        // (some apps return AXApplication as a child of itself, causing infinite recursion)
        if depth > 0 && role == AXTypes.applicationRole {
            return nil
        }

        let title = getStringAttribute(element, AXTypes.title)
        let value: String? = {
            guard let raw = getAttribute(element, AXTypes.value) else { return nil }
            if let str = raw as? String { return str }
            if let num = raw as? NSNumber { return num.stringValue }
            return "\(raw)"
        }()
        let identifier = getStringAttribute(element, AXTypes.identifier)
        let label = getStringAttribute(element, AXTypes.label)
        let roleDescription = getStringAttribute(element, AXTypes.roleDescription)
        let position = getPosition(element)
        let size = getSize(element)
        let isEnabled = getBoolAttribute(element, AXTypes.enabled)
        let isFocused = getBoolAttribute(element, AXTypes.focused)
        let actions = getActions(element)
        let customContent = getCustomContent(element)

        // Skip zero-size elements that have no children (invisible leaves)
        let hasZeroSize = size.map { $0.width == 0 && $0.height == 0 } ?? false

        // Recurse into children
        var childElements: [UIElement] = []
        let childRefs = getChildren(element)
        for childRef in childRefs {
            if let childUI = traverseElement(
                childRef,
                appRef: appRef,
                depth: depth + 1,
                depthLimit: depthLimit,
                isMenuBar: isMenuBar,
                startTime: startTime,
                timeout: timeout
            ) {
                childElements.append(childUI)
            }
        }

        // Skip zero-size leaf nodes
        if hasZeroSize && childElements.isEmpty {
            return nil
        }

        let elementID = UUID()
        elementStore.store(id: elementID, ref: element)

        return UIElement(
            id: elementID,
            role: role,
            title: title,
            value: value,
            identifier: identifier,
            label: label,
            roleDescription: roleDescription,
            position: position,
            size: size,
            isEnabled: isEnabled,
            isFocused: isFocused,
            actions: actions,
            customContent: customContent,
            children: childElements,
            depth: depth
        )
    }

    // MARK: - Internal: AX Attribute Helpers

    private func getAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else { return nil }
        return value
    }

    private func getStringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        guard let value = getAttribute(element, attribute) else { return nil }
        return value as? String
    }

    private func getBoolAttribute(_ element: AXUIElement, _ attribute: String) -> Bool {
        guard let value = getAttribute(element, attribute) else { return false }
        if let boolVal = value as? Bool { return boolVal }
        if let numVal = value as? NSNumber { return numVal.boolValue }
        return false
    }

    private func getPosition(_ element: AXUIElement) -> CGPoint? {
        guard let value = getAttribute(element, AXTypes.position) else { return nil }
        // AXPosition is stored as an AXValue of type .cgPoint
        var point = CGPoint.zero
        guard AXValueGetValue(value as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    private func getSize(_ element: AXUIElement) -> CGSize? {
        guard let value = getAttribute(element, AXTypes.size) else { return nil }
        // AXSize is stored as an AXValue of type .cgSize
        var size = CGSize.zero
        guard AXValueGetValue(value as! AXValue, .cgSize, &size) else { return nil }
        return size
    }

    private func getActions(_ element: AXUIElement) -> [String] {
        var names: CFArray?
        let result = AXUIElementCopyActionNames(element, &names)
        guard result == .success, let actionNames = names as? [String] else { return [] }
        return actionNames
    }

    private func getChildren(_ element: AXUIElement) -> [AXUIElement] {
        guard let value = getAttribute(element, AXTypes.children) else { return [] }
        guard let children = value as? [AXUIElement] else { return [] }
        return children
    }

    /// Get child elements for a specific attribute (e.g., AXWindows).
    private func getChildElements(_ element: AXUIElement, attribute: String) -> [AXUIElement]? {
        guard let value = getAttribute(element, attribute) else { return nil }
        return value as? [AXUIElement]
    }

    /// Extract custom accessibility content (used by RealityKit AccessibilityComponent).
    private func getCustomContent(_ element: AXUIElement) -> [String: String] {
        // AXCustomContent is an array of dictionaries with "label" and "value" keys
        guard let value = getAttribute(element, "AXCustomContent") else { return [:] }
        guard let contentArray = value as? [[String: Any]] else { return [:] }

        var result: [String: String] = [:]
        for item in contentArray {
            if let key = item["label"] as? String,
               let val = item["value"] as? String {
                result[key] = val
            }
        }
        return result
    }
}
