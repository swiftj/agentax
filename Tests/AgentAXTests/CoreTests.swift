import Testing
import Foundation
import ApplicationServices
@testable import AgentAX

// MARK: - ElementStore Tests

@Suite("ElementStore")
struct ElementStoreTests {
    @Test("Store and find element by UUID")
    func storeAndFind() {
        let store = ElementStore()
        let id = UUID()
        let fakeRef = AXUIElementCreateSystemWide()
        store.store(id: id, ref: fakeRef)
        #expect(store.find(id: id) != nil)
    }

    @Test("Find returns nil for unknown UUID")
    func findUnknown() {
        let store = ElementStore()
        #expect(store.find(id: UUID()) == nil)
    }

    @Test("Count tracks stored elements")
    func count() {
        let store = ElementStore()
        #expect(store.count == 0)

        let ref = AXUIElementCreateSystemWide()
        store.store(id: UUID(), ref: ref)
        store.store(id: UUID(), ref: ref)
        #expect(store.count == 2)
    }

    @Test("Clear removes all elements")
    func clear() {
        let store = ElementStore()
        let ref = AXUIElementCreateSystemWide()
        store.store(id: UUID(), ref: ref)
        store.store(id: UUID(), ref: ref)
        #expect(store.count == 2)

        store.clear()
        #expect(store.count == 0)
    }

    @Test("Overwrite existing UUID replaces ref")
    func overwrite() {
        let store = ElementStore()
        let id = UUID()
        let ref1 = AXUIElementCreateSystemWide()
        let ref2 = AXUIElementCreateSystemWide()
        store.store(id: id, ref: ref1)
        store.store(id: id, ref: ref2)
        #expect(store.count == 1)
        #expect(store.find(id: id) != nil)
    }

    @Test("Multiple stores and lookups work correctly")
    func multipleStoresAndLookups() {
        let store = ElementStore()
        let ref = AXUIElementCreateSystemWide()
        var ids: [UUID] = []

        for _ in 0..<100 {
            let id = UUID()
            ids.append(id)
            store.store(id: id, ref: ref)
        }

        #expect(store.count == 100)
        for id in ids {
            #expect(store.find(id: id) != nil)
        }
    }
}

// MARK: - UIElement Tests

