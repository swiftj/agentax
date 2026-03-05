import Foundation
import ArgumentParser
import ApplicationServices
import AppKit
import CoreGraphics

// MARK: - WaitCommand

/// Poll until an element matching a JSONPath selector appears.
public struct WaitCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "wait",
        abstract: "Poll until an element matching a JSONPath selector appears"
    )

    @Argument(help: "JSONPath selector expression")
    public var selector: String

    @Option(name: .long, help: "Maximum time to wait in seconds (default: 10)")
    public var timeout: Double = 10.0

    @Option(name: .long, help: "Polling interval in seconds (default: 0.5)")
    public var interval: Double = 0.5

    @Option(name: .long, help: "Filter to a specific application by name")
    public var app: String?

    @Option(name: .long, help: "Output format (toon or json)")
    public var format: String = "toon"

    public init() {}

    public mutating func run() async throws {
        let selectorExpr = selector
        let timeoutVal = timeout
        let intervalVal = interval
        let appFilter = app
        let outputFormat = OutputFormat(rawValue: format) ?? .toon

        let deadline = Date().addingTimeInterval(timeoutVal)

        while Date() < deadline {
            let matches: [UIElement] = try await MainActor.run {
                let bridge = AXBridge()
                let state = bridge.captureState(appName: appFilter)
                let jsonPathSelector = try JSONPathSelector(selectorExpr)
                return jsonPathSelector.execute(on: state)
            }

            if !matches.isEmpty {
                let result: String = try await MainActor.run {
                    let formatter = OutputFormatter(format: outputFormat)
                    return try formatter.format(matches)
                }
                print(result)
                return
            }

            try await Task.sleep(nanoseconds: UInt64(intervalVal * 1_000_000_000))
        }

        throw AXError.timeout("No element matching '\(selectorExpr)' found within \(timeoutVal)s")
    }
}

// MARK: - AssertCommand

/// Verify element properties match expected values.
public struct AssertCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "assert",
        abstract: "Verify element properties match expected values"
    )

    @Argument(help: "JSONPath selector expression")
    public var selector: String

    @Option(name: .long, help: "Expected role (e.g., AXButton)")
    public var role: String?

    @Option(name: .long, help: "Expected title")
    public var title: String?

    @Option(name: .long, help: "Expected value")
    public var value: String?

    @Option(name: .long, help: "Expected identifier")
    public var identifier: String?

    @Option(name: .long, help: "Expected enabled state")
    public var enabled: Bool?

    @Option(name: .long, help: "Expected focused state")
    public var focused: Bool?

    @Option(name: .long, help: "Filter to a specific application by name")
    public var app: String?

    @Option(name: .long, help: "Output format (toon or json)")
    public var format: String = "toon"

    public init() {}

    public mutating func run() async throws {
        let selectorExpr = selector
        let appFilter = app
        let expectedRole = role
        let expectedTitle = title
        let expectedValue = value
        let expectedIdentifier = identifier
        let expectedEnabled = enabled
        let expectedFocused = focused

        let matches: [UIElement] = try await MainActor.run {
            let bridge = AXBridge()
            let state = bridge.captureState(appName: appFilter)
            let jsonPathSelector = try JSONPathSelector(selectorExpr)
            return jsonPathSelector.execute(on: state)
        }

        guard let element = matches.first else {
            print("[FAIL] No element found matching '\(selectorExpr)'")
            throw ExitCode.failure
        }

        var passed = 0
        var failed = 0

        func check(_ name: String, actual: String?, expected: String?) {
            guard let exp = expected else { return }
            if actual == exp {
                print("[PASS] \(name): '\(exp)'")
                passed += 1
            } else {
                print("[FAIL] \(name): expected '\(exp)', got '\(actual ?? "nil")'")
                failed += 1
            }
        }

        func checkBool(_ name: String, actual: Bool, expected: Bool?) {
            guard let exp = expected else { return }
            if actual == exp {
                print("[PASS] \(name): \(exp)")
                passed += 1
            } else {
                print("[FAIL] \(name): expected \(exp), got \(actual)")
                failed += 1
            }
        }

        check("role", actual: element.role, expected: expectedRole)
        check("title", actual: element.title, expected: expectedTitle)
        check("value", actual: element.value, expected: expectedValue)
        check("identifier", actual: element.identifier, expected: expectedIdentifier)
        checkBool("enabled", actual: element.isEnabled, expected: expectedEnabled)
        checkBool("focused", actual: element.isFocused, expected: expectedFocused)

        print("\nResults: \(passed) passed, \(failed) failed")

        if failed > 0 {
            throw ExitCode.failure
        }
    }
}

