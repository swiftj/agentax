import Foundation
import ArgumentParser
import ApplicationServices

// MARK: - DumpCommand

/// Dump the full accessibility tree for all running apps or a specific app.
public struct DumpCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "dump",
        abstract: "Dump the accessibility tree"
    )

    @Option(name: .long, help: "Output format (toon or json)")
    public var format: String = "toon"

    @Option(name: .long, help: "Filter to a specific application by name")
    public var app: String?

    @Option(name: [.short, .long], help: "Output file path")
    public var output: String?

    public init() {}

    public mutating func run() async throws {
        let outputFormat = OutputFormat(rawValue: format) ?? .toon
        let appFilter = app
        let result: String = try await MainActor.run {
            let bridge = AXBridge()
            let state = bridge.captureState(appName: appFilter)
            let formatter = OutputFormatter(format: outputFormat)
            return try formatter.format(state)
        }

        if let outputPath = output {
            try result.write(toFile: outputPath, atomically: true, encoding: .utf8)
            print("Written to \(outputPath)")
        } else {
            print(result)
        }
    }
}

// MARK: - QueryCommand

/// Query the accessibility tree using JSONPath selectors.
public struct QueryCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "query",
        abstract: "Query the AX tree with a JSONPath selector"
    )

    @Argument(help: "JSONPath selector expression (e.g. '$..[?(@.role==\"AXButton\")]')")
    public var selector: String

    @Option(name: .long, help: "Output format (toon or json)")
    public var format: String = "toon"

    @Option(name: .long, help: "Filter to a specific application by name")
    public var app: String?

    public init() {}

    public mutating func run() async throws {
        let outputFormat = OutputFormat(rawValue: format) ?? .toon
        let selectorExpr = selector
        let appFilter = app

        let result: String = try await MainActor.run {
            let bridge = AXBridge()
            let state = bridge.captureState(appName: appFilter)
            let jsonPathSelector = try JSONPathSelector(selectorExpr)
            let matches = jsonPathSelector.execute(on: state)
            let formatter = OutputFormatter(format: outputFormat)
            return try formatter.format(matches)
        }

        print(result)
    }
}

// MARK: - FindCommand

/// Find elements by common type names, optionally filtered by title and app.
public struct FindCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "find",
        abstract: "Find elements by type (buttons, textfields, windows, etc.)"
    )

    @Argument(help: "Element type: buttons, textfields, windows, groups, text, menus, scrollareas")
    public var type: String

    @Option(name: .long, help: "Filter by title")
    public var title: String?

    @Option(name: .long, help: "Filter to a specific application by name")
    public var app: String?

    @Option(name: .long, help: "Output format (toon or json)")
    public var format: String = "toon"

    public init() {}

    /// Map user-friendly type names to AX role strings.
    private static let typeRoleMap: [String: String] = [
        "buttons": AXTypes.buttonRole,
        "textfields": AXTypes.textFieldRole,
        "windows": AXTypes.windowRole,
        "groups": AXTypes.groupRole,
        "text": AXTypes.staticTextRole,
        "menus": AXTypes.menuItemRole,
        "scrollareas": AXTypes.scrollAreaRole,
    ]

    public mutating func run() async throws {
        guard let axRole = FindCommand.typeRoleMap[type.lowercased()] else {
            let validTypes = FindCommand.typeRoleMap.keys.sorted().joined(separator: ", ")
            throw ValidationError("Unknown type '\(type)'. Valid types: \(validTypes)")
        }

        let outputFormat = OutputFormat(rawValue: format) ?? .toon
        let filterTitle = title
        let appFilter = app
        let typeName = type

        let result: String = try await MainActor.run { [axRole, outputFormat, filterTitle, appFilter, typeName] in
            let bridge = AXBridge()
            let state = bridge.captureState(appName: appFilter)
            let matches = FindCommand.findElements(in: state, role: axRole, title: filterTitle)

            guard !matches.isEmpty else {
                var desc = "No \(typeName) found"
                if let t = filterTitle { desc += " with title '\(t)'" }
                if let a = appFilter { desc += " in app '\(a)'" }
                throw AXError.noMatchingElements(desc)
            }

            let formatter = OutputFormatter(format: outputFormat)
            return try formatter.format(matches)
        }

        print(result)
    }

    /// Recursively collect elements matching a role and optional title.
    private static func findElements(in state: SystemState, role: String, title: String?) -> [UIElement] {
        var results: [UIElement] = []
        for process in state.processes {
            for window in process.windows {
                collectMatching(element: window, role: role, title: title, into: &results)
            }
        }
        return results
    }

    private static func collectMatching(element: UIElement, role: String, title: String?, into results: inout [UIElement]) {
        if element.role == role {
            if let filterTitle = title {
                if element.title?.localizedCaseInsensitiveContains(filterTitle) == true
                    || element.label?.localizedCaseInsensitiveContains(filterTitle) == true {
                    results.append(element)
                }
            } else {
                results.append(element)
            }
        }
        for child in element.children {
            collectMatching(element: child, role: role, title: title, into: &results)
        }
    }
}