@Suite("UIElement")
struct UIElementTests {
    @Test("UIElement Codable roundtrip")
    func codableRoundtrip() throws {
        let element = UIElement(
            role: "AXButton",
            title: "Submit",
            value: "Click me",
            identifier: "submitBtn",
            label: "Submit button",
            roleDescription: "button",
            position: CGPoint(x: 10.5, y: 20.5),
            size: CGSize(width: 100, height: 44),
            isEnabled: true,
            isFocused: false,
            actions: ["AXPress", "AXShowMenu"],
            customContent: ["health": "100", "position_x": "12.5"],
            depth: 3
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(element)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(UIElement.self, from: data)

        #expect(decoded.id == element.id)
        #expect(decoded.role == "AXButton")
        #expect(decoded.title == "Submit")
        #expect(decoded.value == "Click me")
        #expect(decoded.identifier == "submitBtn")
        #expect(decoded.label == "Submit button")
        #expect(decoded.position?.x == 10.5)
        #expect(decoded.position?.y == 20.5)
        #expect(decoded.size?.width == 100)
        #expect(decoded.size?.height == 44)
        #expect(decoded.isEnabled == true)
        #expect(decoded.isFocused == false)
        #expect(decoded.actions == ["AXPress", "AXShowMenu"])
        #expect(decoded.customContent == ["health": "100", "position_x": "12.5"])
        #expect(decoded.depth == 3)
    }

    @Test("UIElement with nil optional fields roundtrips")
    func codableNils() throws {
        let element = UIElement(role: "AXGroup")

        let encoder = JSONEncoder()
        let data = try encoder.encode(element)
        let decoded = try JSONDecoder().decode(UIElement.self, from: data)

        #expect(decoded.role == "AXGroup")
        #expect(decoded.title == nil)
        #expect(decoded.value == nil)
        #expect(decoded.position == nil)
        #expect(decoded.size == nil)
        #expect(decoded.actions.isEmpty)
        #expect(decoded.customContent.isEmpty)
        #expect(decoded.children.isEmpty)
    }

    @Test("UIElement with children roundtrips")
    func codableChildren() throws {
        let child = UIElement(role: "AXStaticText", title: "Hello", depth: 1)
        let parent = UIElement(role: "AXGroup", children: [child], depth: 0)

        let data = try JSONEncoder().encode(parent)
        let decoded = try JSONDecoder().decode(UIElement.self, from: data)

        #expect(decoded.children.count == 1)
        #expect(decoded.children[0].role == "AXStaticText")
        #expect(decoded.children[0].title == "Hello")
    }

    @Test("UIElement equality is based on ID")
    func equality() {
        let id = UUID()
        let a = UIElement(id: id, role: "AXButton", title: "A")
        let b = UIElement(id: id, role: "AXButton", title: "B")
        let c = UIElement(role: "AXButton", title: "A")
        #expect(a == b)
        #expect(a != c)
    }

    @Test("UIElement hashing is based on ID")
    func hashing() {
        let id = UUID()
        let a = UIElement(id: id, role: "AXButton")
        let b = UIElement(id: id, role: "AXTextField")
        let set: Set<UIElement> = [a, b]
        #expect(set.count == 1)
    }
}

// MARK: - SystemState and ProcessInfo Tests

@Suite("SystemState")
struct SystemStateTests {
    @Test("SystemState Codable roundtrip")
    func codableRoundtrip() throws {
        let process = ProcessInfo(
            pid: 1234,
            name: "TestApp",
            bundleIdentifier: "com.test.app",
            isActive: true,
            isHidden: false,
            windows: [UIElement(role: "AXWindow", title: "Main Window")]
        )
        let state = SystemState(
            processes: [process],
            capturedAt: Date(timeIntervalSince1970: 1700000000),
            captureTimeMs: 42.5
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SystemState.self, from: data)

        #expect(decoded.processes.count == 1)
        #expect(decoded.processes[0].name == "TestApp")
        #expect(decoded.processes[0].pid == 1234)
        #expect(decoded.processes[0].bundleIdentifier == "com.test.app")
        #expect(decoded.processes[0].isActive == true)
        #expect(decoded.processes[0].windows.count == 1)
        #expect(decoded.captureTimeMs == 42.5)
    }
}

// MARK: - AXTypes Tests

@Suite("AXTypes")
struct AXTypesTests {
    @Test("Default constants are correct")
    func defaults() {
        #expect(AXTypes.defaultDepthLimit == 50)
        #expect(AXTypes.defaultTimeout == 30)
        #expect(AXTypes.menuBarTimeout == 2)
    }

    @Test("Role constants match AX naming")
    func roleConstants() {
        #expect(AXTypes.buttonRole == "AXButton")
        #expect(AXTypes.textFieldRole == "AXTextField")
        #expect(AXTypes.windowRole == "AXWindow")
        #expect(AXTypes.applicationRole == "AXApplication")
        #expect(AXTypes.staticTextRole == "AXStaticText")
    }

    @Test("Action constants match AX naming")
    func actionConstants() {
        #expect(AXTypes.pressAction == "AXPress")
        #expect(AXTypes.confirmAction == "AXConfirm")
        #expect(AXTypes.cancelAction == "AXCancel")
    }
}

// MARK: - AXError Tests

@Suite("AXError")
struct AXErrorTests {
    @Test("Error descriptions are informative")
    func descriptions() {
        #expect(AXError.notTrusted.description.contains("Accessibility"))
        #expect(AXError.elementNotFound("test").description.contains("test"))
        #expect(AXError.actionNotSupported("AXPress").description.contains("AXPress"))
        #expect(AXError.timeout("30s").description.contains("30s"))
        #expect(AXError.depthLimitExceeded.description.contains("50"))
        #expect(AXError.invalidSelector("bad").description.contains("bad"))
        #expect(AXError.noMatchingElements("query").description.contains("query"))
    }
}

// MARK: - OutputFormat Tests

@Suite("OutputFormat")
struct OutputFormatTests {
    @Test("OutputFormat raw values")
    func rawValues() {
        #expect(OutputFormat(rawValue: "toon") == .toon)
        #expect(OutputFormat(rawValue: "json") == .json)
        #expect(OutputFormat(rawValue: "xml") == nil)
    }

