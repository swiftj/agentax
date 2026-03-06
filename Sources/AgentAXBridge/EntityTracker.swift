import SwiftUI

/// Observable registry of RealityKit entities for accessibility bridging.
///
/// Add this as a `@State` or `@StateObject` in your view, register entities
/// after adding them to your `RealityView`, and include `EntityAccessibilityOverlay`
/// in your view hierarchy.
///
/// ```swift
/// @State private var tracker = EntityTracker()
///
/// var body: some View {
///     RealityView { content in
///         let entity = makePlayerEntity()
///         content.add(entity)
///         tracker.register(BridgedEntity(
///             id: entity.id.description,
///             label: "Player Character",
///             value: "Health: 100%",
///             role: "player",
///             customContent: [
///                 "position_x": "12.5",
///                 "position_y": "3.0",
///                 "health": "100",
///             ]
///         ))
///     }
///     .overlay { EntityAccessibilityOverlay(tracker: tracker) }
/// }
/// ```
@MainActor
@Observable
public final class EntityTracker {
    public private(set) var entities: [BridgedEntity] = []

    public init() {}

    /// Register or update a bridged entity. If an entity with the same ID exists, it is replaced.
    public func register(_ entity: BridgedEntity) {
        if let idx = entities.firstIndex(where: { $0.id == entity.id }) {
            entities[idx] = entity
        } else {
            entities.append(entity)
        }
    }

    /// Remove a bridged entity by ID.
    public func unregister(id: String) {
        entities.removeAll { $0.id == id }
    }

    /// Remove all bridged entities.
    public func clear() {
        entities.removeAll()
    }

    /// Update the value (AXValue) for an entity.
    public func updateValue(id: String, value: String?) {
        guard let idx = entities.firstIndex(where: { $0.id == id }) else { return }
        entities[idx].value = value
    }

    /// Update specific custom content for an entity.
    public func updateCustomContent(id: String, key: String, value: String) {
        guard let idx = entities.firstIndex(where: { $0.id == id }) else { return }
        entities[idx].customContent[key] = value
    }

    /// Batch update: replace all entities at once.
    public func replaceAll(_ newEntities: [BridgedEntity]) {
        entities = newEntities
    }
}
