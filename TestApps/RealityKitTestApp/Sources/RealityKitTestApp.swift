import SwiftUI
import RealityKit
import Accessibility

/// Minimal macOS app for testing agentax's ability to read RealityKit
/// AccessibilityComponent data from the AX tree.
///
/// Run: swift run RealityKitTestApp
/// Test: agentax dump --app "RealityKitTestApp"
///       agentax query '$..[?(@.customContent.entity_type)]' --app RealityKitTestApp
///       agentax query '$..[?(@.label =~ /Player|Enemy/)]' --app RealityKitTestApp
@main
struct RealityKitTestApp: App {
    init() {
        // SPM executables don't have an app bundle, so NSWorkspace sees them as
        // background processes. Force regular activation policy so agentax can find us.
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

    var body: some View {
        VStack(spacing: 16) {
            // Standard SwiftUI controls for basic AX testing
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
                }
                .accessibilityIdentifier("attackButton")

                Button("Heal") {
                    playerHealth = min(100, playerHealth + 20)
                }
                .accessibilityIdentifier("healButton")

                Button("Reset") {
                    playerHealth = 100
                    enemyHealth = 80
                    score = 0
                }
                .accessibilityIdentifier("resetButton")
            }

            Text("Score: \(score)")
                .accessibilityIdentifier("scoreLabel")
                .accessibilityValue("\(score)")

            Divider()

            // RealityKit view with instrumented entities
            RealityView { content in
                // Create a player entity with full accessibility instrumentation
                let playerEntity = makeInstrumentedEntity(
                    name: "Player Character",
                    entityType: "player",
                    position: SIMD3<Float>(0, 0, -2),
                    health: 100,
                    color: .green
                )
                content.add(playerEntity)

                // Create an enemy entity
                let enemyEntity = makeInstrumentedEntity(
                    name: "Enemy Goblin",
                    entityType: "enemy",
                    position: SIMD3<Float>(3, 0, -4),
                    health: 80,
                    color: .red
                )
                content.add(enemyEntity)

                // Create terrain/environment entity
                let terrainEntity = makeInstrumentedEntity(
                    name: "Battle Arena Floor",
                    entityType: "terrain",
                    position: SIMD3<Float>(0, -1, -3),
                    health: nil,
                    color: .brown
                )
                content.add(terrainEntity)

                // Create a collectible item
                let itemEntity = makeInstrumentedEntity(
                    name: "Health Potion",
                    entityType: "item",
                    position: SIMD3<Float>(-2, 0.5, -3),
                    health: nil,
                    color: .blue
                )
                content.add(itemEntity)
            }
            .frame(height: 200)
            .accessibilityIdentifier("realityView")
        }
        .padding()
    }
}

/// Create a RealityKit entity with AccessibilityComponent configured for agentax testing.
/// This is the pattern apps must follow for agentax to see their 3D entities.
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

    // Add a simple mesh so the entity is visible
    let mesh = MeshResource.generateBox(size: 0.5)
    var material = SimpleMaterial()
    material.color = .init(tint: color)
    entity.components.set(ModelComponent(mesh: mesh, materials: [material]))

    // CRITICAL: Configure AccessibilityComponent so agentax can see this entity.
    // Without this, the entity is completely invisible to the AX tree.
    var ax = AccessibilityComponent()
    ax.isAccessibilityElement = true
    ax.label = "\(name)"
    if let health {
        ax.value = "Health: \(health)%"
    } else {
        ax.value = "\(entityType)"
    }

    // customContent is where RealityKit-specific data lives.
    // agentax reads these as key-value pairs in the element's customContent dictionary.
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
        let alive = health > 0 ? "true" : "false"
        content.append(.init(label: "alive", value: "\(alive)", importance: .high))
    }

    ax.customContent = content
    entity.components.set(ax)

    return entity
}