// MARK: - ActionCommand

/// Perform an action on an element matched by a JSONPath selector.
public struct ActionCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "action",
        abstract: "Perform an action on a matched element"
    )

    @Argument(help: "JSONPath selector to find the target element")
    public var selector: String

    @Argument(help: "Action to perform: click, set_value, press, confirm, cancel")
    public var actionName: String

    @Option(name: .long, help: "Value to set (required for set_value action)")
    public var value: String?

    @Option(name: .long, help: "Filter to a specific application by name")
    public var app: String?

    public init() {}

    public mutating func run() async throws {
        let selectorExpr = selector
        let action = actionName
        let setValue = value
        let appFilter = app

        let result: ActionResult = try await MainActor.run {
            let bridge = AXBridge()
            let state = bridge.captureState(appName: appFilter)
            let jsonPathSelector = try JSONPathSelector(selectorExpr)
            let matches = jsonPathSelector.execute(on: state)

            guard let firstMatch = matches.first else {
                throw AXError.noMatchingElements(selectorExpr)
            }

            let executor = ActionExecutor(elementStore: bridge.elementStore)

            switch action.lowercased() {
            case "click", "press":
                return try executor.click(elementId: firstMatch.id)
            case "set_value":
                guard let val = setValue else {
                    throw ValidationError("--value is required for set_value action")
                }
                return try executor.setValue(elementId: firstMatch.id, value: val)
            case "confirm":
                return try executor.performAction(elementId: firstMatch.id, action: AXTypes.confirmAction)
            case "cancel":
                return try executor.performAction(elementId: firstMatch.id, action: AXTypes.cancelAction)
            case "increment":
                return try executor.performAction(elementId: firstMatch.id, action: AXTypes.incrementAction)
            case "decrement":
                return try executor.performAction(elementId: firstMatch.id, action: AXTypes.decrementAction)
            case "show_menu":
                return try executor.performAction(elementId: firstMatch.id, action: AXTypes.showMenuAction)
            default:
                // Try it as a raw AX action name
                return try executor.performAction(elementId: firstMatch.id, action: action)
            }
        }

        if result.success {
            print("OK: \(result.action) on \(result.elementId)")
        } else {
            print("FAILED: \(result.action) on \(result.elementId) - \(result.message ?? "unknown error")")
        }
    }
}

// MARK: - InfoCommand

/// Display system state summary: permission status, running apps, frontmost app.
public struct InfoCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "info",
        abstract: "System state summary: permissions, running apps, frontmost app"
    )

    public init() {}

    public mutating func run() async throws {
        await MainActor.run {
            let bridge = AXBridge()
            let trusted = bridge.checkPermissions()

            print("Accessibility Permission: \(trusted ? "GRANTED" : "DENIED")")

            if !trusted {
                print("Enable in System Settings > Privacy & Security > Accessibility")
                return
            }

            let state = bridge.captureState()
            let appCount = state.processes.count
            let activeApp = state.processes.first(where: { $0.isActive })
            let totalElements = state.processes.reduce(0) { sum, proc in
                sum + proc.windows.reduce(0) { wSum, win in wSum + InfoCommand.countElements(win) }
            }

            print("Running Apps: \(appCount)")
            if let active = activeApp {
                print("Frontmost App: \(active.name) (pid: \(active.pid))")
            }
            print("Total Elements: \(totalElements)")
            print("Capture Time: \(String(format: "%.1f", state.captureTimeMs))ms")
        }
    }

    private static func countElements(_ element: UIElement) -> Int {
        1 + element.children.reduce(0) { $0 + countElements($1) }
    }
}

// MARK: - TestCommand

