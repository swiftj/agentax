# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is agentax

Native Swift accessibility testing harness for SwiftUI and RealityKit applications. Gives AI agents (Claude Code, etc.) deterministic, token-efficient access to the macOS AX tree — replacing screenshot-based testing entirely. Single binary that serves as both CLI tool and MCP server.

Replaces the Python-based [macos-ui-automation-mcp](https://github.com/mb-dev/macos-ui-automation-mcp) with 100% native Swift. No PyObjC, no Python runtime.

## Build & Test

```bash
swift build                        # Build
swift run agentax <command>        # Run CLI
swift run agentax serve            # MCP server (stdio)
swift test                         # All tests
swift test --filter <TestName>     # Single test
```

**IMPORTANT**: Always use `swift build` / `swift test` — NEVER invoke `swiftc` directly. Direct `swiftc` calls dump `.o`, `.d`, `.dia`, `.swiftdeps` artifacts into the working directory instead of `.build/`. All build output must go through SPM into `.build/`.

## Platform & Stack

- macOS 14+, Swift 6.0+, Xcode 16+
- Apple `ApplicationServices` framework for AX API (`AXUIElement*` functions)
- Apple `CoreGraphics` for `CGEvent`-based input (mouse, keyboard)
- `AppKit` / `NSWorkspace` for app enumeration

## Key Constraints

- **TOON-first output**: Default all output (CLI and MCP) to TOON format via `ToonFormat` library. JSON is opt-in (`--format json`). TOON achieves 30-60% fewer tokens than JSON.
- **No Python, no bridging**: Call macOS Accessibility C API directly from Swift. No PyObjC, no FFI.
- **O(1) action resolution**: Each captured element gets a UUID. Live `AXUIElement` refs stored in `[UUID: AXUIElement]` map. Actions resolve without re-traversing.
- **Depth limit 50**: Prevents infinite recursion from SwiftUI's internal view hierarchy quirks.
- **Timeout safety**: 30s default for tree traversal, 2s for menu bars (prevents triggering menu opening).
- **RealityKit-aware**: Read `AccessibilityComponent.customContent` to expose 3D state (coordinates, physics, game data) that no vision model can infer from pixels.

## Dependencies (Package.swift)

- **ToonFormat** — `https://github.com/toon-format/toon-swift` (TOON v3.0 encoder)
- **swift-argument-parser** — `https://github.com/apple/swift-argument-parser` (CLI)
- **MCP Swift SDK** — `https://github.com/modelcontextprotocol/swift-sdk` (evaluate maturity; fallback: implement stdio JSON-RPC directly)

## Package Structure

```
Sources/
  AgentAX/                    # Library target
    Core/                     # AXBridge, SystemState, Actions, InputEvents
    Models/                   # UIElement, SystemState models, AXTypes constants
    Selectors/                # JSONPathSelector
    Output/                   # TOONEncoder, JSONEncoder
    Skill/                    # Agentic skill install system (see claudedocs/agentic-skills.md)
    Interfaces/               # CLI (ArgumentParser), MCPServer
  agentax-cli/                # Executable target (thin entry point)
Tests/AgentAXTests/
```

## Detailed Documentation

Read these before working on the corresponding areas:

- `claudedocs/architecture.md` — AX Bridge API, state capture algorithm, element selection (JSONPath), action execution, output encoding, performance targets
- `claudedocs/mcp-tools.md` — All MCP tools and resources with parameters, plus CLI command reference
- `claudedocs/agentic-skills.md` — Skill system: supported agents, install/uninstall mechanics, embedded content, marker-based AGENTS.md sections
- `claudedocs/ax_research.md` — Original research: why AX beats vision, RealityKit AccessibilityComponent instrumentation, TOON format spec, tool comparison

## Quick Reference

The agent testing loop: dump AX tree → JSONPath query → perform action → re-dump → verify state change. Tools like `snapshot_diff`, `wait_for_element`, and `assert_element_state` collapse multi-step verification into single calls.

RealityKit entities are invisible to the AX tree unless the app instruments them with `AccessibilityComponent`. See `claudedocs/architecture.md` for the instrumentation pattern.

macOS Accessibility permission must be granted to the parent app (Terminal, Claude Code, VS Code). Check with `AXIsProcessTrusted()`.
