import XCTest
import Foundation
@testable import AgentAX

final class OutputTests: XCTestCase {

    // MARK: - Test Helpers

    static func makeButton(title: String = "OK", identifier: String? = "okButton") -> UIElement {
        UIElement(
            role: "AXButton",
            title: title,
            identifier: identifier,
            position: CGPoint(x: 100, y: 200),
            size: CGSize(width: 80, height: 30),
            isEnabled: true,
            isFocused: false,
            actions: ["AXPress"],
            depth: 0
        )
    }

    static func makeStaticText(title: String = "Hello") -> UIElement {
        UIElement(
            role: "AXStaticText",
            title: title,
            isEnabled: true,
            isFocused: false,
            depth: 1
        )
    }

    static func makeButtonWithChild() -> UIElement {
        var button = makeButton()
        button.children = [makeStaticText(title: "OK")]
        return button
    }

    static func makeProcess(
        name: String = "Safari",
        pid: Int32 = 1234,
        bundleId: String? = "com.apple.Safari",
        active: Bool = true,
        windows: [UIElement] = []
    ) -> AgentAX.ProcessInfo {
        AgentAX.ProcessInfo(
            pid: pid,
            name: name,
            bundleIdentifier: bundleId,
            isActive: active,
            isHidden: false,
            windows: windows
        )
    }

    static func makeSystemState() -> SystemState {
        let window = UIElement(
            role: "AXWindow",
            title: "Apple",
            isEnabled: true,
            isFocused: true,
            children: [makeButton()],
            depth: 0
        )
        let process = makeProcess(windows: [window])
        return SystemState(
            processes: [process],
            capturedAt: Date(timeIntervalSince1970: 1705312200), // 2024-01-15T10:30:00Z
            captureTimeMs: 45.2
        )
    }

    // MARK: - TOON Encoder Tests

    func testTOONEncodesSimpleElement() {
        let encoder = TOONEncoder()
        let button = Self.makeButton()
        let output = encoder.encode(button)

        XCTAssertTrue(output.contains("role: AXButton"))
        XCTAssertTrue(output.contains("title: OK"))
        XCTAssertTrue(output.contains("identifier: okButton"))
        XCTAssertTrue(output.contains("position: 100.0, 200.0"))
        XCTAssertTrue(output.contains("size: 80.0, 30.0"))
        XCTAssertTrue(output.contains("enabled: true"))
        XCTAssertTrue(output.contains("focused: false"))
        XCTAssertTrue(output.contains("- AXPress"))
    }

    func testTOONEncodesNestedChildren() {
        let encoder = TOONEncoder()
        let button = Self.makeButtonWithChild()
        let output = encoder.encode(button)

        XCTAssertTrue(output.contains("children:"))
        XCTAssertTrue(output.contains("role: AXStaticText"))
        XCTAssertTrue(output.contains("title: OK"))
    }

    func testTOONEncodesSystemState() {
        let encoder = TOONEncoder()
        let state = Self.makeSystemState()
        let output = encoder.encode(state)

        XCTAssertTrue(output.contains("capturedAt:"))
        XCTAssertTrue(output.contains("captureTimeMs: 45.2"))
        XCTAssertTrue(output.contains("processes:"))
        XCTAssertTrue(output.contains("name: Safari"))
        XCTAssertTrue(output.contains("pid: 1234"))
        XCTAssertTrue(output.contains("bundleIdentifier: com.apple.Safari"))
        XCTAssertTrue(output.contains("active: true"))
        XCTAssertTrue(output.contains("windows:"))
        XCTAssertTrue(output.contains("role: AXWindow"))
        XCTAssertTrue(output.contains("title: Apple"))
    }

    func testTOONOmitsNilValues() {
        let encoder = TOONEncoder()
        let element = UIElement(
            role: "AXGroup",
            title: nil,
            value: nil,
            identifier: nil,
            isEnabled: true,
            isFocused: false,
            depth: 0
        )
        let output = encoder.encode(element)

        XCTAssertTrue(output.contains("role: AXGroup"))
        XCTAssertFalse(output.contains("title:"))
        XCTAssertFalse(output.contains("value:"))
        XCTAssertFalse(output.contains("identifier:"))
        XCTAssertFalse(output.contains("label:"))
    }

    func testTOONHandlesCustomContent() {
        let encoder = TOONEncoder()
        let element = UIElement(
            role: "AXGroup",
            isEnabled: true,
            isFocused: false,
            customContent: ["x": "10", "y": "20", "type": "entity"],
            depth: 0
        )
        let output = encoder.encode(element)

        XCTAssertTrue(output.contains("customContent:"))
        XCTAssertTrue(output.contains("type: entity"))
    }

    func testTOONEncodesKeyValuePairs() {
        let encoder = TOONEncoder()
        let pairs: [(key: String, value: String)] = [
            (key: "status", value: "success"),
            (key: "message", value: "Action performed")
        ]
        let output = encoder.encode(pairs)

        XCTAssertTrue(output.contains("status: success"))
        XCTAssertTrue(output.contains("message: Action performed"))
    }

    func testTOONEncodesProcessList() {
        let encoder = TOONEncoder()
        let processes = [
            Self.makeProcess(name: "Safari", pid: 1234),
            Self.makeProcess(name: "Finder", pid: 5678, bundleId: "com.apple.finder", active: false)
        ]
        let output = encoder.encode(processes)

        XCTAssertTrue(output.contains("- name: Safari"))
        XCTAssertTrue(output.contains("- name: Finder"))
        XCTAssertTrue(output.contains("pid: 5678"))
    }