// MARK: - SnapshotDiffCommand

/// Capture before state, perform action, capture after, print diff.
public struct SnapshotDiffCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "snapshot-diff",
        abstract: "Capture AX tree, perform action, capture again, return diff"
    )

    @Option(name: .long, help: "Filter to a specific application by name")
    public var app: String?

    @Option(name: .long, help: "JSONPath selector for the element to act on")
    public var actionSelector: String

    @Option(name: .long, help: "Action to perform (e.g., click, press)")
    public var action: String = "click"

    @Option(name: .long, help: "Seconds to wait after action before capturing (default: 0.5)")
    public var settle: Double = 0.5

    @Option(name: .long, help: "Output format (toon or json)")
    public var format: String = "toon"

    public init() {}

    public mutating func run() async throws {
        let appFilter = app
        let actionSel = actionSelector
        let actionName = action
        let settleTime = settle

        // Capture before state
        let beforeElements: [ElementFingerprint] = await MainActor.run {
            let bridge = AXBridge()
            let state = bridge.captureState(appName: appFilter)
            return SnapshotDiffCommand.flattenElements(state)
        }

        // Perform the action
        try await MainActor.run {
            let bridge = AXBridge()
            let state = bridge.captureState(appName: appFilter)
            let jsonPathSelector = try JSONPathSelector(actionSel)
            let matches = jsonPathSelector.execute(on: state)

            guard let firstMatch = matches.first else {
                throw AXError.noMatchingElements(actionSel)
            }

            let executor = ActionExecutor(elementStore: bridge.elementStore)
            switch actionName.lowercased() {
            case "click", "press":
                _ = try executor.click(elementId: firstMatch.id)
            case "confirm":
                _ = try executor.performAction(elementId: firstMatch.id, action: AXTypes.confirmAction)
            case "cancel":
                _ = try executor.performAction(elementId: firstMatch.id, action: AXTypes.cancelAction)
            default:
                _ = try executor.performAction(elementId: firstMatch.id, action: actionName)
            }
        }

        // Wait for settle
        try await Task.sleep(nanoseconds: UInt64(settleTime * 1_000_000_000))

        // Capture after state
        let afterElements: [ElementFingerprint] = await MainActor.run {
            let bridge = AXBridge()
            let state = bridge.captureState(appName: appFilter)
            return SnapshotDiffCommand.flattenElements(state)
        }

        // Compare
        let beforeSet = Set(beforeElements.map { $0.key })
        let afterSet = Set(afterElements.map { $0.key })

        let beforeByKey = Dictionary(grouping: beforeElements, by: { $0.key })
        let afterByKey = Dictionary(grouping: afterElements, by: { $0.key })

        let addedKeys = afterSet.subtracting(beforeSet)
        let removedKeys = beforeSet.subtracting(afterSet)
        let commonKeys = beforeSet.intersection(afterSet)

        var changedCount = 0
        var changes: [String] = []

        for key in commonKeys.sorted() {
            guard let before = beforeByKey[key]?.first,
                  let after = afterByKey[key]?.first else { continue }
            if before.value != after.value || before.title != after.title {
                changedCount += 1
                var desc = "  CHANGED: \(key)"
                if before.title != after.title {
                    desc += " title: '\(before.title ?? "nil")' -> '\(after.title ?? "nil")'"
                }
                if before.value != after.value {
                    desc += " value: '\(before.value ?? "nil")' -> '\(after.value ?? "nil")'"
                }
                changes.append(desc)
            }
        }

        print("Snapshot Diff:")
        print("  Added: \(addedKeys.count) elements")
        for key in addedKeys.sorted() {
            print("    + \(key)")
        }
        print("  Removed: \(removedKeys.count) elements")
        for key in removedKeys.sorted() {
            print("    - \(key)")
        }
        print("  Changed: \(changedCount) elements")
        for change in changes {
            print(change)
        }

        if addedKeys.isEmpty && removedKeys.isEmpty && changedCount == 0 {
            print("  (no changes detected)")
        }
    }

    /// A lightweight fingerprint for comparing elements across snapshots.
    struct ElementFingerprint: Sendable {
        let key: String          // role + identifier (or role + title as fallback)
        let role: String
        let title: String?
        let value: String?
        let identifier: String?
    }

    /// Flatten all elements in a SystemState into fingerprints.
    static func flattenElements(_ state: SystemState) -> [ElementFingerprint] {
        var results: [ElementFingerprint] = []
        for process in state.processes {
            for window in process.windows {
                collectFingerprints(element: window, into: &results)
            }
        }
        return results
    }

    private static func collectFingerprints(element: UIElement, into results: inout [ElementFingerprint]) {
        let key: String
        if let ident = element.identifier, !ident.isEmpty {
            key = "\(element.role):\(ident)"
        } else if let title = element.title, !title.isEmpty {
            key = "\(element.role):\(title)"
        } else {
            key = "\(element.role):_unnamed_"
        }
        results.append(ElementFingerprint(
            key: key,
            role: element.role,
            title: element.title,
            value: element.value,
            identifier: element.identifier
        ))
        for child in element.children {
            collectFingerprints(element: child, into: &results)
        }
    }
}

