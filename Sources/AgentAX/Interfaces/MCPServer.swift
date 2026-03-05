import Foundation
import MCP
import AppKit
import ApplicationServices

/// Stateful MCP server for agentax. Holds a persistent AXBridge so the UUID->AXUIElement
/// map survives across tool invocations.
@MainActor
public final class AgentAXMCPServer {
    private let bridge: AXBridge
    private let actionExecutor: ActionExecutor
    private let inputEvents: InputEventGenerator
    private let server: Server

    public init() {
        self.bridge = AXBridge()
        self.actionExecutor = ActionExecutor(elementStore: bridge.elementStore)
        self.inputEvents = InputEventGenerator()
        self.server = Server(
            name: "agentax",
            version: agentaxVersion,
            capabilities: .init(
                resources: .init(subscribe: false, listChanged: false),
                tools: .init(listChanged: false)
            )
        )
    }

    // MARK: - Public API

    /// Start the MCP server on stdio transport. Blocks until the server stops.
    public func start() async throws {
        await registerToolHandlers()
        await registerResourceHandlers()
        let transport = StdioTransport()
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }

    // MARK: - Tool Registration

    private func registerToolHandlers() async {
        await server.withMethodHandler(ListTools.self) { _ in
            .init(tools: AgentAXMCPServer.allTools)
        }

        await server.withMethodHandler(CallTool.self) { [self] params in
            await self.handleToolCall(params)
        }
    }

    private func registerResourceHandlers() async {
        await server.withMethodHandler(ListResources.self) { _ in
            .init(resources: [
                Resource(
                    name: "Current UI State",
                    uri: "ui://state/current",
                    description: "Shallow overview of all running apps and their windows",
                    mimeType: "text/plain"
                ),
            ])
        }

        await server.withMethodHandler(ListResourceTemplates.self) { _ in
            .init(templates: [
                Resource.Template(
                    uriTemplate: "ui://state/process/{name}",
                    name: "Process UI State",
                    description: "Deep AX tree for a specific application by name",
                    mimeType: "text/plain"
                ),
            ])
        }

        await server.withMethodHandler(ReadResource.self) { [self] params in
            await self.handleResourceRead(params)
        }
    }

    // MARK: - Tool Dispatch

    @MainActor
    private func handleToolCall(_ params: CallTool.Parameters) -> CallTool.Result {
        do {
            switch params.name {
            case "find_elements":
                return try handleFindElements(params)
            case "find_elements_in_app":
                return try handleFindElementsInApp(params)
            case "click_element_by_selector":
                return try handleClickElementBySelector(params)
            case "click_at_position":
                return try handleClickAtPosition(params)
            case "type_text_to_element_by_selector":
                return try handleTypeTextToElementBySelector(params)
            case "get_element_details":
                return try handleGetElementDetails(params)
            case "list_running_applications":
                return try handleListRunningApplications(params)
            case "get_app_overview":
                return try handleGetAppOverview(params)
            case "check_accessibility_permissions":
                return handleCheckAccessibilityPermissions()
            case "get_frontmost_app":
                return try handleGetFrontmostApp(params)
            case "scroll_element":
                return try handleScrollElement(params)
            case "activate_app":
                return try handleActivateApp(params)
            case "get_menu_bar_items":
                return try handleGetMenuBarItems(params)
            case "dump_tree":
                return try handleDumpTree(params)
            case "wait_for_element":
                return try handleWaitForElement(params)
            case "assert_element_state":
                return try handleAssertElementState(params)
            case "get_element_custom_content":
                return try handleGetElementCustomContent(params)
            case "snapshot_diff":
                return try handleSnapshotDiff(params)
            default:
                return .init(content: [.text("Unknown tool: \(params.name)")], isError: true)
            }
        } catch {
            return .init(content: [.text("Error: \(error)")], isError: true)
        }
    }

    // MARK: - Resource Dispatch