    func testTOONEncodesElementArray() {
        let encoder = TOONEncoder()
        let elements = [Self.makeButton(title: "OK"), Self.makeButton(title: "Cancel")]
        let output = encoder.encode(elements)

        XCTAssertTrue(output.contains("- role: AXButton"))
        XCTAssertTrue(output.contains("title: OK"))
        XCTAssertTrue(output.contains("title: Cancel"))
    }

    // MARK: - JSON Encoder Tests

    func testJSONEncodesValidJSON() throws {
        let encoder = JSONOutputEncoder()
        let button = Self.makeButton()
        let output = try encoder.encode(button)

        // Must be valid JSON
        let data = output.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data, options: [])
        XCTAssertTrue(parsed is [String: Any])
    }

    func testJSONRoundtripsUIElement() throws {
        let encoder = JSONOutputEncoder()
        let original = Self.makeButton()
        let jsonString = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = jsonString.data(using: .utf8)!
        let decoded = try decoder.decode(UIElement.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.role, original.role)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.identifier, original.identifier)
        XCTAssertEqual(decoded.isEnabled, original.isEnabled)
        XCTAssertEqual(decoded.isFocused, original.isFocused)
        XCTAssertEqual(decoded.actions, original.actions)
    }

    func testJSONRoundtripsSystemState() throws {
        let encoder = JSONOutputEncoder()
        let original = Self.makeSystemState()
        let jsonString = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = jsonString.data(using: .utf8)!
        let decoded = try decoder.decode(SystemState.self, from: data)

        XCTAssertEqual(decoded.processes.count, original.processes.count)
        XCTAssertEqual(decoded.processes.first?.name, "Safari")
        XCTAssertEqual(decoded.processes.first?.pid, 1234)
        XCTAssertEqual(decoded.captureTimeMs, original.captureTimeMs)
    }

    func testJSONEncodesPrettyPrinted() throws {
        let encoder = JSONOutputEncoder()
        let button = Self.makeButton()
        let output = try encoder.encode(button)

        // Pretty-printed JSON contains newlines and indentation
        XCTAssertTrue(output.contains("\n"))
        XCTAssertTrue(output.contains("  "))
    }

    func testJSONEncodesGenericValue() throws {
        let encoder = JSONOutputEncoder()
        let state = Self.makeSystemState()
        let output = try encoder.encodeValue(state)

        let data = output.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data, options: [])
        XCTAssertTrue(parsed is [String: Any])
    }

    // MARK: - OutputFormatter Tests

    func testOutputFormatterDispatchesToTOON() throws {
        let formatter = OutputFormatter(format: .toon)
        let element = Self.makeButton()
        let output = try formatter.format(element)

        // TOON output does not contain JSON braces
        XCTAssertFalse(output.contains("{"))
        XCTAssertFalse(output.contains("}"))
        XCTAssertTrue(output.contains("role: AXButton"))
    }

    func testOutputFormatterDispatchesToJSON() throws {
        let formatter = OutputFormatter(format: .json)
        let element = Self.makeButton()
        let output = try formatter.format(element)

        // JSON output contains braces
        XCTAssertTrue(output.contains("{"))
        XCTAssertTrue(output.contains("}"))
        XCTAssertTrue(output.contains("\"role\""))
    }

    func testOutputFormatterDefaultIsTOON() throws {
        let formatter = OutputFormatter()
        XCTAssertEqual(formatter.format, .toon)
    }

    func testOutputFormatterFormatsSystemState() throws {
        let state = Self.makeSystemState()

        let toonOutput = try OutputFormatter(format: .toon).format(state)
        let jsonOutput = try OutputFormatter(format: .json).format(state)

        XCTAssertTrue(toonOutput.contains("captureTimeMs:"))
        XCTAssertTrue(jsonOutput.contains("\"captureTimeMs\""))
    }

    func testOutputFormatterFormatsElementArray() throws {
        let elements = [Self.makeButton(), Self.makeStaticText()]

        let toonOutput = try OutputFormatter(format: .toon).format(elements)
        let jsonOutput = try OutputFormatter(format: .json).format(elements)

        XCTAssertTrue(toonOutput.contains("- role: AXButton"))
        XCTAssertTrue(jsonOutput.contains("["))
    }

    func testOutputFormatterFormatsProcessArray() throws {
        let processes = [Self.makeProcess()]

        let toonOutput = try OutputFormatter(format: .toon).format(processes)
        let jsonOutput = try OutputFormatter(format: .json).format(processes)

        XCTAssertTrue(toonOutput.contains("name: Safari"))
        XCTAssertTrue(jsonOutput.contains("\"name\""))
    }

    // MARK: - Token Efficiency Test

    func testTOONIsShorterThanJSON() throws {
        let state = Self.makeSystemState()
        let toonOutput = try OutputFormatter(format: .toon).format(state)
        let jsonOutput = try OutputFormatter(format: .json).format(state)

        // TOON should be meaningfully shorter
        XCTAssertLessThan(
            toonOutput.count,
            jsonOutput.count,
            "TOON output (\(toonOutput.count) chars) should be shorter than JSON (\(jsonOutput.count) chars)"
        )

        // Expect at least 20% savings
        let savings = 1.0 - Double(toonOutput.count) / Double(jsonOutput.count)
        XCTAssertGreaterThan(savings, 0.20, "TOON should save at least 20% vs JSON, got \(Int(savings * 100))%")
    }
}
