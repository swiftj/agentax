import Testing
import Foundation
@testable import AgentAX

// MARK: - Mock tree helpers

/// Build a UIElement with minimal boilerplate.
private func el(
    role: String,
    title: String? = nil,
    identifier: String? = nil,
    label: String? = nil,
    value: String? = nil,
    isEnabled: Bool = true,
    isFocused: Bool = false,
    depth: Int = 0,
    customContent: [String: String] = [:],
    children: [UIElement] = []
) -> UIElement {
    UIElement(
        role: role,
        title: title,
        value: value,
        identifier: identifier,
        label: label,
        isEnabled: isEnabled,
        isFocused: isFocused,
        customContent: customContent,
        children: children,
        depth: depth
    )
}

/// Build a sample AX tree for testing:
///
/// SystemState
///   Process "MyApp"
///     Window "Main Window"
///       Button "Login" (identifier: loginButton)
///       TextField "Username" (enabled)
///       TextField "Password" (enabled)
///       Group
///         Button "Submit"
///         StaticText "Welcome"
///   Process "Finder"
///     Window "Desktop"
///       Button "Eject"
private func sampleState() -> SystemState {
    let submitButton = el(role: "AXButton", title: "Submit", depth: 3)
    let welcomeText = el(role: "AXStaticText", title: "Welcome", depth: 3)
    let group = el(role: "AXGroup", depth: 2, children: [submitButton, welcomeText])

    let loginButton = el(role: "AXButton", title: "Login", identifier: "loginButton", depth: 2)
    let usernameField = el(role: "AXTextField", title: "Username", isEnabled: true, depth: 2)
    let passwordField = el(role: "AXTextField", title: "Password", isEnabled: false, depth: 2)

    let mainWindow = el(
        role: "AXWindow",
        title: "Main Window",
        depth: 1,
        children: [loginButton, usernameField, passwordField, group]
    )

    let myApp = AgentAX.ProcessInfo(pid: 100, name: "MyApp", bundleIdentifier: "com.example.myapp",
                            isActive: true, windows: [mainWindow])

    let ejectButton = el(role: "AXButton", title: "Eject", depth: 2)
    let desktopWindow = el(role: "AXWindow", title: "Desktop", depth: 1, children: [ejectButton])
    let finder = AgentAX.ProcessInfo(pid: 200, name: "Finder", bundleIdentifier: "com.apple.finder",
                             isActive: false, windows: [desktopWindow])

    return SystemState(processes: [myApp, finder])
}

/// Build a tree with RealityKit custom content.
private func realityKitState() -> SystemState {
    let player = el(
        role: "AXGroup",
        label: "Player Character",
        depth: 2,
        customContent: ["position_x": "1.5", "position_y": "3.0", "health": "100"]
    )
    let enemy = el(
        role: "AXGroup",
        label: "Enemy",
        depth: 2,
        customContent: ["position_x": "5.0", "position_y": "2.0", "health": "50"]
    )
    let scene = el(role: "AXGroup", title: "Scene", depth: 1, children: [player, enemy])
    let window = el(role: "AXWindow", title: "Game", depth: 0, children: [scene])

    let process = AgentAX.ProcessInfo(pid: 300, name: "GameApp", windows: [window])
    return SystemState(processes: [process])
}

// MARK: - Parsing tests

@Suite("JSONPathSelector Parsing")
struct JSONPathParsingTests {

    @Test("Parse root only")
    func parseRoot() throws {
        let selector = try JSONPathSelector("$")
        #expect(selector.segments.count == 1)
        if case .root = selector.segments[0] {} else {
            Issue.record("Expected .root segment")
        }
    }

    @Test("Parse child access")
    func parseChild() throws {
        let selector = try JSONPathSelector("$.processes")
        #expect(selector.segments.count == 2)
        if case .child("processes") = selector.segments[1] {} else {
            Issue.record("Expected .child('processes')")
        }
    }

    @Test("Parse recursive descent")
    func parseRecursiveDescent() throws {
        let selector = try JSONPathSelector("$..[?(@.role=='AXButton')]")
        #expect(selector.segments.count == 3) // root, recursiveDescent, filter
        if case .recursiveDescent = selector.segments[1] {} else {
            Issue.record("Expected .recursiveDescent")
        }
    }

    @Test("Parse simple filter")
    func parseSimpleFilter() throws {
        let selector = try JSONPathSelector("$..[?(@.role=='AXButton')]")
        guard case .filter(let expr) = selector.segments[2] else {
            Issue.record("Expected .filter segment")
            return
        }
        if case .comparison(let prop, let op, let val) = expr {
            #expect(prop == "role")
            #expect(op == .equal)
            #expect(val == .string("AXButton"))
        } else {
            Issue.record("Expected comparison expression")
        }
    }

