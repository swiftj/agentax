# Architecture

## Core Layer — AX Bridge

Wraps macOS Accessibility C API into Swift. Source: `Sources/AgentAX/Core/AXBridge.swift`

Key functions:
- `AXIsProcessTrusted()` — check permissions
- `AXUIElementCreateApplication(pid)` — create app reference
- `AXUIElementCopyAttributeValue(element, attribute)` — read: role, title, value, position, size, children, enabled, focused, identifier
- `AXUIElementCopyAttributeNames(element)` — list available attributes
- `AXUIElementCopyActionNames(element)` — list available actions (AXPress, AXConfirm, etc.)
- `AXUIElementPerformAction(element, action)` — execute actions
- `AXUIElementSetAttributeValue(element, attribute, value)` — set values (text fields)

Position/size return as `AXValue` objects wrapping `CGPoint`/`CGSize` — extract with `AXValueGetValue()`.

## State Capture

Source: `Sources/AgentAX/Core/SystemState.swift`

Recursively walk the AX tree:
1. Get running apps via `NSWorkspace.shared.runningApplications`
2. For each app, create `AXUIElementCreateApplication(pid)`
3. Traverse `AXChildren` recursively, capturing: role, title, value, position, size, enabled, focused, identifier, actions
4. For RealityKit entities with `AccessibilityComponent`: capture `customContent` key-value pairs (3D coordinates, game state, physics flags, health, inventory — whatever the developer injected)
5. Assign each element a UUID for O(1) lookup during action execution
6. Store live `AXUIElement` refs in a `[UUID: AXUIElement]` map so actions can resolve back to the real element
7. Apply timeouts (default 30s overall, 2s for menu bars to avoid triggering menu opening)
8. Only traverse children of visible elements by default (size > 0)
9. Enforce depth limit (default 50) to prevent infinite recursion from SwiftUI's internal view hierarchy quirks

## RealityKit Entity Visibility

RealityKit entities are **invisible to the AX tree by default**. The application under test must instrument them:

```swift
var accessibilityComponent = AccessibilityComponent()
accessibilityComponent.isAccessibilityElement = true
accessibilityComponent.label = "Player Character"
accessibilityComponent.value = "Health: 80%"
accessibilityComponent.traits = .button
accessibilityComponent.customContent = [
    .init(label: "position_x", value: "12.5"),
    .init(label: "position_y", value: "3.0"),
    .init(label: "position_z", value: "-7.2"),
    .init(label: "collision_group", value: "player"),
]
entity.components.set(accessibilityComponent)
```

agentax reads these `customContent` entries and exposes them in the serialized tree, giving the AI agent full 3D spatial awareness without any visual processing.

### Application Instrumentation Requirements

For agentax to test a SwiftUI/RealityKit app effectively:

1. **SwiftUI views**: Use `.accessibilityIdentifier()` on interactive elements. SwiftUI populates the AX tree automatically, but identifiers make targeted queries reliable.
2. **RealityKit entities**: Attach `AccessibilityComponent` with `isAccessibilityElement = true`, a descriptive `label`, current `value`, appropriate `traits`, and `customContent` for any proprietary state the agent needs to verify.
3. **Navigation state**: Ensure navigation destinations and sheet presentations are reflected in the AX tree (SwiftUI does this by default).
4. **Dynamic content**: Use `.accessibilityValue()` to expose changing state (toggle states, slider values, progress) so the agent can verify transitions.

## Element Selection — JSONPath

Source: `Sources/AgentAX/Selectors/JSONPathSelector.swift`

Serialize the captured `SystemState` to a dictionary tree, then support JSONPath queries:
```
$..[?(@.role=='AXButton')]                          # All buttons
$..[?(@.ax_identifier=='loginButton')]              # By accessibility identifier
$.processes[?(@.name=='MyApp')]..[?(@.role=='AXButton')]  # App-specific
$..[?(@.role=='AXTextField' && @.enabled==true)]    # Compound filters
$..[?(@.label=='Player Character')]                 # RealityKit entity by label
$..[?(@.customContent.position_x)]                  # Elements with 3D position data
```

Implement subset support: recursive descent `..`, child access `.`, filters `[?()]`. Use a Swift JSONPath library or build minimal support.

## Actions

Source: `Sources/AgentAX/Core/Actions.swift`, `Sources/AgentAX/Core/InputEvents.swift`

Actions resolve a `UIElement` (from JSONPath results) back to its live `AXUIElement` ref via the UUID map, then:
- **Click**: `AXUIElementPerformAction(ref, kAXPressAction)` — requires `AXPress` in element's action list
- **Set value**: `AXUIElementSetAttributeValue(ref, kAXValueAttribute, text)` — for text fields
- **Click at position**: `CGEvent`-based mouse down/up at coordinates
- **Right click / double click / drag**: `CGEvent`-based variants
- **Type text**: `CGEventCreateKeyboardEvent` + `CGEventKeyboardSetUnicodeString`
- **Key combination**: `CGEventCreateKeyboardEvent` with modifier flags (Cmd, Shift, Ctrl, Option)

## Output Format

Source: `Sources/AgentAX/Output/`

**Default: TOON** — Use the `ToonFormat` library to encode the AX tree. Achieves 30-60% token reduction vs JSON by eliminating braces/brackets and using indentation-based hierarchy with tabular arrays and key folding.

**Optional: JSON** — Standard `JSONEncoder` with `.sortedKeys` and `.prettyPrinted`. Selected via `--format json` flag on CLI or `format` parameter on MCP tools.

All MCP tool responses default to TOON. Provide a `format` parameter on MCP tools to allow JSON when requested.

## Performance Targets

- Full app AX tree capture: < 500ms for typical SwiftUI app
- Single element lookup by identifier: < 10ms (O(1) UUID map)
- Action execution (click/type): < 50ms
- Full dump → TOON serialize → stdout: < 1s
- Zero startup overhead (native binary, no interpreter, no dependency resolution)

## Design Decisions

- **TOON-first**: All output defaults to TOON format. JSON is opt-in. The Python version outputs only JSON which is token-expensive for LLMs.
- **Single binary, dual interface**: `agentax serve` starts MCP mode; all other subcommands are CLI.
- **No Python, no bridging**: Direct Swift calls to macOS Accessibility C API.
- **O(1) action resolution**: UUID-keyed map of live `AXUIElement` refs.
- **Timeout safety**: Configurable timeouts. Menu bar gets 2s to prevent triggering. Visibility filtering skips zero-size elements.
- **Depth limiting**: 50-level cap for SwiftUI's internal view hierarchy quirks.
- **RealityKit-aware**: Handles `AccessibilityComponent.customContent` for 3D state.
- **Test primitive design**: `snapshot_diff`, `wait_for_element`, and `assert_element_state` are single-call test primitives for agentic loops.
- **macOS permissions**: Requires Accessibility permission on the parent app. Check with `AXIsProcessTrusted()`.