    @MainActor
    private func handleResourceRead(_ params: ReadResource.Parameters) -> ReadResource.Result {
        let uri = params.uri

        if uri == "ui://state/current" {
            // Shallow overview — capture with depth limit 2 (apps + windows only)
            let state = bridge.captureState(depthLimit: 2)
            let formatter = OutputFormatter(format: .toon)
            let text = (try? formatter.format(state)) ?? "Error formatting state"
            return .init(contents: [.text(text, uri: uri, mimeType: "text/plain")])
        }

        if uri.hasPrefix("ui://state/process/") {
            let name = String(uri.dropFirst("ui://state/process/".count))
            let decodedName = name.removingPercentEncoding ?? name
            let state = bridge.captureState(appName: decodedName)
            let formatter = OutputFormatter(format: .toon)
            let text = (try? formatter.format(state)) ?? "Error formatting state"
            return .init(contents: [.text(text, uri: uri, mimeType: "text/plain")])
        }

        return .init(contents: [.text("Unknown resource: \(uri)", uri: uri, mimeType: "text/plain")])
    }

    // MARK: - Tool Implementations

    // 1. find_elements
    private func handleFindElements(_ params: CallTool.Parameters) throws -> CallTool.Result {
        guard let selectorStr = params.arguments?["selector"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: selector")], isError: true)
        }
        let app = params.arguments?["app"]?.stringValue
        let format = resolveFormat(params)

        let state = bridge.captureState(appName: app)
        let selector = try JSONPathSelector(selectorStr)
        let matches = selector.execute(on: state)

        let formatter = OutputFormatter(format: format)
        let result = try formatter.format(matches)
        return .init(content: [.text(result)])
    }

    // 2. find_elements_in_app
    private func handleFindElementsInApp(_ params: CallTool.Parameters) throws -> CallTool.Result {
        guard let appName = params.arguments?["app_name"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: app_name")], isError: true)
        }
        let format = resolveFormat(params)

        // Deeper traversal for single app
        let state = bridge.captureState(appName: appName)

        if let selectorStr = params.arguments?["selector"]?.stringValue {
            let selector = try JSONPathSelector(selectorStr)
            let matches = selector.execute(on: state)
            let formatter = OutputFormatter(format: format)
            let result = try formatter.format(matches)
            return .init(content: [.text(result)])
        } else {
            let formatter = OutputFormatter(format: format)
            let result = try formatter.format(state)
            return .init(content: [.text(result)])
        }
    }

    // 3. click_element_by_selector
    private func handleClickElementBySelector(_ params: CallTool.Parameters) throws -> CallTool.Result {
        guard let selectorStr = params.arguments?["selector"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: selector")], isError: true)
        }
        let app = params.arguments?["app"]?.stringValue

        let state = bridge.captureState(appName: app)
        let selector = try JSONPathSelector(selectorStr)
        let matches = selector.execute(on: state)

        guard let first = matches.first else {
            return .init(content: [.text("No element found matching selector: \(selectorStr)")], isError: true)
        }

        let result = try actionExecutor.click(elementId: first.id)
        return .init(content: [.text(formatActionResult(result))])
    }

    // 4. click_at_position
    private func handleClickAtPosition(_ params: CallTool.Parameters) throws -> CallTool.Result {
        guard let x = params.arguments?["x"]?.doubleValue ?? params.arguments?["x"]?.intValue.map(Double.init) else {
            return .init(content: [.text("Missing required parameter: x")], isError: true)
        }
        guard let y = params.arguments?["y"]?.doubleValue ?? params.arguments?["y"]?.intValue.map(Double.init) else {
            return .init(content: [.text("Missing required parameter: y")], isError: true)
        }

        try inputEvents.clickAtPosition(x: x, y: y)
        return .init(content: [.text("Clicked at position (\(x), \(y))")])
    }

    // 5. type_text_to_element_by_selector
    private func handleTypeTextToElementBySelector(_ params: CallTool.Parameters) throws -> CallTool.Result {
        guard let selectorStr = params.arguments?["selector"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: selector")], isError: true)
        }
        guard let text = params.arguments?["text"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: text")], isError: true)
        }
        let app = params.arguments?["app"]?.stringValue

        let state = bridge.captureState(appName: app)
        let selector = try JSONPathSelector(selectorStr)
        let matches = selector.execute(on: state)

        guard let first = matches.first else {
            return .init(content: [.text("No element found matching selector: \(selectorStr)")], isError: true)
        }

        let result = try actionExecutor.setValue(elementId: first.id, value: text)
        return .init(content: [.text(formatActionResult(result))])
    }

