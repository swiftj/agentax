import Foundation
import ApplicationServices

/// Thread-safe store for live AXUIElement references keyed by UUID.
/// Enables O(1) action resolution: capture the tree once, then look up any element by its UUID.
public final class ElementStore: @unchecked Sendable {
    private var refs: [UUID: AXUIElement] = [:]
    private let lock = NSLock()

    public init() {}

    /// Store a live AXUIElement reference for the given UUID.
    public func store(id: UUID, ref: AXUIElement) {
        lock.lock()
        defer { lock.unlock() }
        refs[id] = ref
    }

    /// O(1) lookup of a live AXUIElement by its UUID.
    public func find(id: UUID) -> AXUIElement? {
        lock.lock()
        defer { lock.unlock() }
        return refs[id]
    }

    /// Remove all stored references.
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        refs.removeAll()
    }

    /// The number of stored element references.
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return refs.count
    }
}