    @Test("Parse compound AND filter")
    func parseAndFilter() throws {
        let selector = try JSONPathSelector("$..[?(@.role=='AXTextField' && @.enabled==true)]")
        guard case .filter(let expr) = selector.segments.last else {
            Issue.record("Expected filter segment")
            return
        }
        if case .and(let lhs, let rhs) = expr {
            if case .comparison(let p1, _, let v1) = lhs {
                #expect(p1 == "role")
                #expect(v1 == .string("AXTextField"))
            }
            if case .comparison(let p2, _, let v2) = rhs {
                #expect(p2 == "enabled")
                #expect(v2 == .bool(true))
            }
        } else {
            Issue.record("Expected AND expression")
        }
    }

    @Test("Parse compound OR filter")
    func parseOrFilter() throws {
        let selector = try JSONPathSelector("$..[?(@.role=='AXButton' || @.role=='AXTextField')]")
        guard case .filter(let expr) = selector.segments.last else {
            Issue.record("Expected filter segment")
            return
        }
        if case .or = expr {} else {
            Issue.record("Expected OR expression")
        }
    }

    @Test("Parse existence check")
    func parseExistence() throws {
        let selector = try JSONPathSelector("$..[?(@.customContent.position_x)]")
        guard case .filter(let expr) = selector.segments.last else {
            Issue.record("Expected filter segment")
            return
        }
        if case .exists(let prop) = expr {
            #expect(prop == "customContent.position_x")
        } else {
            Issue.record("Expected exists expression")
        }
    }

    @Test("Parse inequality filter")
    func parseNotEqual() throws {
        let selector = try JSONPathSelector("$..[?(@.role!='AXGroup')]")
        guard case .filter(let expr) = selector.segments.last else {
            Issue.record("Expected filter segment")
            return
        }
        if case .comparison(_, let op, _) = expr {
            #expect(op == .notEqual)
        } else {
            Issue.record("Expected comparison with notEqual")
        }
    }

    @Test("Parse complex path: process filter then element filter")
    func parseAppSpecific() throws {
        let selector = try JSONPathSelector("$.processes[?(@.name=='MyApp')]..[?(@.role=='AXButton')]")
        // $, .processes, filter(name==MyApp), .., filter(role==AXButton)
        #expect(selector.segments.count == 5)
        if case .root = selector.segments[0] {} else { Issue.record("Expected root") }
        if case .child("processes") = selector.segments[1] {} else { Issue.record("Expected .processes") }
        if case .filter = selector.segments[2] {} else { Issue.record("Expected process filter") }
        if case .recursiveDescent = selector.segments[3] {} else { Issue.record("Expected ..") }
        if case .filter = selector.segments[4] {} else { Issue.record("Expected element filter") }
    }

    @Test("Invalid path throws error")
    func invalidPath() throws {
        #expect(throws: AXError.self) {
            _ = try JSONPathSelector("[invalid")
        }
    }

    @Test("AND has higher precedence than OR")
    func andOrPrecedence() throws {
        let selector = try JSONPathSelector("$..[?(@.role=='AXButton' || @.role=='AXTextField' && @.enabled==true)]")
        guard case .filter(let expr) = selector.segments.last else {
            Issue.record("Expected filter segment")
            return
        }
        // Should parse as: OR( role==AXButton, AND( role==AXTextField, enabled==true ) )
        if case .or(let lhs, let rhs) = expr {
            if case .comparison(let p, _, _) = lhs {
                #expect(p == "role")
            } else {
                Issue.record("Expected comparison on LHS of OR")
            }
            if case .and = rhs {} else {
                Issue.record("Expected AND on RHS of OR")
            }
        } else {
            Issue.record("Expected OR at top level")
        }
    }
}

// MARK: - Execution tests

@Suite("JSONPathSelector Execution")
struct JSONPathExecutionTests {

    @Test("Find all buttons via recursive descent")
    func findAllButtons() throws {
        let state = sampleState()
        let selector = try JSONPathSelector("$..[?(@.role=='AXButton')]")
        let results = selector.execute(on: state)
        let titles = results.compactMap(\.title).sorted()
        #expect(titles == ["Eject", "Login", "Submit"])
    }

    @Test("Find element by identifier")
    func findByIdentifier() throws {
        let state = sampleState()
        let selector = try JSONPathSelector("$..[?(@.identifier=='loginButton')]")
        let results = selector.execute(on: state)
        #expect(results.count == 1)
        #expect(results[0].title == "Login")
    }

    @Test("Find by label")
    func findByLabel() throws {
        let state = realityKitState()
        let selector = try JSONPathSelector("$..[?(@.label=='Player Character')]")
        let results = selector.execute(on: state)
        #expect(results.count == 1)
        #expect(results[0].customContent["health"] == "100")
    }

    @Test("Compound AND filter: enabled text fields")
    func compoundAndFilter() throws {
        let state = sampleState()
        let selector = try JSONPathSelector("$..[?(@.role=='AXTextField' && @.enabled==true)]")
        let results = selector.execute(on: state)
        #expect(results.count == 1)
        #expect(results[0].title == "Username")
    }