    // 6. get_element_details
    private func handleGetElementDetails(_ params: CallTool.Parameters) throws -> CallTool.Result {
        guard let idStr = params.arguments?["element_id"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: element_id")], isError: true)
        }
        guard let elementId = UUID(uuidString: idStr) else {
            return .init(content: [.text("Invalid UUID: \(idStr)")], isError: true)
        }
        let format = resolveFormat(params)

        // Look for the element in the last captured state by searching the element store
        // We need to recapture to get the UIElement model data
        let state = bridge.captureState()
        let element = findElementById(elementId, in: state)

        guard let element else {
            return .init(content: [.text("Element not found: \(idStr)")], isError: true)
        }

        let formatter = OutputFormatter(format: format)
        let result = try formatter.format(element)
        return .init(content: [.text(result)])
    }

    // 7. list_running_applications
    private func handleListRunningApplications(_ params: CallTool.Parameters) throws -> CallTool.Result {
        let format = resolveFormat(params)

        let state = bridge.captureState(depthLimit: 0)
        let formatter = OutputFormatter(format: format)
        let result = try formatter.format(state.processes)
        return .init(content: [.text(result)])
    }

    // 8. get_app_overview
    private func handleGetAppOverview(_ params: CallTool.Parameters) throws -> CallTool.Result {
        let format = resolveFormat(params)

        // Shallow capture — depth 2 gives apps + top-level windows
        let state = bridge.captureState(depthLimit: 2)
        let formatter = OutputFormatter(format: format)
        let result = try formatter.format(state)
        return .init(content: [.text(result)])
    }

    // 9. check_accessibility_permissions
    private func handleCheckAccessibilityPermissions() -> CallTool.Result {
        let trusted = bridge.checkPermissions()
        let encoder = TOONEncoder()
        let result = encoder.encode([
            (key: "trusted", value: "\(trusted)"),
            (key: "message", value: trusted
                ? "Accessibility permission granted"
                : "Accessibility permission DENIED. Enable in System Settings > Privacy & Security > Accessibility."
            ),
        ])
        return .init(content: [.text(result)])
    }

    // 10. get_frontmost_app
    private func handleGetFrontmostApp(_ params: CallTool.Parameters) throws -> CallTool.Result {
        let format = resolveFormat(params)

        let state = bridge.captureState()
        guard let frontmost = state.processes.first(where: { $0.isActive }) else {
            return .init(content: [.text("No frontmost application found")], isError: true)
        }

        let formatter = OutputFormatter(format: format)
        // Create a SystemState with just the frontmost app for full formatting
        let frontmostState = SystemState(
            processes: [frontmost],
            capturedAt: state.capturedAt,
            captureTimeMs: state.captureTimeMs
        )
        let result = try formatter.format(frontmostState)
        return .init(content: [.text(result)])
    }

    // 11. scroll_element
    private func handleScrollElement(_ params: CallTool.Parameters) throws -> CallTool.Result {
        guard let selectorStr = params.arguments?["selector"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: selector")], isError: true)
        }
        guard let dirStr = params.arguments?["direction"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: direction")], isError: true)
        }
        guard let direction = ScrollDirection(rawValue: dirStr.lowercased()) else {
            return .init(content: [.text("Invalid direction: \(dirStr). Use: up, down, left, right")], isError: true)
        }
        let amount = params.arguments?["amount"]?.intValue ?? 3
        let app = params.arguments?["app"]?.stringValue

        let state = bridge.captureState(appName: app)
        let selector = try JSONPathSelector(selectorStr)
        let matches = selector.execute(on: state)

        guard let first = matches.first else {
            return .init(content: [.text("No element found matching selector: \(selectorStr)")], isError: true)
        }

        let result = try actionExecutor.scroll(elementId: first.id, direction: direction, amount: amount)
        return .init(content: [.text(formatActionResult(result))])
    }