// MARK: - ActivateCommand

/// Bring an application to the foreground.
public struct ActivateCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "activate",
        abstract: "Bring an application to the foreground"
    )

    @Argument(help: "Application name (e.g., Safari)")
    public var name: String?

    @Option(name: .long, help: "Application bundle identifier (e.g., com.apple.Safari)")
    public var bundleId: String?

    public init() {}

    public mutating func run() async throws {
        let appName = name
        let bundleIdentifier = bundleId

        guard appName != nil || bundleIdentifier != nil else {
            throw ValidationError("Provide either an application name or --bundle-id")
        }

        let result: String = await MainActor.run {
            let workspace = NSWorkspace.shared
            let apps = workspace.runningApplications

            let target: NSRunningApplication?
            if let bid = bundleIdentifier {
                target = apps.first { $0.bundleIdentifier == bid }
            } else if let name = appName {
                target = apps.first { $0.localizedName == name }
            } else {
                target = nil
            }

            guard let app = target else {
                let identifier = bundleIdentifier ?? appName ?? "unknown"
                return "ERROR: Application '\(identifier)' not found"
            }

            app.activate()
            return "Activated: \(app.localizedName ?? "Unknown") (pid: \(app.processIdentifier))"
        }

        print(result)
    }
}

// MARK: - FrontmostCommand

/// Print the currently focused application and its window tree.
public struct FrontmostCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "frontmost",
        abstract: "Print the currently focused application and its window tree"
    )

    @Option(name: .long, help: "Output format (toon or json)")
    public var format: String = "toon"

    public init() {}

    public mutating func run() async throws {
        let outputFormat = OutputFormat(rawValue: format) ?? .toon

        let result: String = try await MainActor.run {
            let workspace = NSWorkspace.shared
            guard let frontApp = workspace.frontmostApplication else {
                return "No frontmost application found"
            }

            let appName = frontApp.localizedName ?? "Unknown"
            let pid = frontApp.processIdentifier
            let bundleId = frontApp.bundleIdentifier ?? "unknown"

            let bridge = AXBridge()
            let state = bridge.captureState(appName: appName)

            let formatter = OutputFormatter(format: outputFormat)
            var output = "Frontmost: \(appName) (pid: \(pid), bundle: \(bundleId))\n"
            output += try formatter.format(state)
            return output
        }

        print(result)
    }
}

// MARK: - ClickAtCommand