/// Test AX permissions and basic functionality.
public struct TestCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "test",
        abstract: "Test AX permissions and basic functionality"
    )

    public init() {}

    public mutating func run() async throws {
        await MainActor.run {
            let bridge = AXBridge()
            var passed = 0
            var failed = 0

            // Test 1: AX permissions
            let trusted = bridge.checkPermissions()
            if trusted {
                print("[PASS] AXIsProcessTrusted: accessibility permission granted")
                passed += 1
            } else {
                print("[FAIL] AXIsProcessTrusted: accessibility permission DENIED")
                print("       Enable in System Settings > Privacy & Security > Accessibility")
                failed += 1
            }

            guard trusted else {
                print("\nResults: \(passed) passed, \(failed) failed")
                return
            }

            // Test 2: Can enumerate apps
            let state = bridge.captureState()
            if !state.processes.isEmpty {
                print("[PASS] App enumeration: found \(state.processes.count) running apps")
                passed += 1
            } else {
                print("[FAIL] App enumeration: no running apps found")
                failed += 1
            }

            // Test 3: Can capture at least one element
            let totalElements = state.processes.reduce(0) { sum, proc in
                sum + proc.windows.reduce(0) { wSum, win in wSum + TestCommand.countElements(win) }
            }
            if totalElements > 0 {
                print("[PASS] Element capture: \(totalElements) elements captured in \(String(format: "%.1f", state.captureTimeMs))ms")
                passed += 1
            } else {
                print("[FAIL] Element capture: no elements captured")
                failed += 1
            }

            // Test 4: Element store populated
            let storeCount = bridge.elementStore.count
            if storeCount > 0 {
                print("[PASS] Element store: \(storeCount) live AXUIElement refs stored")
                passed += 1
            } else {
                print("[FAIL] Element store: no element refs stored")
                failed += 1
            }

            print("\nResults: \(passed) passed, \(failed) failed")
        }
    }

    private static func countElements(_ element: UIElement) -> Int {
        1 + element.children.reduce(0) { $0 + countElements($1) }
    }
}

// MARK: - ServeCommand

/// Start the MCP server (stdio or SSE transport).
public struct ServeCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "serve",
        abstract: "Start the MCP server (stdio transport for Claude Code, etc.)"
    )

    @Option(name: .long, help: "Transport type: stdio or sse")
    public var transport: String = "stdio"

    public init() {}

    public mutating func run() async throws {
        print("MCP server (\(transport) transport) — not yet implemented")
        print("Track progress: https://github.com/swiftj/agentax/issues")
    }
}

// MARK: - SkillCommand

/// Manage agentic skill installations.
public struct SkillCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "skill",
        abstract: "Manage agentic skill installations for AI coding agents",
        subcommands: [
            SkillInstallCommand.self,
            SkillUninstallCommand.self,
            SkillListCommand.self,
            SkillUpdateCommand.self,
            SkillShowCommand.self,
        ]
    )

    public init() {}
}

public struct SkillInstallCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "install",
        abstract: "Install agentax skill for an AI coding agent"
    )

    @Argument(help: "Agent name: claude-code, gemini-cli, codex, antigravity, opencode")
    public var agent: String

    @Option(name: .long, help: "Install level: project or user")
    public var level: String = "project"

    public init() {}

    public mutating func run() async throws {
        print("Skill install for \(agent) (level: \(level)) — not yet implemented")
    }
}

public struct SkillUninstallCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "uninstall",
        abstract: "Uninstall agentax skill for an AI coding agent"
    )

    @Argument(help: "Agent name: claude-code, gemini-cli, codex, antigravity, opencode")
    public var agent: String

    @Option(name: .long, help: "Install level: project or user")
    public var level: String = "project"

    public init() {}

    public mutating func run() async throws {
        print("Skill uninstall for \(agent) (level: \(level)) — not yet implemented")
    }
}

public struct SkillListCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List installed agentax skills"
    )

    public init() {}

    public mutating func run() async throws {
        print("Skill list — not yet implemented")
    }
}

public struct SkillUpdateCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "update",
        abstract: "Update all installed agentax skills"
    )

    public init() {}

    public mutating func run() async throws {
        print("Skill update — not yet implemented")
    }
}

public struct SkillShowCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "show",
        abstract: "Show skill content for an agent"
    )

    @Argument(help: "Agent name: claude-code, gemini-cli, codex, antigravity, opencode")
    public var agent: String

    public init() {}

    public mutating func run() async throws {
        print("Skill show for \(agent) — not yet implemented")
    }
}