    // 12. activate_app
    private func handleActivateApp(_ params: CallTool.Parameters) throws -> CallTool.Result {
        let name = params.arguments?["name"]?.stringValue
        let bundleId = params.arguments?["bundle_id"]?.stringValue

        guard name != nil || bundleId != nil else {
            return .init(content: [.text("Missing required parameter: name or bundle_id")], isError: true)
        }

        let workspace = NSWorkspace.shared
        let app = workspace.runningApplications.first { runningApp in
            if let name, runningApp.localizedName == name { return true }
            if let bundleId, runningApp.bundleIdentifier == bundleId { return true }
            return false
        }

        guard let app else {
            let identifier = name ?? bundleId ?? "unknown"
            return .init(content: [.text("Application not found: \(identifier)")], isError: true)
        }

        app.activate()
        let appName = app.localizedName ?? app.bundleIdentifier ?? "unknown"
        return .init(content: [.text("Activated application: \(appName)")])
    }

    // 13. get_menu_bar_items
    private func handleGetMenuBarItems(_ params: CallTool.Parameters) throws -> CallTool.Result {
        guard let appName = params.arguments?["app_name"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: app_name")], isError: true)
        }
        let format = resolveFormat(params)

        let state = bridge.captureState(appName: appName)
        // Menu bar items are captured as part of the app's windows array
        // (the menu bar element is appended after regular windows in AXBridge)
        // Filter for menu bar and its items
        let menuBarElements = state.processes.flatMap { proc in
            proc.windows.filter { $0.role == AXTypes.menuBarRole }
        }

        let formatter = OutputFormatter(format: format)
        let result = try formatter.format(menuBarElements)
        return .init(content: [.text(result)])
    }

    // 14. dump_tree
    private func handleDumpTree(_ params: CallTool.Parameters) throws -> CallTool.Result {
        let app = params.arguments?["app"]?.stringValue
        let format = resolveFormat(params)
        let depthLimit = params.arguments?["depth_limit"]?.intValue ?? AXTypes.defaultDepthLimit

        let state = bridge.captureState(appName: app, depthLimit: depthLimit)
        let formatter = OutputFormatter(format: format)
        let result = try formatter.format(state)
        return .init(content: [.text(result)])
    }

    // 15. wait_for_element
    private func handleWaitForElement(_ params: CallTool.Parameters) throws -> CallTool.Result {
        guard let selectorStr = params.arguments?["selector"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: selector")], isError: true)
        }
        let timeout = params.arguments?["timeout"]?.doubleValue
            ?? params.arguments?["timeout"]?.intValue.map(Double.init)
            ?? 10.0
        let interval = params.arguments?["interval"]?.doubleValue
            ?? params.arguments?["interval"]?.intValue.map(Double.init)
            ?? 0.5
        let app = params.arguments?["app"]?.stringValue
        let format = resolveFormat(params)

        let deadline = Date().addingTimeInterval(timeout)
        let selector = try JSONPathSelector(selectorStr)

        while Date() < deadline {
            let state = bridge.captureState(appName: app)
            let matches = selector.execute(on: state)
            if !matches.isEmpty {
                let formatter = OutputFormatter(format: format)
                let result = try formatter.format(matches)
                return .init(content: [.text(result)])
            }
            Thread.sleep(forTimeInterval: interval)
        }

        return .init(content: [.text("Timeout after \(timeout)s waiting for element matching: \(selectorStr)")], isError: true)
    }

