import Foundation
import ApplicationServices
import CoreGraphics

/// Result of performing an action on a UI element.
public struct ActionResult: Sendable, Codable {
    public let success: Bool
    public let elementId: UUID
    public let action: String
    public let message: String?

    public init(success: Bool, elementId: UUID, action: String, message: String? = nil) {
        self.success = success
        self.elementId = elementId
        self.action = action
        self.message = message
    }
}

/// Direction for scroll actions.
public enum ScrollDirection: String, Sendable, Codable, CaseIterable {
    case up, down, left, right
}

/// Executes actions on UI elements via their live AXUIElement references.
///
/// Elements are looked up from `ElementStore` by UUID, giving O(1) resolution
/// without re-traversing the AX tree.
@MainActor
public final class ActionExecutor {
    private let elementStore: ElementStore

    public init(elementStore: ElementStore) {
        self.elementStore = elementStore
    }

    // MARK: - Public API

    /// Click an element via the AXPress action.
    public func click(elementId: UUID) throws -> ActionResult {
        try performAction(elementId: elementId, action: AXTypes.pressAction)
    }

    /// Set the value of a text field or other value-holding element.
    public func setValue(elementId: UUID, value: String) throws -> ActionResult {
        let ref = try resolveElement(id: elementId)

        let result = AXUIElementSetAttributeValue(
            ref,
            AXTypes.value as CFString,
            value as CFTypeRef
        )

        guard result == .success else {
            return ActionResult(
                success: false,
                elementId: elementId,
                action: "setValue",
                message: "AXError code \(result.rawValue) setting value"
            )
        }

        return ActionResult(
            success: true,
            elementId: elementId,
            action: "setValue",
            message: "Value set to: \(value)"
        )
    }

    /// Perform any named AX action on an element (e.g., AXPress, AXConfirm, AXShowMenu).
    ///
    /// Custom actions (from SwiftUI `.accessibilityAction(named:)`) are returned by
    /// `AXUIElementCopyActionNames` as description strings like
    /// `"Name:Open Actions\n    Target:0x0\n    Selector:(null)"`.
    /// This method matches user-friendly names (e.g. "Open Actions") against both
    /// exact action strings and the `Name:` prefix of custom action descriptions.
    ///
    /// When `fallbackToAncestor` is true (default) and the target element doesn't
    /// support the requested action, walks up the AX parent chain to find the nearest
    /// ancestor that does. This handles the common case of clicking a label/text inside
    /// a button, row, or cell.
    public func performAction(
        elementId: UUID,
        action: String,
        fallbackToAncestor: Bool = true
    ) throws -> ActionResult {
        let ref = try resolveElement(id: elementId)

        // Try the target element first
        if let resolved = resolveAction(action, on: ref) {
            return try executeAction(resolved, on: ref, elementId: elementId, userAction: action)
        }

        // Walk up ancestors if fallback is enabled
        if fallbackToAncestor {
            var current = ref
            var depth = 0
            let maxDepth = 10 // Don't walk too far up
            while depth < maxDepth {
                var parentRef: CFTypeRef?
                let parentResult = AXUIElementCopyAttributeValue(
                    current, AXTypes.parent as CFString, &parentRef
                )
                guard parentResult == .success, let parent = parentRef else { break }
                let parentElement = parent as! AXUIElement
                if let resolved = resolveAction(action, on: parentElement) {
                    var result = try executeAction(
                        resolved, on: parentElement, elementId: elementId, userAction: action
                    )
                    let ancestorRole = getRole(parentElement) ?? "unknown"
                    result = ActionResult(
                        success: result.success,
                        elementId: elementId,
                        action: action,
                        message: (result.message ?? "")
                            + (result.success
                                ? " (action performed on ancestor \(ancestorRole) \(depth + 1) level\(depth == 0 ? "" : "s") up)"
                                : "")
                    )
                    return result
                }
                current = parentElement
                depth += 1
            }
        }

        // No element in the chain supports this action
        let displayNames = getActionDisplayNames(ref)
        throw AXError.actionNotSupported(
            "\(action) not in supported actions: \(displayNames.joined(separator: ", "))"
        )
    }

    // MARK: - Action Resolution Helpers

