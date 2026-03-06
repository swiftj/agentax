import SwiftUI

/// Invisible SwiftUI overlay that bridges RealityKit entity data into the macOS AX tree.
///
/// On macOS, RealityKit's `AccessibilityComponent` does NOT appear in the system
/// accessibility tree. This view solves that by creating standard SwiftUI accessibility
/// elements for each tracked entity. These elements appear in the AX tree with:
/// - `AXDescription` (label) — the entity's descriptive name
/// - `AXValue` — the entity's current state/value
/// - `AXIdentifier` — the entity's stable ID (prefixed with "rk-")
/// - `AXCustomContent` — all custom key-value pairs (3D coordinates, health, game data)
///
/// Usage: Add as an overlay on your `RealityView`:
/// ```swift
/// RealityView { content in ... }
///     .overlay { EntityAccessibilityOverlay(tracker: tracker) }
/// ```
///
/// agentax queries these elements like any other AX element:
/// ```
/// agentax query '$..[?(@.identifier =~ /^rk-/)]' --app MyGame
/// agentax query '$..[?(@.customContent.entity_role == "player")]' --app MyGame
/// ```
public struct EntityAccessibilityOverlay: View {
    @Bindable public var tracker: EntityTracker

    public init(tracker: EntityTracker) {
        self.tracker = tracker
    }

    public var body: some View {
        ZStack {
            ForEach(tracker.entities) { entity in
                BridgedEntityAccessibilityElement(entity: entity)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(false)
    }
}

/// Individual accessibility element for a single bridged RealityKit entity.
private struct BridgedEntityAccessibilityElement: View {
    let entity: BridgedEntity

    var body: some View {
        // Use a 1x1 clear rectangle so it has non-zero size in the AX tree.
        // agentax filters out zero-size leaf nodes, so this needs a minimal footprint.
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(entity.label)
            .accessibilityValue(entity.value ?? "")
            .accessibilityIdentifier("rk-\(entity.id)")
            .accessibilityAddTraits(.isStaticText)
            // Bridge all custom content as AXCustomContent entries.
            // This is the key mechanism: .accessibilityCustomContent on macOS
            // maps to AXCustomContent in the AX tree, which agentax reads as
            // the element's customContent dictionary.
            .accessibilityCustomContent(Text("entity_role"), Text(entity.role))
            .applyCustomContent(entity.customContent)
    }
}

// MARK: - Custom Content Application

extension View {
    /// Apply a dictionary of custom content entries as accessibility custom content.
    /// Each entry becomes an AXCustomContent item readable by agentax.
    @ViewBuilder
    func applyCustomContent(_ content: [String: String]) -> some View {
        // SwiftUI doesn't support dynamic modifier application, so we chain
        // them manually. For large dictionaries, we use a recursive approach.
        if content.isEmpty {
            self
        } else {
            self.modifier(CustomContentModifier(entries: content.sorted(by: { $0.key < $1.key })))
        }
    }
}

/// View modifier that applies sorted custom content entries as accessibility custom content.
private struct CustomContentModifier: ViewModifier {
    let entries: [(key: String, value: String)]

    func body(content: Content) -> some View {
        entries.reduce(AnyView(content)) { view, entry in
            AnyView(view.accessibilityCustomContent(Text(entry.key), Text(entry.value)))
        }
    }
}