    // 16. assert_element_state
    private func handleAssertElementState(_ params: CallTool.Parameters) throws -> CallTool.Result {
        guard let selectorStr = params.arguments?["selector"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: selector")], isError: true)
        }
        guard let expected = params.arguments?["expected"]?.objectValue else {
            return .init(content: [.text("Missing required parameter: expected (object)")], isError: true)
        }
        let app = params.arguments?["app"]?.stringValue

        let state = bridge.captureState(appName: app)
        let selector = try JSONPathSelector(selectorStr)
        let matches = selector.execute(on: state)

        guard let element = matches.first else {
            return .init(content: [.text("FAIL: No element found matching selector: \(selectorStr)")], isError: false)
        }

        var results: [(property: String, passed: Bool, detail: String)] = []

        for (key, expectedValue) in expected {
            switch key {
            case "role":
                if let exp = expectedValue.stringValue {
                    let pass = element.role == exp
                    results.append((key, pass, pass ? "PASS" : "expected '\(exp)', got '\(element.role)'"))
                }
            case "title":
                if let exp = expectedValue.stringValue {
                    let actual = element.title ?? "<nil>"
                    let pass = element.title == exp
                    results.append((key, pass, pass ? "PASS" : "expected '\(exp)', got '\(actual)'"))
                }
            case "value":
                if let exp = expectedValue.stringValue {
                    let actual = element.value ?? "<nil>"
                    let pass = element.value == exp
                    results.append((key, pass, pass ? "PASS" : "expected '\(exp)', got '\(actual)'"))
                }
            case "identifier":
                if let exp = expectedValue.stringValue {
                    let actual = element.identifier ?? "<nil>"
                    let pass = element.identifier == exp
                    results.append((key, pass, pass ? "PASS" : "expected '\(exp)', got '\(actual)'"))
                }
            case "label":
                if let exp = expectedValue.stringValue {
                    let actual = element.label ?? "<nil>"
                    let pass = element.label == exp
                    results.append((key, pass, pass ? "PASS" : "expected '\(exp)', got '\(actual)'"))
                }
            case "enabled":
                if let exp = expectedValue.boolValue {
                    let pass = element.isEnabled == exp
                    results.append((key, pass, pass ? "PASS" : "expected \(exp), got \(element.isEnabled)"))
                }
            case "focused":
                if let exp = expectedValue.boolValue {
                    let pass = element.isFocused == exp
                    results.append((key, pass, pass ? "PASS" : "expected \(exp), got \(element.isFocused)"))
                }
            default:
                // Check customContent keys
                if key.hasPrefix("customContent.") {
                    let contentKey = String(key.dropFirst("customContent.".count))
                    if let exp = expectedValue.stringValue {
                        let actual = element.customContent[contentKey] ?? "<nil>"
                        let pass = element.customContent[contentKey] == exp
                        results.append((key, pass, pass ? "PASS" : "expected '\(exp)', got '\(actual)'"))
                    }
                } else {
                    results.append((key, false, "unknown property"))
                }
            }
        }

        let allPassed = results.allSatisfy { $0.passed }
        var lines: [String] = [allPassed ? "PASS" : "FAIL"]
        for r in results {
            lines.append("  \(r.property): \(r.detail)")
        }
        return .init(content: [.text(lines.joined(separator: "\n"))])
    }

    // 17. get_element_custom_content
    private func handleGetElementCustomContent(_ params: CallTool.Parameters) throws -> CallTool.Result {
        guard let selectorStr = params.arguments?["selector"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: selector")], isError: true)
        }
        let app = params.arguments?["app"]?.stringValue

        let state = bridge.captureState(appName: app)
        let selector = try JSONPathSelector(selectorStr)
        let matches = selector.execute(on: state)

        guard let element = matches.first else {
            return .init(content: [.text("No element found matching selector: \(selectorStr)")], isError: true)
        }

        if element.customContent.isEmpty {
            return .init(content: [.text("No customContent on element (role: \(element.role), id: \(element.id))")])
        }

        let encoder = TOONEncoder()
        let pairs = element.customContent.sorted(by: { $0.key < $1.key }).map {
            (key: $0.key, value: $0.value)
        }
        let result = encoder.encode(pairs)
        return .init(content: [.text(result)])
    }

    // 18. snapshot_diff
    private func handleSnapshotDiff(_ params: CallTool.Parameters) throws -> CallTool.Result {
        let app = params.arguments?["app"]?.stringValue

        // Capture before state
        let before = bridge.captureState(appName: app)

        // Perform action if specified
        if let actionSelector = params.arguments?["action_selector"]?.stringValue {
            let sel = try JSONPathSelector(actionSelector)
            let matches = sel.execute(on: before)
            if let first = matches.first {
                let actionName = params.arguments?["action_name"]?.stringValue ?? AXTypes.pressAction
                _ = try actionExecutor.performAction(elementId: first.id, action: actionName)
                // Allow UI to settle
                Thread.sleep(forTimeInterval: 0.5)
            } else {
                return .init(content: [.text("No element found for action_selector: \(actionSelector)")], isError: true)
            }
        }

        // Capture after state
        let after = bridge.captureState(appName: app)

        // Compute diff
        let diff = computeDiff(before: before, after: after)
        return .init(content: [.text(diff)])
    }

    // MARK: - Helpers

