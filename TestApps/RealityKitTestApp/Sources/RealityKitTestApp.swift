import SwiftUI
import RealityKit
import Accessibility
import AgentAXBridge

/// Test app that demonstrates BOTH approaches to RealityKit accessibility on macOS:
///
/// 1. **Direct AccessibilityComponent** — Standard RealityKit API. Works on visionOS;
///    on macOS, RealityView MAY bridge some metadata to the AX tree depending on the
///    hosting view's NSAccessibility implementation.
///
/// 2. **AgentAXBridge** — Guaranteed bridge via SwiftUI accessibility modifiers.
///    Creates invisible elements that always appear in the macOS AX tree.
///
/// Run: cd TestApps/RealityKitTestApp && swift run RealityKitTestApp
/// Test:
///   agentax dump --app "RealityKitTestApp"
///   agentax query '$..[?(@.identifier =~ /^rk-/)]' --app RealityKitTestApp
///   agentax query '$..[?(@.customContent.entity_type == "player")]' --app RealityKitTestApp
///   agentax inspect '$..[?(@.label == "Player Character")]' --app RealityKitTestApp
@main
struct RealityKitTestApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some SwiftUI.Scene {
        WindowGroup("AX Test Scene") {
            ContentView()
                .frame(minWidth: 600, minHeight: 400)
        }
    }
}

struct ContentView: View {
    @State private var playerHealth: Int = 100
    @State private var enemyHealth: Int = 80
    @State private var score: Int = 0
    @State private var tracker = EntityTracker()

    var body: some View {
        VStack(spacing: 16) {
            Text("RealityKit AX Test")
                .font(.title)
                .accessibilityIdentifier("headerText")

            HStack(spacing: 20) {
                VStack {
                    Text("Player Health: \(playerHealth)")
                        .accessibilityIdentifier("playerHealthLabel")
                    Slider(value: Binding(
                        get: { Double(playerHealth) },
                        set: { playerHealth = Int($0) }
                    ), in: 0...100)
                        .accessibilityIdentifier("playerHealthSlider")
                        .accessibilityValue("\(playerHealth)")
                }

                VStack {
                    Text("Enemy Health: \(enemyHealth)")
                        .accessibilityIdentifier("enemyHealthLabel")
                    Slider(value: Binding(
                        get: { Double(enemyHealth) },
                        set: { enemyHealth = Int($0) }
                    ), in: 0...100)
                        .accessibilityIdentifier("enemyHealthSlider")
                        .accessibilityValue("\(enemyHealth)")
                }
            }
            .padding(.horizontal)

            HStack(spacing: 12) {
                Button("Attack") {
                    enemyHealth = max(0, enemyHealth - 15)
                    score += 10
                    tracker.updateCustomContent(id: "enemy-1", key: "health", value: "\(enemyHealth)")
                    tracker.updateValue(id: "enemy-1", value: "Health: \(enemyHealth)%")
                }
                .accessibilityIdentifier("attackButton")

                Button("Heal") {
                    playerHealth = min(100, playerHealth + 20)
                    tracker.updateCustomContent(id: "player-1", key: "health", value: "\(playerHealth)")
                    tracker.updateValue(id: "player-1", value: "Health: \(playerHealth)%")
                }
                .accessibilityIdentifier("healButton")

                Button("Reset") {
                    playerHealth = 100
                    enemyHealth = 80
                    score = 0
                    registerEntities()
                }
                .accessibilityIdentifier("resetButton")
            }

            Text("Score: \(score)")
                .accessibilityIdentifier("scoreLabel")
                .accessibilityValue("\(score)")

            Divider()

            // RealityKit view — entities have AccessibilityComponent set directly.
            // On macOS, the hosting RealityView bridges entity accessibility to NSAccessibility.
            RealityView { content in
                content.add(makeInstrumentedEntity(
                    name: "Player Character",
                    entityType: "player",
                    position: SIMD3<Float>(0, 0, -2),
                    health: 100,
                    color: .green
                ))
                content.add(makeInstrumentedEntity(
                    name: "Enemy Goblin",
                    entityType: "enemy",
                    position: SIMD3<Float>(3, 0, -4),
                    health: 80,
                    color: .red
                ))
                content.add(makeInstrumentedEntity(
                    name: "Battle Arena Floor",
                    entityType: "terrain",
                    position: SIMD3<Float>(0, -1, -3),
                    health: nil,
                    color: .brown
                ))
                content.add(makeInstrumentedEntity(
                    name: "Health Potion",
                    entityType: "item",
                    position: SIMD3<Float>(-2, 0.5, -3),
                    health: nil,
                    color: .blue
                ))
            }
            .frame(height: 200)
            .accessibilityIdentifier("realityView")

            // AgentAXBridge overlay — guaranteed to appear in macOS AX tree.
            // Use this as fallback if direct AccessibilityComponent doesn't bridge.
            EntityAccessibilityOverlay(tracker: tracker)
        }
        .padding()
        .onAppear {
            registerEntities()
        }
    }