/// Click at screen coordinates.
public struct ClickAtCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "click-at",
        abstract: "Click at screen coordinates"
    )

    @Argument(help: "X coordinate")
    public var x: Double

    @Argument(help: "Y coordinate")
    public var y: Double

    @Flag(name: .long, help: "Perform a right-click instead of left-click")
    public var right: Bool = false

    @Flag(name: .long, help: "Perform a double-click")
    public var double: Bool = false

    public init() {}

    public mutating func run() async throws {
        let xPos = x
        let yPos = y
        let isRight = right
        let isDouble = double

        try await MainActor.run {
            let input = InputEventGenerator()
            if isDouble {
                try input.doubleClickAtPosition(x: xPos, y: yPos)
            } else if isRight {
                try input.rightClickAtPosition(x: xPos, y: yPos)
            } else {
                try input.clickAtPosition(x: xPos, y: yPos)
            }
        }

        let clickType = isDouble ? "Double-click" : (isRight ? "Right-click" : "Click")
        print("OK: \(clickType) at (\(x), \(y))")
    }
}

// MARK: - TypeCommand

/// Type text or key combinations.
public struct TypeCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "type",
        abstract: "Type text or key combinations"
    )

    @Argument(help: "Text to type (omit if using --key)")
    public var text: String?

    @Option(name: .long, help: "Key name to press (e.g., return, tab, escape)")
    public var key: String?

    @Option(name: .long, help: "Comma-separated modifier keys (e.g., command,shift)")
    public var modifiers: String?

    public init() {}

    public mutating func run() async throws {
        let textValue = text
        let keyValue = key
        let modifiersValue = modifiers

        guard textValue != nil || keyValue != nil else {
            throw ValidationError("Provide text to type or --key for a key press")
        }

        try await MainActor.run {
            let input = InputEventGenerator()

            if let keyName = keyValue {
                // Key combination mode
                var mods: [KeyModifier] = []
                if let modStr = modifiersValue {
                    mods = modStr.split(separator: ",").compactMap { part in
                        KeyModifier(rawValue: part.trimmingCharacters(in: .whitespaces))
                    }
                }
                try input.keyCombination(key: keyName, modifiers: mods)
            } else if let txt = textValue {
                // Text typing mode
                try input.typeText(txt)
            }
        }

        if let keyName = keyValue {
            let modStr = modifiersValue.map { " with modifiers: \($0)" } ?? ""
            print("OK: Key '\(keyName)'\(modStr)")
        } else {
            print("OK: Typed \(textValue?.count ?? 0) characters")
        }
    }
}

// MARK: - DetailsCommand

/// Get full details for a matched element including all properties and customContent.
public struct DetailsCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "details",
        abstract: "Get full details for a matched element"
    )

    @Argument(help: "JSONPath selector expression")
    public var selector: String

    @Option(name: .long, help: "Filter to a specific application by name")
    public var app: String?

    @Option(name: .long, help: "Output format (toon or json)")
    public var format: String = "toon"

    public init() {}

    public mutating func run() async throws {
        let selectorExpr = selector
        let appFilter = app
        let outputFormat = OutputFormat(rawValue: format) ?? .toon

        let result: String = try await MainActor.run {
            let bridge = AXBridge()
            let state = bridge.captureState(appName: appFilter)
            let jsonPathSelector = try JSONPathSelector(selectorExpr)
            let matches = jsonPathSelector.execute(on: state)

            guard let element = matches.first else {
                throw AXError.noMatchingElements(selectorExpr)
            }

            // Build a detailed output including all properties
            var lines: [String] = []
            lines.append("Element Details:")
            lines.append("  id: \(element.id)")
            lines.append("  role: \(element.role)")
            if let t = element.title { lines.append("  title: \(t)") }
            if let v = element.value { lines.append("  value: \(v)") }
            if let i = element.identifier { lines.append("  identifier: \(i)") }
            if let l = element.label { lines.append("  label: \(l)") }
            if let rd = element.roleDescription { lines.append("  roleDescription: \(rd)") }
            if let pos = element.position { lines.append("  position: (\(pos.x), \(pos.y))") }
            if let sz = element.size { lines.append("  size: \(sz.width) x \(sz.height)") }
            lines.append("  enabled: \(element.isEnabled)")
            lines.append("  focused: \(element.isFocused)")
            if !element.actions.isEmpty {
                lines.append("  actions: \(element.actions.joined(separator: ", "))")
            }
            if !element.customContent.isEmpty {
                lines.append("  customContent:")
                for (key, value) in element.customContent.sorted(by: { $0.key < $1.key }) {
                    lines.append("    \(key): \(value)")
                }
            }
            lines.append("  children: \(element.children.count)")
            lines.append("  depth: \(element.depth)")

            // Also include formatted output if JSON requested
            if outputFormat == .json {
                let formatter = OutputFormatter(format: outputFormat)
                return try formatter.format(element)
            }

            return lines.joined(separator: "\n")
        }

        print(result)
    }
}