    private func resolveFormat(_ params: CallTool.Parameters) -> OutputFormat {
        if let formatStr = params.arguments?["format"]?.stringValue {
            return OutputFormat(rawValue: formatStr) ?? .toon
        }
        return .toon
    }

    private func formatActionResult(_ result: ActionResult) -> String {
        if result.success {
            return "OK: \(result.action) on \(result.elementId.uuidString)"
                + (result.message.map { " - \($0)" } ?? "")
        } else {
            return "FAILED: \(result.action) on \(result.elementId.uuidString)"
                + (result.message.map { " - \($0)" } ?? "")
        }
    }

    private func findElementById(_ id: UUID, in state: SystemState) -> UIElement? {
        for process in state.processes {
            for window in process.windows {
                if let found = findElementById(id, in: window) {
                    return found
                }
            }
        }
        return nil
    }

    private func findElementById(_ id: UUID, in element: UIElement) -> UIElement? {
        if element.id == id { return element }
        for child in element.children {
            if let found = findElementById(id, in: child) {
                return found
            }
        }
        return nil
    }

    /// Compute a textual diff between two SystemState snapshots.
    private func computeDiff(before: SystemState, after: SystemState) -> String {
        var lines: [String] = ["snapshot_diff:"]

        let beforeApps = Set(before.processes.map { $0.name })
        let afterApps = Set(after.processes.map { $0.name })

        let added = afterApps.subtracting(beforeApps)
        let removed = beforeApps.subtracting(afterApps)

        if !added.isEmpty {
            lines.append("  apps_added: \(added.sorted().joined(separator: ", "))")
        }
        if !removed.isEmpty {
            lines.append("  apps_removed: \(removed.sorted().joined(separator: ", "))")
        }

        // For common apps, diff element counts and window counts
        let commonApps = beforeApps.intersection(afterApps)
        for appName in commonApps.sorted() {
            let beforeProc = before.processes.first { $0.name == appName }
            let afterProc = after.processes.first { $0.name == appName }

            guard let bp = beforeProc, let ap = afterProc else { continue }

            let beforeCount = bp.windows.reduce(0) { $0 + countElements($1) }
            let afterCount = ap.windows.reduce(0) { $0 + countElements($1) }
            let beforeWindows = bp.windows.count
            let afterWindows = ap.windows.count

            var appChanges: [String] = []
            if beforeWindows != afterWindows {
                appChanges.append("windows: \(beforeWindows) -> \(afterWindows)")
            }
            if beforeCount != afterCount {
                appChanges.append("elements: \(beforeCount) -> \(afterCount)")
            }
            if bp.isActive != ap.isActive {
                appChanges.append("active: \(bp.isActive) -> \(ap.isActive)")
            }

            // Diff window titles
            let beforeTitles = bp.windows.compactMap { $0.title }
            let afterTitles = ap.windows.compactMap { $0.title }
            let newTitles = Set(afterTitles).subtracting(Set(beforeTitles))
            let goneTitles = Set(beforeTitles).subtracting(Set(afterTitles))
            if !newTitles.isEmpty {
                appChanges.append("new_windows: \(newTitles.sorted().joined(separator: ", "))")
            }
            if !goneTitles.isEmpty {
                appChanges.append("closed_windows: \(goneTitles.sorted().joined(separator: ", "))")
            }

            if !appChanges.isEmpty {
                lines.append("  \(appName):")
                for change in appChanges {
                    lines.append("    \(change)")
                }
            }
        }

        if lines.count == 1 {
            lines.append("  no changes detected")
        }

        return lines.joined(separator: "\n")
    }

    private func countElements(_ element: UIElement) -> Int {
        1 + element.children.reduce(0) { $0 + countElements($1) }
    }

    // MARK: - Tool Definitions

