import Foundation

/// Unified output formatter that dispatches to the appropriate encoder
/// based on the selected output format.
public struct OutputFormatter: Sendable {
    public let format: OutputFormat

    private let jsonEncoder: JSONOutputEncoder
    private let toonEncoder: TOONEncoder

    public init(format: OutputFormat = .toon) {
        self.format = format
        self.jsonEncoder = JSONOutputEncoder()
        self.toonEncoder = TOONEncoder()
    }

    public func format(_ state: SystemState) throws -> String {
        switch format {
        case .toon:
            toonEncoder.encode(state)
        case .json:
            try jsonEncoder.encode(state)
        }
    }

    public func format(_ elements: [UIElement]) throws -> String {
        switch format {
        case .toon:
            toonEncoder.encode(elements)
        case .json:
            try jsonEncoder.encode(elements)
        }
    }

    public func format(_ element: UIElement) throws -> String {
        switch format {
        case .toon:
            toonEncoder.encode(element)
        case .json:
            try jsonEncoder.encode(element)
        }
    }

    public func format(_ processes: [ProcessInfo]) throws -> String {
        switch format {
        case .toon:
            toonEncoder.encode(processes)
        case .json:
            try jsonEncoder.encode(processes)
        }
    }
}