    /// Resolve a user-provided action name against an element's supported actions.
    /// Returns the raw AX action string to pass to `AXUIElementPerformAction`, or nil.
    private func resolveAction(_ action: String, on ref: AXUIElement) -> String? {
        var actionsRef: CFArray?
        let listResult = AXUIElementCopyActionNames(ref, &actionsRef)
        guard listResult == .success, let actions = actionsRef as? [String] else { return nil }

        // Exact match (standard AX actions like "AXPress")
        if actions.contains(action) { return action }

        // Custom action match by Name: prefix
        if let match = actions.first(where: { $0.hasPrefix("Name:\(action)\n") || $0 == "Name:\(action)" }) {
            return match
        }

        return nil
    }

    /// Execute a resolved action on an AXUIElement.
    private func executeAction(
        _ resolvedAction: String,
        on ref: AXUIElement,
        elementId: UUID,
        userAction: String
    ) throws -> ActionResult {
        let result = AXUIElementPerformAction(ref, resolvedAction as CFString)
        guard result == .success else {
            return ActionResult(
                success: false,
                elementId: elementId,
                action: userAction,
                message: "AXError code \(result.rawValue) performing \(userAction)"
            )
        }
        return ActionResult(success: true, elementId: elementId, action: userAction, message: nil)
    }

    /// Get clean display names for an element's supported actions.
    private func getActionDisplayNames(_ ref: AXUIElement) -> [String] {
        var actionsRef: CFArray?
        let listResult = AXUIElementCopyActionNames(ref, &actionsRef)
        guard listResult == .success, let actions = actionsRef as? [String] else { return [] }
        return actions.map { name in
            if let range = name.range(of: "\n") {
                return String(name[name.startIndex..<range.lowerBound])
            }
            return name
        }
    }

    /// Get the role of an AXUIElement.
    private func getRole(_ ref: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(ref, AXTypes.role as CFString, &value)
        guard result == .success else { return nil }
        return value as? String
    }

    /// Scroll an element in the given direction.
    ///
    /// Uses CGEvent scroll wheel events posted at the element's center position.
    public func scroll(elementId: UUID, direction: ScrollDirection, amount: Int = 3) throws -> ActionResult {
        let ref = try resolveElement(id: elementId)

        // Get element position and size to find center point
        let center = try elementCenter(ref: ref, elementId: elementId)

        // Move mouse to element center first
        if let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                                   mouseCursorPosition: center, mouseButton: .left) {
            moveEvent.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.05)
        }

        // Create scroll event
        let (deltaY, deltaX): (Int32, Int32) = switch direction {
        case .up:    (Int32(amount), 0)
        case .down:  (Int32(-amount), 0)
        case .left:  (0, Int32(amount))
        case .right: (0, Int32(-amount))
        }

        guard let scrollEvent = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 2,
            wheel1: deltaY,
            wheel2: deltaX,
            wheel3: 0
        ) else {
            return ActionResult(
                success: false,
                elementId: elementId,
                action: "scroll.\(direction.rawValue)",
                message: "Failed to create scroll event"
            )
        }

        scrollEvent.post(tap: .cghidEventTap)

        return ActionResult(
            success: true,
            elementId: elementId,
            action: "scroll.\(direction.rawValue)",
            message: "Scrolled \(direction.rawValue) by \(amount)"
        )
    }

    // MARK: - Private Helpers

    /// Resolve a UUID to a live AXUIElement, throwing if not found.
    private func resolveElement(id: UUID) throws -> AXUIElement {
        guard let ref = elementStore.find(id: id) else {
            throw AXError.elementNotFound(id.uuidString)
        }
        return ref
    }

    /// Get the center point of an AXUIElement from its position and size attributes.
    private func elementCenter(ref: AXUIElement, elementId: UUID) throws -> CGPoint {
        var posValue: CFTypeRef?
        var sizeValue: CFTypeRef?

        let posResult = AXUIElementCopyAttributeValue(ref, AXTypes.position as CFString, &posValue)
        let sizeResult = AXUIElementCopyAttributeValue(ref, AXTypes.size as CFString, &sizeValue)

        guard posResult == .success, sizeResult == .success,
              let posVal = posValue, let sizeVal = sizeValue else {
            throw AXError.attributeError(
                "Cannot read position/size for element \(elementId.uuidString)"
            )
        }

        var point = CGPoint.zero
        var size = CGSize.zero

        guard AXValueGetValue(posVal as! AXValue, .cgPoint, &point),
              AXValueGetValue(sizeVal as! AXValue, .cgSize, &size) else {
            throw AXError.attributeError(
                "Cannot convert position/size values for element \(elementId.uuidString)"
            )
        }

        return CGPoint(x: point.x + size.width / 2, y: point.y + size.height / 2)
    }
}
