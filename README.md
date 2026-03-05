# agentax

**The fastest, most token-efficient accessibility testing harness for SwiftUI and RealityKit applications.**

<p>
  <img src="https://img.shields.io/badge/VERSION-0.1.1-blue?style=flat-square" alt="Version">
  <img src="https://img.shields.io/badge/Swift-6.0+-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift Version">
  <img src="https://img.shields.io/badge/-macOS%2014+-000000?style=flat-square&logo=apple&logoColor=white" alt="macOS 14+">
  <img src="https://img.shields.io/badge/LICENSE-MIT-green?style=flat-square" alt="License">
</p>
<p>
  <img src="https://img.shields.io/badge/MCP-COMPATIBLE-8A2BE2?style=flat-square" alt="MCP Compatible">
  <img src="https://img.shields.io/badge/TOON-DEFAULT_OUTPUT-ff6b6b?style=flat-square" alt="TOON Default">
  <img src="https://img.shields.io/badge/Agentic_Skills-5_AGENTS-orange?style=flat-square" alt="Agentic Skills">
</p>

---

agentax gives AI coding agents (Claude Code, Gemini CLI, Codex, etc.) full native access to the macOS Accessibility tree — enabling autonomous, deterministic UI testing and validation of SwiftUI and RealityKit applications without screenshots, and without vision models.

## Why agentax?

Vision-based testing (screenshots fed to multimodal LLMs) is fundamentally flawed for automated agent testing:

| | Vision-based | agentax |
|---|---|---|
| **Token cost** | Thousands per screenshot | ~10x fewer via AX tree |
| **Speed** | Seconds per interaction (capture + encode + API + parse) | Milliseconds (native API) |
| **Determinism** | Varies with theme, resolution, artifacts | Exact — OS guarantees element identity |
| **3D awareness** | Blind to RealityKit state | Full access via `AccessibilityComponent.customContent` |
| **Startup** | Usually an interpreter + dependency resolution | Native binary, zero overhead |

## Quick Start

### Install

```bash
git clone https://github.com/swiftj/agentax.git
cd agentax
swift build
```

### Set Up Accessibility Permissions

agentax requires macOS Accessibility permissions on the **parent application**:

`System Settings > Privacy & Security > Accessibility`

Add whichever app runs agentax — Terminal, VS Code, Claude Code, etc.

### Configure Claude Code

Add to your MCP settings (`.mcp.json` or Claude Code config):

```json
{
  "mcpServers": {
    "agentax": {
      "command": "/path/to/agentax",
      "args": ["serve"]
    }
  }
}
```

### Start Testing

Ask Claude Code things like:
- *"Find all buttons in my app"*
- *"Click the submit button"*
- *"Type 'hello' into the search field"*
- *"Show me the RealityKit entity state"*
- *"Test the login flow end-to-end"*

## Features

### Dual Interface: CLI + MCP Server

One binary serves both modes. `agentax serve` starts the MCP server (stdio or SSE); all other subcommands are CLI.

```bash
# CLI usage
agentax dump                          # Full AX tree (TOON format)
agentax dump --format json --app Safari
agentax query '$..[?(@.role=="AXButton")]'
agentax find buttons --title "Submit"
agentax action '$..[?(@.ax_identifier=="loginBtn")]' click
agentax info
agentax test                          # Verify permissions + basic functionality

# MCP server
agentax serve                         # stdio transport (for Claude Code)
agentax serve --transport sse         # SSE transport
```

### TOON-First Output

