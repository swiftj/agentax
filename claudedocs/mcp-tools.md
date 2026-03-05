# MCP Tools, Resources & CLI Reference

## MCP Server Tools

### Core tools (replicate from Python reference project)

| Tool | Description |
|------|-------------|
| `find_elements` | Find UI elements matching a JSONPath selector |
| `find_elements_in_app` | Search within a specific application (filtered, deeper traversal) |
| `click_element_by_selector` | Click element found via JSONPath (uses AXPress) |
| `click_at_position` | Click at screen coordinates (x, y) |
| `type_text_to_element_by_selector` | Type text into element found via JSONPath |
| `get_element_details` | Get full details for a specific element including customContent |
| `list_running_applications` | List all running apps with name, PID, bundle ID, active/hidden state |
| `get_app_overview` | Quick shallow overview of all apps and their windows |
| `check_accessibility_permissions` | Verify AX permissions are granted |

### Additional tools beyond the Python version

| Tool | Description |
|------|-------------|
| `get_frontmost_app` | Get the currently focused application and its window tree |
| `scroll_element` | Scroll within a scroll area element |
| `activate_app` | Bring an application to the foreground by name or bundle ID |
| `get_menu_bar_items` | Get menu bar items for a specific application |
| `dump_tree` | Full AX tree dump for an app in TOON or JSON format |
| `wait_for_element` | Poll until an element matching a selector appears (with timeout) — essential for async UI transitions |
| `assert_element_state` | Verify element properties match expected values — returns pass/fail for agent test loops |
| `get_element_custom_content` | Extract RealityKit `customContent` key-value pairs from a specific element |
| `snapshot_diff` | Capture AX tree, perform action, capture again, return diff — single-call test primitive |

## MCP Server Resources

| Resource URI | Description |
|-------------|-------------|
| `ui://state/current` | Current UI overview (shallow) |
| `ui://state/process/{name}` | Deep UI state for a specific process |

## CLI Commands

```
agentax serve                    # Start MCP server (stdio)
agentax serve --transport sse    # Start MCP server (SSE)
agentax dump                     # Dump full AX tree (TOON default)
agentax dump --format json       # Dump as JSON
agentax dump --app Safari        # Dump single app
agentax dump -o state.toon       # Save to file
agentax query <jsonpath>         # Query elements via JSONPath
agentax find buttons             # Find elements by type
agentax find buttons --title OK  # Filter by title
agentax action <jsonpath> click  # Perform action on matched elements
agentax action <jsonpath> set_value --value "text"
agentax info                     # System state summary
agentax test                     # Test AX permissions and basic functionality
agentax skill install <agent>    # Install agentic skill (see claudedocs/agentic-skills.md)
agentax skill uninstall <agent>
agentax skill list
agentax skill update [agent]
agentax skill show
```