// MARK: - MenuCommand

/// Get menu bar items for a specific application.
public struct MenuCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "menu",
        abstract: "Get menu bar items for a specific application"
    )

    @Argument(help: "Application name")
    public var appName: String

    @Option(name: .long, help: "Output format (toon or json)")
    public var format: String = "toon"

    public init() {}

    public mutating func run() async throws {
        let targetApp = appName
        let outputFormat = OutputFormat(rawValue: format) ?? .toon

        let result: String = try await MainActor.run {
            let bridge = AXBridge()
            let state = bridge.captureState(appName: targetApp)

            // Find menu bar elements (role == AXMenuBar)
            var menuElements: [UIElement] = []
            for process in state.processes {
                for window in process.windows {
                    if window.role == AXTypes.menuBarRole {
                        menuElements.append(window)
                    }
                    // Also check children for menu bar items
                    MenuCommand.collectMenuElements(element: window, into: &menuElements)
                }
            }

            guard !menuElements.isEmpty else {
                return "No menu bar items found for '\(targetApp)'"
            }

            let formatter = OutputFormatter(format: outputFormat)
            return try formatter.format(menuElements)
        }

        print(result)
    }

    private static func collectMenuElements(element: UIElement, into results: inout [UIElement]) {
        if element.role == AXTypes.menuBarItemRole || element.role == AXTypes.menuItemRole {
            results.append(element)
        }
        for child in element.children {
            collectMenuElements(element: child, into: &results)
        }
    }
}

// MARK: - CustomContentCommand

/// Extract RealityKit customContent key-value pairs from matched elements.
public struct CustomContentCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "custom-content",
        abstract: "Extract RealityKit customContent key-value pairs from matched elements"
    )

    @Argument(help: "JSONPath selector expression")
    public var selector: String

    @Option(name: .long, help: "Filter to a specific application by name")
    public var app: String?

    @Option(name: .long, help: "Output format (toon or json)")
    public var format: String = "toon"

    public init() {}

    public mutating func run() async throws {
        let selectorExpr = selector
        let appFilter = app
        let outputFormat = OutputFormat(rawValue: format) ?? .toon

        let result: String = try await MainActor.run {
            let bridge = AXBridge()
            let state = bridge.captureState(appName: appFilter)
            let jsonPathSelector = try JSONPathSelector(selectorExpr)
            let matches = jsonPathSelector.execute(on: state)

            guard !matches.isEmpty else {
                throw AXError.noMatchingElements(selectorExpr)
            }

            if outputFormat == .json {
                // Build JSON output of all custom content
                var allContent: [[String: Any]] = []
                for element in matches {
                    var entry: [String: Any] = [
                        "id": element.id.uuidString,
                        "role": element.role,
                    ]
                    if let title = element.title { entry["title"] = title }
                    if let label = element.label { entry["label"] = label }
                    entry["customContent"] = element.customContent
                    allContent.append(entry)
                }
                let data = try JSONSerialization.data(withJSONObject: allContent, options: [.prettyPrinted, .sortedKeys])
                return String(data: data, encoding: .utf8) ?? "[]"
            } else {
                // TOON-style output
                var lines: [String] = []
                for element in matches {
                    let desc = element.title ?? element.label ?? element.identifier ?? element.role
                    lines.append("\(desc):")
                    if element.customContent.isEmpty {
                        lines.append("  (no custom content)")
                    } else {
                        for (key, value) in element.customContent.sorted(by: { $0.key < $1.key }) {
                            lines.append("  \(key): \(value)")
                        }
                    }
                }
                return lines.joined(separator: "\n")
            }
        }

        print(result)
    }
}
