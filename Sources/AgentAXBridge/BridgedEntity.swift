import Foundation

/// Represents a RealityKit entity's accessibility data for bridging into the macOS AX tree.
///
/// On macOS, RealityKit's `AccessibilityComponent` does NOT bridge to the system
/// accessibility tree (this only works on visionOS). `BridgedEntity` is the agentax
/// solution: apps create `BridgedEntity` values from their RealityKit entities, and
/// `EntityAccessibilityOverlay` converts them into SwiftUI accessibility elements
/// that DO appear in the AX tree.
public struct BridgedEntity: Identifiable, Sendable {
    public let id: String
    public var label: String
    public var value: String?
    public var role: String
    public var customContent: [String: String]

    /// Create a bridged entity with full accessibility data.
    ///
    /// - Parameters:
    ///   - id: Stable identifier for the entity (e.g., entity.id.description or a game-specific ID)
    ///   - label: Descriptive label (maps to AXDescription/accessibilityLabel)
    ///   - value: Current value/state (maps to AXValue)
    ///   - role: Semantic role hint (stored in customContent as "entity_role", e.g., "player", "enemy", "item")
    ///   - customContent: Arbitrary key-value pairs (maps to AXCustomContent entries).
    ///     Use this for 3D coordinates, health, physics state, game data — anything
    ///     the AI agent needs to verify or act on.
    public init(
        id: String,
        label: String,
        value: String? = nil,
        role: String = "entity",
        customContent: [String: String] = [:]
    ) {
        self.id = id
        self.label = label
        self.value = value
        self.role = role
        self.customContent = customContent
    }
}
