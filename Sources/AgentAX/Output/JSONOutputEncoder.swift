import Foundation

/// JSON output encoder for SystemState, UIElement, and other Codable types.
/// Uses pretty-printed, sorted-keys JSON with ISO 8601 dates.
public struct JSONOutputEncoder: Sendable {
    private let encoder: JSONEncoder

    public init() {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc
    }

    public func encode(_ state: SystemState) throws -> String {
        try encodeValue(state)
    }

    public func encode(_ elements: [UIElement]) throws -> String {
        try encodeValue(elements)
    }

    public func encode(_ element: UIElement) throws -> String {
        try encodeValue(element)
    }

    public func encode(_ processes: [ProcessInfo]) throws -> String {
        try encodeValue(processes)
    }

    /// Encode any Encodable & Sendable value to a pretty-printed JSON string.
    public func encodeValue<T: Encodable & Sendable>(_ value: T) throws -> String {
        let data = try encoder.encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(value, EncodingError.Context(
                codingPath: [],
                debugDescription: "Failed to convert JSON data to UTF-8 string"
            ))
        }
        return string
    }
}
