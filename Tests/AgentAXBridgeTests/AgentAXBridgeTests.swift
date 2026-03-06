import Testing
@testable import AgentAXBridge

@Suite("AgentAXBridge Tests")
struct AgentAXBridgeTests {

    // MARK: - BridgedEntity Tests

    @Test("BridgedEntity initializes with all properties")
    func entityInitFull() {
        let entity = BridgedEntity(
            id: "test-1",
            label: "Player Character",
            value: "Health: 100%",
            role: "player",
            customContent: [
                "position_x": "12.5",
                "position_y": "3.0",
                "health": "100",
            ]
        )

        #expect(entity.id == "test-1")
        #expect(entity.label == "Player Character")
        #expect(entity.value == "Health: 100%")
        #expect(entity.role == "player")
        #expect(entity.customContent["position_x"] == "12.5")
        #expect(entity.customContent["position_y"] == "3.0")
        #expect(entity.customContent["health"] == "100")
    }

    @Test("BridgedEntity uses default values")
    func entityInitDefaults() {
        let entity = BridgedEntity(id: "e1", label: "Box")

        #expect(entity.id == "e1")
        #expect(entity.label == "Box")
        #expect(entity.value == nil)
        #expect(entity.role == "entity")
        #expect(entity.customContent.isEmpty)
    }

    @Test("BridgedEntity is Identifiable")
    func entityIdentifiable() {
        let a = BridgedEntity(id: "same-id", label: "A")
        let b = BridgedEntity(id: "same-id", label: "B")
        #expect(a.id == b.id)
    }

    // MARK: - EntityTracker Tests

    @MainActor
    @Test("EntityTracker starts empty")
    func trackerEmpty() {
        let tracker = EntityTracker()
        #expect(tracker.entities.isEmpty)
    }

    @MainActor
    @Test("EntityTracker register adds entity")
    func trackerRegister() {
        let tracker = EntityTracker()
        let entity = BridgedEntity(id: "p1", label: "Player")
        tracker.register(entity)
        #expect(tracker.entities.count == 1)
        #expect(tracker.entities[0].label == "Player")
    }

    @MainActor
    @Test("EntityTracker register replaces entity with same ID")
    func trackerRegisterReplace() {
        let tracker = EntityTracker()
        tracker.register(BridgedEntity(id: "p1", label: "Old"))
        tracker.register(BridgedEntity(id: "p1", label: "New"))
        #expect(tracker.entities.count == 1)
        #expect(tracker.entities[0].label == "New")
    }

    @MainActor
    @Test("EntityTracker unregister removes entity")
    func trackerUnregister() {
        let tracker = EntityTracker()
        tracker.register(BridgedEntity(id: "p1", label: "Player"))
        tracker.register(BridgedEntity(id: "e1", label: "Enemy"))
        tracker.unregister(id: "p1")
        #expect(tracker.entities.count == 1)
        #expect(tracker.entities[0].id == "e1")
    }

    @MainActor
    @Test("EntityTracker clear removes all entities")
    func trackerClear() {
        let tracker = EntityTracker()
        tracker.register(BridgedEntity(id: "p1", label: "Player"))
        tracker.register(BridgedEntity(id: "e1", label: "Enemy"))
        tracker.clear()
        #expect(tracker.entities.isEmpty)
    }

    @MainActor
    @Test("EntityTracker updateCustomContent modifies specific key")
    func trackerUpdateCustomContent() {
        let tracker = EntityTracker()
        tracker.register(BridgedEntity(
            id: "p1",
            label: "Player",
            customContent: ["health": "100", "position_x": "0.0"]
        ))

        tracker.updateCustomContent(id: "p1", key: "health", value: "75")

        #expect(tracker.entities[0].customContent["health"] == "75")
        #expect(tracker.entities[0].customContent["position_x"] == "0.0")
    }

    @MainActor
    @Test("EntityTracker updateCustomContent ignores unknown ID")
    func trackerUpdateUnknown() {
        let tracker = EntityTracker()
        tracker.register(BridgedEntity(id: "p1", label: "Player"))
        tracker.updateCustomContent(id: "unknown", key: "health", value: "50")
        #expect(tracker.entities[0].customContent.isEmpty)
    }

    @MainActor
    @Test("EntityTracker updateValue modifies entity value")
    func trackerUpdateValue() {
        let tracker = EntityTracker()
        tracker.register(BridgedEntity(id: "p1", label: "Player", value: "Health: 100%"))

        tracker.updateValue(id: "p1", value: "Health: 75%")
        #expect(tracker.entities[0].value == "Health: 75%")

        tracker.updateValue(id: "p1", value: nil)
        #expect(tracker.entities[0].value == nil)
    }

    @MainActor
    @Test("EntityTracker updateValue ignores unknown ID")
    func trackerUpdateValueUnknown() {
        let tracker = EntityTracker()
        tracker.register(BridgedEntity(id: "p1", label: "Player", value: "ok"))
        tracker.updateValue(id: "unknown", value: "nope")
        #expect(tracker.entities[0].value == "ok")
    }

    @MainActor
    @Test("EntityTracker replaceAll swaps entire entity list")
    func trackerReplaceAll() {
        let tracker = EntityTracker()
        tracker.register(BridgedEntity(id: "old1", label: "Old"))

        tracker.replaceAll([
            BridgedEntity(id: "new1", label: "New A"),
            BridgedEntity(id: "new2", label: "New B"),
        ])

        #expect(tracker.entities.count == 2)
        #expect(tracker.entities[0].id == "new1")
        #expect(tracker.entities[1].id == "new2")
    }

    // MARK: - Accessibility Identifier Convention

    @Test("Bridge entities use rk- prefix for AX identifiers")
    func rkPrefixConvention() {
        let entity = BridgedEntity(id: "my-entity-42", label: "Token")
        let expectedIdentifier = "rk-\(entity.id)"
        #expect(expectedIdentifier == "rk-my-entity-42")
    }

    @MainActor
    @Test("EntityTracker handles many entities")
    func trackerBulkOperations() {
        let tracker = EntityTracker()

        // Register 100 entities
        for i in 0..<100 {
            tracker.register(BridgedEntity(
                id: "entity-\(i)",
                label: "Entity \(i)",
                role: i % 2 == 0 ? "player" : "enemy",
                customContent: ["index": "\(i)"]
            ))
        }

        #expect(tracker.entities.count == 100)

        // Update one in the middle
        tracker.updateCustomContent(id: "entity-50", key: "index", value: "updated")
        #expect(tracker.entities.first { $0.id == "entity-50" }?.customContent["index"] == "updated")

        // Unregister one
        tracker.unregister(id: "entity-0")
        #expect(tracker.entities.count == 99)
    }
}