All output defaults to [TOON](https://github.com/toon-format/toon-swift) (Token-Oriented Object Notation) — achieving 30-60% fewer tokens than JSON by eliminating braces/brackets and using indentation-based hierarchy. JSON is available via `--format json`.

### RealityKit-Aware

RealityKit entities are invisible to the AX tree by default. When the app under test instruments them with `AccessibilityComponent`, agentax reads `customContent` key-value pairs to expose 3D coordinates, game state, physics data, and any proprietary state the developer injects:

```swift
var ax = AccessibilityComponent()
ax.isAccessibilityElement = true
ax.label = "Player Character"
ax.value = "Health: 80%"
ax.customContent = [
    .init(label: "position_x", value: "12.5"),
    .init(label: "position_y", value: "3.0"),
    .init(label: "position_z", value: "-7.2"),
]
entity.components.set(ax)
```

### MCP Tools

| Tool | Description |
|------|-------------|
| `find_elements` | Find UI elements matching a JSONPath selector |
| `find_elements_in_app` | Search within a specific application |
| `click_element_by_selector` | Click element via JSONPath (uses AXPress) |
| `click_at_position` | Click at screen coordinates |
| `type_text_to_element_by_selector` | Type text into element via JSONPath |
| `get_element_details` | Full element details including customContent |
| `list_running_applications` | List all running apps |
| `get_app_overview` | Quick overview of all apps and windows |
| `check_accessibility_permissions` | Verify AX permissions |
| `get_frontmost_app` | Get focused app and its window tree |
| `scroll_element` | Scroll within a scroll area |
| `activate_app` | Bring app to foreground |
| `get_menu_bar_items` | Get menu bar for a specific app |
| `dump_tree` | Full AX tree dump (TOON or JSON) |
| `wait_for_element` | Poll until selector matches (async transitions) |
| `assert_element_state` | Verify properties — pass/fail for test loops |
| `get_element_custom_content` | Extract RealityKit customContent |
| `snapshot_diff` | Capture, act, capture, return diff — single-call test |

### JSONPath Queries

```bash
$..[?(@.role=='AXButton')]                           # All buttons
$..[?(@.ax_identifier=='loginButton')]               # By identifier
$.processes[?(@.name=='MyApp')]..[?(@.role=='AXButton')]  # App-specific
$..[?(@.role=='AXTextField' && @.enabled==true)]     # Compound
$..[?(@.label=='Player Character')]                  # RealityKit entity
```

## Agentic Skills

agentax supports the [Agentic Skills](https://agentskills.io) specification. One command teaches any supported agent how to use agentax:

```bash
agentax skill install claude-code                # Project-level
agentax skill install claude-code --level user   # Global
agentax skill install gemini-cli --level user
agentax skill list                               # Check status
agentax skill update                             # Update all
```

### Supported Agents

| Agent | Format |
|-------|--------|
| Claude Code | `SKILL.md` + `references/` |
| Gemini CLI | `SKILL.md` + `references/` |
| Codex | `AGENTS.md` section |
| Antigravity | `SKILL.md` + `references/` |
| OpenCode | `SKILL.md` + `references/` |

## Application Instrumentation

For agentax to test your app effectively:

1. **SwiftUI views** — Use `.accessibilityIdentifier()` on interactive elements
2. **RealityKit entities** — Attach `AccessibilityComponent` with `isAccessibilityElement = true`, label, value, traits, and `customContent` for proprietary state
3. **Dynamic content** — Use `.accessibilityValue()` to expose changing state

## Architecture

agentax calls the macOS latest Accessibility (AX) API directly from Swift:

- **AX Bridge** — Wraps `AXUIElement*` functions for tree traversal and action execution
- **State Capture** — Recursive AX tree walk with timeout safety, depth limiting, and UUID-based element mapping for O(1) action resolution
- **JSONPath Selector** — Query the serialized tree with JSONPath expressions
- **TOON/JSON Output** — Serialize via `ToonFormat` library (default) or `JSONEncoder`
- **CGEvent Input** — Mouse clicks, keyboard input, drag operations via CoreGraphics

## Development

```bash
swift build                    # Build
swift test                     # Run tests
swift test --filter <TestName> # Single test

# Install git hooks (auto SemVer bumping)
./scripts/install-hooks.sh
```

### Version Bumping

Git hooks automatically manage SemVer on the `main` branch when `.swift` files change:

- Default: Patch bump (`0.1.0` -> `0.1.1`)
- `[minor]` in commit message: Minor bump (`0.1.0` -> `0.2.0`)
- `[major]` in commit message: Major bump (`0.1.0` -> `1.0.0`)
- `[skip-version]`: Skip bump
- `[release]`: Create GitHub release for patch bumps
- `[skip-release]`: Skip GitHub release
- Minor and major bumps always create a GitHub release

## Requirements

- macOS 14+
- Swift 6.0+
- Xcode 16+
- macOS Accessibility permissions granted to parent app

## License

MIT License