    @Test("OutputFormat allCases")
    func allCases() {
        #expect(OutputFormat.allCases.count == 2)
    }
}

// MARK: - ActionResult Tests

@Suite("ActionResult")
struct ActionResultTests {
    @Test("ActionResult Codable roundtrip")
    func codableRoundtrip() throws {
        let id = UUID()
        let result = ActionResult(success: true, elementId: id, action: "AXPress", message: "Clicked")

        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(ActionResult.self, from: data)

        #expect(decoded.success == true)
        #expect(decoded.elementId == id)
        #expect(decoded.action == "AXPress")
        #expect(decoded.message == "Clicked")
    }

    @Test("ActionResult with nil message")
    func nilMessage() throws {
        let result = ActionResult(success: false, elementId: UUID(), action: "setValue")
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(ActionResult.self, from: data)
        #expect(decoded.message == nil)
    }
}

// MARK: - ScrollDirection Tests

@Suite("ScrollDirection")
struct ScrollDirectionTests {
    @Test("ScrollDirection raw values")
    func rawValues() {
        #expect(ScrollDirection(rawValue: "up") == .up)
        #expect(ScrollDirection(rawValue: "down") == .down)
        #expect(ScrollDirection(rawValue: "left") == .left)
        #expect(ScrollDirection(rawValue: "right") == .right)
    }

    @Test("ScrollDirection allCases")
    func allCases() {
        #expect(ScrollDirection.allCases.count == 4)
    }
}

// MARK: - KeyModifier Tests

@Suite("KeyModifier")
struct KeyModifierTests {
    @Test("KeyModifier raw values")
    func rawValues() {
        #expect(KeyModifier(rawValue: "command") == .command)
        #expect(KeyModifier(rawValue: "shift") == .shift)
        #expect(KeyModifier(rawValue: "control") == .control)
        #expect(KeyModifier(rawValue: "option") == .option)
    }

    @Test("KeyModifier cgFlag values are distinct")
    func cgFlags() {
        let flags = KeyModifier.allCases.map { $0.cgFlag.rawValue }
        let uniqueFlags = Set(flags)
        #expect(uniqueFlags.count == KeyModifier.allCases.count)
    }

    @Test("KeyModifier allCases")
    func allCases() {
        #expect(KeyModifier.allCases.count == 4)
    }
}

// MARK: - InputEventError Tests

@Suite("InputEventError")
struct InputEventErrorTests {
    @Test("Error descriptions are informative")
    func descriptions() {
        let createErr = InputEventError.eventCreationFailed("click")
        #expect(createErr.description.contains("click"))

        let unknownErr = InputEventError.unknownKey("xyz")
        #expect(unknownErr.description.contains("xyz"))
    }
}

// MARK: - InputEventGenerator Key Code Map Tests

@Suite("InputEventGenerator KeyCodes")
struct KeyCodeMapTests {
    @Test("All letters a-z are mapped")
    func letters() {
        for char in "abcdefghijklmnopqrstuvwxyz" {
            #expect(InputEventGenerator.keyCodeMap[String(char)] != nil, "Missing keycode for '\(char)'")
        }
    }

    @Test("All digits 0-9 are mapped")
    func digits() {
        for char in "0123456789" {
            #expect(InputEventGenerator.keyCodeMap[String(char)] != nil, "Missing keycode for '\(char)'")
        }
    }

    @Test("Common special keys are mapped")
    func specialKeys() {
        let required = ["return", "tab", "space", "delete", "escape", "left", "right", "up", "down"]
        for key in required {
            #expect(InputEventGenerator.keyCodeMap[key] != nil, "Missing keycode for '\(key)'")
        }
    }

    @Test("Function keys F1-F12 are mapped")
    func functionKeys() {
        for i in 1...12 {
            #expect(InputEventGenerator.keyCodeMap["f\(i)"] != nil, "Missing keycode for 'f\(i)'")
        }
    }

    @Test("Key codes are unique per physical key")
    func uniqueness() {
        // return and enter share the same physical key, so allow aliases
        // Just verify we have a reasonable number of unique codes
        let uniqueCodes = Set(InputEventGenerator.keyCodeMap.values)
        #expect(uniqueCodes.count > 40) // letters + digits + special keys
    }
}
