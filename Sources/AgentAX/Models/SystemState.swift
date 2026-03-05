import Foundation

/// Captured state of all running applications and their AX trees.
public struct SystemState: Sendable, Codable {
    public var processes: [ProcessInfo]
    public var capturedAt: Date
    public var captureTimeMs: Double

    public init(processes: [ProcessInfo] = [], capturedAt: Date = Date(), captureTimeMs: Double = 0) {
        self.processes = processes
        self.capturedAt = capturedAt
        self.captureTimeMs = captureTimeMs
    }
}

/// A running application's basic info plus its AX tree.
public struct ProcessInfo: Sendable, Codable {
    public let pid: Int32
    public let name: String
    public let bundleIdentifier: String?
    public let isActive: Bool
    public let isHidden: Bool
    public var windows: [UIElement]

    public init(
        pid: Int32,
        name: String,
        bundleIdentifier: String? = nil,
        isActive: Bool = false,
        isHidden: Bool = false,
        windows: [UIElement] = []
    ) {
        self.pid = pid
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.isActive = isActive
        self.isHidden = isHidden
        self.windows = windows
    }
}