    @Test("Compound OR filter: buttons or text fields")
    func compoundOrFilter() throws {
        let state = sampleState()
        let selector = try JSONPathSelector("$..[?(@.role=='AXButton' || @.role=='AXTextField')]")
        let results = selector.execute(on: state)
        #expect(results.count == 5) // Login, Username, Password, Submit, Eject
    }

    @Test("App-specific query: MyApp buttons only")
    func appSpecificQuery() throws {
        let state = sampleState()
        let selector = try JSONPathSelector("$.processes[?(@.name=='MyApp')]..[?(@.role=='AXButton')]")
        let results = selector.execute(on: state)
        let titles = results.compactMap(\.title).sorted()
        #expect(titles == ["Login", "Submit"])
        // Eject (from Finder) should not appear
    }

    @Test("CustomContent existence check (dotted key)")
    func customContentExistsDottedKey() throws {
        let state = realityKitState()
        let selector = try JSONPathSelector("$..[?(@.customContent.position_x)]")
        let results = selector.execute(on: state)
        #expect(results.count == 2)
    }

    @Test("CustomContent existence check (bare property)")
    func customContentExistsBare() throws {
        let state = realityKitState()
        let selector = try JSONPathSelector("$..[?(@.customContent)]")
        let results = selector.execute(on: state)
        // Should match elements that have non-empty customContent
        #expect(results.count >= 2, "Expected at least 2 elements with customContent")
        for result in results {
            #expect(!result.customContent.isEmpty)
        }
    }

    @Test("CustomContent value comparison")
    func customContentComparison() throws {
        let state = realityKitState()
        let selector = try JSONPathSelector("$..[?(@.customContent.health=='100')]")
        let results = selector.execute(on: state)
        #expect(results.count == 1)
        #expect(results[0].label == "Player Character")
    }

    @Test("Inequality filter")
    func inequalityFilter() throws {
        let state = sampleState()
        let selector = try JSONPathSelector("$..[?(@.role!='AXWindow' && @.role!='AXGroup' && @.role!='AXStaticText')]")
        let results = selector.execute(on: state)
        // Should get buttons and text fields only
        let roles = Set(results.map(\.role))
        #expect(roles == Set(["AXButton", "AXTextField"]))
    }

    @Test("Empty tree returns no results")
    func emptyTree() throws {
        let state = SystemState(processes: [])
        let selector = try JSONPathSelector("$..[?(@.role=='AXButton')]")
        let results = selector.execute(on: state)
        #expect(results.isEmpty)
    }

    @Test("No matches returns empty array")
    func noMatches() throws {
        let state = sampleState()
        let selector = try JSONPathSelector("$..[?(@.role=='AXSlider')]")
        let results = selector.execute(on: state)
        #expect(results.isEmpty)
    }

    @Test("Deeply nested elements are found")
    func deeplyNested() throws {
        // Build a 10-level deep tree
        var current = el(role: "AXButton", title: "DeepButton", depth: 10)
        for d in stride(from: 9, through: 0, by: -1) {
            current = el(role: "AXGroup", depth: d, children: [current])
        }

        let process = AgentAX.ProcessInfo(pid: 999, name: "DeepApp", windows: [current])
        let state = SystemState(processes: [process])

        let selector = try JSONPathSelector("$..[?(@.role=='AXButton')]")
        let results = selector.execute(on: state)
        #expect(results.count == 1)
        #expect(results[0].title == "DeepButton")
    }

    @Test("Execute on flat element list")
    func executeOnElements() throws {
        let elements = [
            el(role: "AXButton", title: "A"),
            el(role: "AXTextField", title: "B"),
            el(role: "AXButton", title: "C"),
        ]
        let selector = try JSONPathSelector("$..[?(@.role=='AXButton')]")
        let results = selector.execute(on: elements)
        #expect(results.count == 2)
    }

    @Test("Boolean false comparison")
    func boolFalseComparison() throws {
        let state = sampleState()
        let selector = try JSONPathSelector("$..[?(@.enabled==false)]")
        let results = selector.execute(on: state)
        #expect(results.count == 1)
        #expect(results[0].title == "Password")
    }

    @Test("Children access via child segment")
    func childrenAccess() throws {
        let state = sampleState()
        // $.processes[?(@.name=='MyApp')].windows.children → direct children of MyApp's windows
        let selector = try JSONPathSelector("$.processes[?(@.name=='MyApp')].windows.children")
        let results = selector.execute(on: state)
        // Main Window has 4 direct children: Login button, Username, Password, Group
        #expect(results.count == 4)
    }

    @Test("Process filter by bundleIdentifier")
    func processFilterBundleId() throws {
        let state = sampleState()
        let selector = try JSONPathSelector("$.processes[?(@.bundleIdentifier=='com.apple.finder')]..[?(@.role=='AXButton')]")
        let results = selector.execute(on: state)
        #expect(results.count == 1)
        #expect(results[0].title == "Eject")
    }
}