    private func registerEntities() {
        tracker.replaceAll([
            BridgedEntity(
                id: "player-1",
                label: "Player Character",
                value: "Health: \(playerHealth)%",
                role: "player",
                customContent: [
                    "entity_type": "player",
                    "position_x": "0.0", "position_y": "0.0", "position_z": "-2.0",
                    "health": "\(playerHealth)", "alive": "true",
                ]
            ),
            BridgedEntity(
                id: "enemy-1",
                label: "Enemy Goblin",
                value: "Health: \(enemyHealth)%",
                role: "enemy",
                customContent: [
                    "entity_type": "enemy",
                    "position_x": "3.0", "position_y": "0.0", "position_z": "-4.0",
                    "health": "\(enemyHealth)", "alive": "true",
                ]
            ),
            BridgedEntity(
                id: "terrain-1",
                label: "Battle Arena Floor",
                value: "terrain",
                role: "terrain",
                customContent: [
                    "entity_type": "terrain",
                    "position_x": "0.0", "position_y": "-1.0", "position_z": "-3.0",
                ]
            ),
            BridgedEntity(
                id: "item-1",
                label: "Health Potion",
                value: "item",
                role: "item",
                customContent: [
                    "entity_type": "item",
                    "position_x": "-2.0", "position_y": "0.5", "position_z": "-3.0",
                ]
            ),
        ])
    }
}

/// Create a RealityKit entity with AccessibilityComponent for direct AX bridging.
@MainActor
func makeInstrumentedEntity(
    name: String,
    entityType: String,
    position: SIMD3<Float>,
    health: Int?,
    color: NSColor
) -> Entity {
    let entity = Entity()
    entity.name = name
    entity.position = position

    let mesh = MeshResource.generateBox(size: 0.5)
    var material = SimpleMaterial()
    material.color = .init(tint: color)
    entity.components.set(ModelComponent(mesh: mesh, materials: [material]))

    // AccessibilityComponent — standard RealityKit API
    var ax = AccessibilityComponent()
    ax.isAccessibilityElement = true
    ax.label = "\(name)"
    if let health {
        ax.value = "Health: \(health)%"
    } else {
        ax.value = "\(entityType)"
    }

    let posX = String(format: "%.1f", position.x)
    let posY = String(format: "%.1f", position.y)
    let posZ = String(format: "%.1f", position.z)

    var content: [AccessibilityComponent.CustomContent] = [
        .init(label: "entity_type", value: "\(entityType)", importance: .high),
        .init(label: "position_x", value: "\(posX)", importance: .high),
        .init(label: "position_y", value: "\(posY)", importance: .high),
        .init(label: "position_z", value: "\(posZ)", importance: .high),
    ]

    if let health {
        content.append(.init(label: "health", value: "\(health)", importance: .high))
        content.append(.init(label: "alive", value: health > 0 ? "true" : "false", importance: .high))
    }

    ax.customContent = content
    entity.components.set(ax)

    return entity
}