    nonisolated static let allTools: [Tool] = [
        // 1. find_elements
        Tool(
            name: "find_elements",
            description: "Find UI elements matching a JSONPath selector across all apps or a specific app",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "selector": .object(["type": .string("string"), "description": .string("JSONPath selector (e.g. '$..[?(@.role==\"AXButton\")]')")]),
                    "app": .object(["type": .string("string"), "description": .string("Filter to a specific app by name")]),
                    "format": .object(["type": .string("string"), "description": .string("Output format: toon (default) or json")]),
                ]),
                "required": .array([.string("selector")]),
            ]),
            annotations: .init(readOnlyHint: true)
        ),

        // 2. find_elements_in_app
        Tool(
            name: "find_elements_in_app",
            description: "Search for UI elements within a specific application with deeper traversal",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "app_name": .object(["type": .string("string"), "description": .string("Application name to search within")]),
                    "selector": .object(["type": .string("string"), "description": .string("Optional JSONPath selector to filter results")]),
                    "format": .object(["type": .string("string"), "description": .string("Output format: toon (default) or json")]),
                ]),
                "required": .array([.string("app_name")]),
            ]),
            annotations: .init(readOnlyHint: true)
        ),

        // 3. click_element_by_selector
        Tool(
            name: "click_element_by_selector",
            description: "Click the first UI element matching a JSONPath selector (AXPress action)",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "selector": .object(["type": .string("string"), "description": .string("JSONPath selector to find the element to click")]),
                    "app": .object(["type": .string("string"), "description": .string("Filter to a specific app by name")]),
                ]),
                "required": .array([.string("selector")]),
            ]),
            annotations: .init(readOnlyHint: false, destructiveHint: true)
        ),

        // 4. click_at_position
        Tool(
            name: "click_at_position",
            description: "Click at absolute screen coordinates using CGEvent",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "x": .object(["type": .string("number"), "description": .string("X coordinate (absolute screen position)")]),
                    "y": .object(["type": .string("number"), "description": .string("Y coordinate (absolute screen position)")]),
                ]),
                "required": .array([.string("x"), .string("y")]),
            ]),
            annotations: .init(readOnlyHint: false, destructiveHint: true)
        ),

        // 5. type_text_to_element_by_selector
        Tool(
            name: "type_text_to_element_by_selector",
            description: "Set the value of a text field or other value-holding element found via JSONPath selector",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "selector": .object(["type": .string("string"), "description": .string("JSONPath selector to find the target element")]),
                    "text": .object(["type": .string("string"), "description": .string("Text to type/set as the element value")]),
                    "app": .object(["type": .string("string"), "description": .string("Filter to a specific app by name")]),
                ]),
                "required": .array([.string("selector"), .string("text")]),
            ]),
            annotations: .init(readOnlyHint: false, destructiveHint: true)
        ),

        // 6. get_element_details
        Tool(
            name: "get_element_details",
            description: "Get full details for a specific UI element by its UUID, including customContent",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "element_id": .object(["type": .string("string"), "description": .string("UUID of the element (from a previous find/dump result)")]),
                    "format": .object(["type": .string("string"), "description": .string("Output format: toon (default) or json")]),
                ]),
                "required": .array([.string("element_id")]),
            ]),
            annotations: .init(readOnlyHint: true)
        ),

        // 7. list_running_applications
        Tool(
            name: "list_running_applications",
            description: "List all running apps with name, PID, bundle ID, active/hidden state",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "format": .object(["type": .string("string"), "description": .string("Output format: toon (default) or json")]),
                ]),
            ]),
            annotations: .init(readOnlyHint: true)
        ),

        // 8. get_app_overview
        Tool(
            name: "get_app_overview",
            description: "Quick shallow overview of all apps and their top-level windows",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "format": .object(["type": .string("string"), "description": .string("Output format: toon (default) or json")]),
                ]),
            ]),
            annotations: .init(readOnlyHint: true)
        ),

        // 9. check_accessibility_permissions
        Tool(
            name: "check_accessibility_permissions",
            description: "Check if accessibility permission is granted for this process",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([:]),
            ]),
            annotations: .init(readOnlyHint: true)
        ),

        // 10. get_frontmost_app
        Tool(
            name: "get_frontmost_app",
            description: "Get the currently focused/frontmost application and its full window tree",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "format": .object(["type": .string("string"), "description": .string("Output format: toon (default) or json")]),
                ]),
            ]),
            annotations: .init(readOnlyHint: true)
        ),

        // 11. scroll_element
        Tool(
            name: "scroll_element",
            description: "Scroll within a scroll area element found via JSONPath selector",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "selector": .object(["type": .string("string"), "description": .string("JSONPath selector to find the scroll area")]),
                    "direction": .object(["type": .string("string"), "description": .string("Scroll direction: up, down, left, right")]),
                    "amount": .object(["type": .string("integer"), "description": .string("Scroll amount in lines (default: 3)")]),
                    "app": .object(["type": .string("string"), "description": .string("Filter to a specific app by name")]),
                ]),
                "required": .array([.string("selector"), .string("direction")]),
            ]),
            annotations: .init(readOnlyHint: false)
        ),

        // 12. activate_app
        Tool(
            name: "activate_app",
            description: "Bring an application to the foreground by name or bundle ID",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "name": .object(["type": .string("string"), "description": .string("Application name (e.g. 'Safari')")]),
                    "bundle_id": .object(["type": .string("string"), "description": .string("Bundle identifier (e.g. 'com.apple.Safari')")]),
                ]),
            ]),
            annotations: .init(readOnlyHint: false)
        ),

        // 13. get_menu_bar_items
        Tool(
            name: "get_menu_bar_items",
            description: "Get the menu bar items for a specific application",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "app_name": .object(["type": .string("string"), "description": .string("Application name")]),
                    "format": .object(["type": .string("string"), "description": .string("Output format: toon (default) or json")]),
                ]),
                "required": .array([.string("app_name")]),
            ]),
            annotations: .init(readOnlyHint: true)
        ),

        // 14. dump_tree
        Tool(
            name: "dump_tree",
            description: "Full AX tree dump for all apps or a specific app",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "app": .object(["type": .string("string"), "description": .string("Filter to a specific app by name")]),
                    "format": .object(["type": .string("string"), "description": .string("Output format: toon (default) or json")]),
                    "depth_limit": .object(["type": .string("integer"), "description": .string("Maximum traversal depth (default: 50)")]),
                ]),
            ]),
            annotations: .init(readOnlyHint: true)
        ),

        // 15. wait_for_element
        Tool(
            name: "wait_for_element",
            description: "Poll until a UI element matching a JSONPath selector appears, with configurable timeout",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "selector": .object(["type": .string("string"), "description": .string("JSONPath selector to match")]),
                    "timeout": .object(["type": .string("number"), "description": .string("Timeout in seconds (default: 10)")]),
                    "interval": .object(["type": .string("number"), "description": .string("Poll interval in seconds (default: 0.5)")]),
                    "app": .object(["type": .string("string"), "description": .string("Filter to a specific app by name")]),
                    "format": .object(["type": .string("string"), "description": .string("Output format: toon (default) or json")]),
                ]),
                "required": .array([.string("selector")]),
            ]),
            annotations: .init(readOnlyHint: true)
        ),

        // 16. assert_element_state
        Tool(
            name: "assert_element_state",
            description: "Verify UI element properties match expected values. Returns PASS/FAIL for agent test loops.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "selector": .object(["type": .string("string"), "description": .string("JSONPath selector to find the element")]),
                    "expected": .object(["type": .string("object"), "description": .string("Object with property names as keys and expected values. Supports: role, title, value, identifier, label, enabled, focused, customContent.* keys")]),
                    "app": .object(["type": .string("string"), "description": .string("Filter to a specific app by name")]),
                ]),
                "required": .array([.string("selector"), .string("expected")]),
            ]),
            annotations: .init(readOnlyHint: true)
        ),

        // 17. get_element_custom_content
        Tool(
            name: "get_element_custom_content",
            description: "Extract RealityKit customContent key-value pairs from a UI element found via selector",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "selector": .object(["type": .string("string"), "description": .string("JSONPath selector to find the element")]),
                    "app": .object(["type": .string("string"), "description": .string("Filter to a specific app by name")]),
                ]),
                "required": .array([.string("selector")]),
            ]),
            annotations: .init(readOnlyHint: true)
        ),

        // 18. snapshot_diff
        Tool(
            name: "snapshot_diff",
            description: "Capture AX tree, optionally perform an action, capture again, and return the diff. Single-call test primitive.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "app": .object(["type": .string("string"), "description": .string("Filter to a specific app by name")]),
                    "action_selector": .object(["type": .string("string"), "description": .string("JSONPath selector for the element to act on (optional)")]),
                    "action_name": .object(["type": .string("string"), "description": .string("AX action to perform (default: AXPress)")]),
                ]),
            ]),
            annotations: .init(readOnlyHint: false)
        ),
    ]
}
