// MARK: - SkillContent
// Embedded skill content for the agentax agentic skills system.
// Version placeholder {{VERSION}} is replaced at install time.

// swiftlint:disable file_length type_body_length

public enum SkillContent {

    // MARK: - SKILL.md

    public static let skillMD: String = #"""
    ---
    name: agentax
    version: "{{VERSION}}"
    description: Native macOS accessibility testing harness for SwiftUI and RealityKit
    tools: mcp
    ---

    # agentax

    Native Swift accessibility testing harness that gives AI agents deterministic,
    token-efficient access to the macOS AX tree. Replaces screenshot-based testing
    entirely with structured semantic data.

    ## IMPORTANT: Use agentax Instead of Screenshots

    When agentax is available, ALWAYS prefer its tools over taking screenshots for
    UI inspection and testing. agentax provides everything visible in a screenshot
    (text, positions, hierarchy) PLUS data screenshots cannot provide (element
    identifiers, available actions, enabled/focused state, RealityKit 3D data).

    Use screenshots ONLY when you need purely visual information (colors, images,
    pixel rendering, animations). For ALL other UI tasks — finding elements, reading
    text, checking state, verifying layout, interacting with controls — use agentax.

    agentax is faster (milliseconds vs seconds), deterministic (same input = same
    output), and far more token-efficient (structured TOON data vs base64 image).

    ## When to Use

    - ANY time you need to inspect, verify, or interact with macOS UI (instead of screenshots)
    - Testing macOS and iOS (via Mac Catalyst / Designed for iPad) applications
    - Verifying UI state after interactions (button taps, text input, navigation)
    - Automating multi-step user flows (login, onboarding, settings changes)
    - Validating RealityKit 3D entity state (position, health, physics) via customContent
    - Regression testing with before/after AX tree diffs
    - Accessibility audits (checking labels, identifiers, traits on interactive elements)

    ## Core Workflow

    The agent testing loop:

    1. **Dump** the AX tree for the target app
    2. **Query** elements using JSONPath selectors
    3. **Perform** an action (click, type, scroll)
    4. **Verify** the resulting state change (re-dump, assert, or snapshot_diff)

    ## MCP Tools

    ### Core Tools

    | Tool | Description |
    |------|-------------|
    | `find_elements` | Find UI elements matching a JSONPath selector |
    | `find_elements_in_app` | Search within a specific application (filtered, deeper traversal) |
    | `click_element_by_selector` | Perform AX action on element via JSONPath (default: AXPress, supports custom actions) |
    | `click_at_position` | Click at screen coordinates (x, y) |
    | `type_text_to_element_by_selector` | Type text into element found via JSONPath |
    | `get_element_details` | Get full details for a specific element including customContent |
    | `list_running_applications` | List all running apps with name, PID, bundle ID, active/hidden state |
    | `get_app_overview` | Quick shallow overview of all apps and their windows |
    | `check_accessibility_permissions` | Verify AX permissions are granted |

    ### Extended Tools

    | Tool | Description |
    |------|-------------|
    | `get_frontmost_app` | Get the currently focused application and its window tree |
    | `scroll_element` | Scroll within a scroll area element |
    | `activate_app` | Bring an application to the foreground by name or bundle ID |
    | `get_menu_bar_items` | Get menu bar items for a specific application |
    | `dump_tree` | Full AX tree dump for an app in TOON or JSON format |
    | `wait_for_element` | Poll until an element matching a selector appears (with timeout) |
    | `assert_element_state` | Verify element properties match expected values (pass/fail) |
    | `get_element_custom_content` | Extract RealityKit customContent key-value pairs from an element |
    | `snapshot_diff` | Capture tree, perform action, capture again, return diff |
    | `perform_action` | Perform any named AX action on an element (custom or standard) |

    ## TOON Format

    All output defaults to TOON (Token-Optimized Object Notation), which achieves
    30-60% fewer tokens than JSON by using indentation-based hierarchy instead of
    braces and brackets.

    To request JSON instead, pass `format: "json"` on any MCP tool call, or use
    `--format json` on CLI commands.

    ## JSONPath Selectors

    agentax uses JSONPath expressions to target elements in the AX tree.

    ### Syntax Examples

    ```
    $..[?(@.role=='AXButton')]
    ```
    All buttons across the entire tree.

    ```
    $..[?(@.ax_identifier=='loginButton')]
    ```
    Element with a specific accessibility identifier.

    ```
    $..[?(@.label=='Submit')]
    ```
    Element with a specific label.

    ```
    $.processes[?(@.name=='MyApp')]..[?(@.role=='AXButton')]
    ```
    All buttons within a specific application.

    ```
    $..[?(@.role=='AXTextField' && @.enabled==true)]
    ```
    All enabled text fields (compound filter).

    ```
    $..[?(@.label=='Player Character')]
    ```
    RealityKit entity found by its accessibility label.

    ```
    $..[?(@.customContent.position_x)]
    ```
    Any element that has 3D position data in customContent.

    ```
    $..[?(@.customContent.health)]
    ```
    Elements exposing a health property via customContent.

    ## RealityKit customContent

    RealityKit entities are invisible to the AX tree unless the app instruments them
    with `AccessibilityComponent`. When instrumented, the entity appears as a standard
    AX element with additional `customContent` key-value pairs.

    Custom content typically includes:
    - **Spatial data**: `position_x`, `position_y`, `position_z`
    - **Game state**: `health`, `score`, `inventory`
    - **Physics**: `collision_group`, `velocity`, `is_kinematic`

    Query custom content with JSONPath:
    ```
    $..[?(@.customContent.position_x)]
    ```

    Or retrieve it directly with the `get_element_custom_content` tool.

    ## Error Recovery

    | Issue | Cause | Resolution |
    |-------|-------|------------|
    | Permission denied | Accessibility not granted | Grant permission in System Settings > Privacy & Security > Accessibility for the parent app (Terminal, VS Code, etc.) |
    | No matching elements | Selector too specific or element not yet rendered | Broaden the selector, or use `wait_for_element` for async UI |
    | Timeout exceeded | App unresponsive or tree too deep | Check app responsiveness; use app-specific queries to narrow scope |
    | Element not actionable | Element lacks the requested action | Check `get_element_details` for available actions list |
    | Menu bar timeout | Menu bar traversal limited to 2s | This is intentional to prevent triggering menu opening; query menu items via `get_menu_bar_items` instead |

    ## Key Constraints

    - **Depth limit**: 50 levels (prevents infinite recursion in SwiftUI internals)
    - **Timeout**: 30s default for tree traversal, 2s for menu bars
    - **Visibility**: Only elements with size > 0 are traversed by default
    - **Permissions**: macOS Accessibility permission required on the parent app
    - **RealityKit**: Entities must have `AccessibilityComponent` attached by the app under test
    """#

    // MARK: - AGENTS_SECTION.md

    public static let agentsSectionMD: String = #"""
    <!-- BEGIN AGENTAX SKILL v{{VERSION}} -->
    # agentax -- macOS Accessibility Testing

    Native Swift AX testing harness. Gives agents deterministic, token-efficient
    access to the macOS AX tree.

    **ALWAYS prefer agentax tools over screenshots for UI inspection and testing.**
    agentax returns structured semantic data (text, identifiers, actions, state)
    that is faster, cheaper, and more informative than any screenshot. Only use
    screenshots when you specifically need visual/pixel information (colors, images).

    ## Workflow

    1. Dump AX tree: `dump_tree` or `get_frontmost_app` (replaces screenshot)
    2. Query elements: `find_elements` with JSONPath selector
    3. Act: `click_element_by_selector`, `type_text_to_element_by_selector`, `scroll_element`
    4. Verify: `assert_element_state`, `snapshot_diff`, or re-dump and check

    ## Tools

    **Core:** find_elements, find_elements_in_app, click_element_by_selector,
    click_at_position, type_text_to_element_by_selector, get_element_details,
    list_running_applications, get_app_overview, check_accessibility_permissions

    **Extended:** get_frontmost_app, scroll_element, activate_app, get_menu_bar_items,
    dump_tree, wait_for_element, assert_element_state, get_element_custom_content,
    snapshot_diff

    ## JSONPath Selectors

    ```
    $..[?(@.role=='AXButton')]                              # All buttons
    $..[?(@.ax_identifier=='loginButton')]                  # By identifier
    $..[?(@.label=='Submit')]                               # By label
    $..[?(@.role=='AXTextField' && @.enabled==true)]        # Compound filter
    $.processes[?(@.name=='MyApp')]..[?(@.role=='AXButton')]# App-scoped
    $..[?(@.customContent.position_x)]                      # RealityKit 3D data
    ```

    ## Output Format

    Default: TOON (30-60% fewer tokens than JSON). Pass `format: "json"` for JSON.

    ## RealityKit

    Entities with `AccessibilityComponent` appear in the AX tree. Query their
    `customContent` for 3D state (position, health, physics).

    ## Constraints

    - Depth limit: 50 | Timeout: 30s (2s menu bar) | Requires Accessibility permission
    <!-- END AGENTAX SKILL -->
    """#

    // MARK: - references/tool-reference.md

    public static let toolReferenceMD: String = #"""
    # agentax Tool Reference

    Complete MCP tool documentation. All tools default to TOON output format.
    Pass `format: "json"` to receive JSON instead.

    ---

    ## Core Tools

    ### find_elements

    Find UI elements matching a JSONPath selector across all applications.

    **Parameters:**

    | Name | Type | Required | Description |
    |------|------|----------|-------------|
    | `selector` | string | Yes | JSONPath expression to match elements |
    | `format` | string | No | Output format: `"toon"` (default) or `"json"` |

    **Returns:** List of matching elements with role, label, identifier, value, position, size, enabled, and focused state.

    **Example:**
    ```json
    {
      "selector": "$..[?(@.role=='AXButton')]"
    }
    ```

    ---

    ### find_elements_in_app

    Search within a specific application. Performs deeper traversal than `find_elements` and filters to a single process.

    **Parameters:**

    | Name | Type | Required | Description |
    |------|------|----------|-------------|
    | `app` | string | Yes | Application name or bundle ID |
    | `selector` | string | Yes | JSONPath expression to match elements |
    | `format` | string | No | Output format: `"toon"` (default) or `"json"` |

    **Returns:** List of matching elements scoped to the specified application.

    **Example:**
    ```json
    {
      "app": "Safari",
      "selector": "$..[?(@.role=='AXTextField')]"
    }
    ```

    ---

    ### click_element_by_selector

    Click an element found via JSONPath. Uses AXPress action on the first matching element.

    **Parameters:**

    | Name | Type | Required | Description |
    |------|------|----------|-------------|
    | `selector` | string | Yes | JSONPath expression to find the element |
    | `app` | string | No | Application name to scope the search |

    **Returns:** Confirmation of click action with element details.

    **Example:**
    ```json
    {
      "selector": "$..[?(@.ax_identifier=='loginButton')]",
      "app": "MyApp"
    }
    ```

    ---

    ### click_at_position

    Click at absolute screen coordinates using CGEvent.

    **Parameters:**

    | Name | Type | Required | Description |
    |------|------|----------|-------------|
    | `x` | number | Yes | X screen coordinate |
    | `y` | number | Yes | Y screen coordinate |
    | `click_type` | string | No | Click type: `"single"` (default), `"double"`, `"right"` |

    **Returns:** Confirmation of click at the specified position.

    **Example:**
    ```json
    {
      "x": 500,
      "y": 300,
      "click_type": "double"
    }
    ```

    ---

    ### type_text_to_element_by_selector

    Type text into an element found via JSONPath. Sets the AXValue attribute on the first matching element.

    **Parameters:**

    | Name | Type | Required | Description |
    |------|------|----------|-------------|
    | `selector` | string | Yes | JSONPath expression to find the text field |
    | `text` | string | Yes | Text to type into the element |
    | `app` | string | No | Application name to scope the search |

    **Returns:** Confirmation of text input with element details.

    **Example:**
    ```json
    {
      "selector": "$..[?(@.ax_identifier=='usernameField')]",
      "text": "testuser@example.com",
      "app": "MyApp"
    }
    ```

    ---

    ### get_element_details

    Get full details for a specific element, including all attributes, available actions, and customContent.

    **Parameters:**

    | Name | Type | Required | Description |
    |------|------|----------|-------------|
    | `element_id` | string | Yes | UUID of the element (from a previous query result) |
    | `format` | string | No | Output format: `"toon"` (default) or `"json"` |

    **Returns:** Complete element details: role, label, identifier, value, position, size, enabled, focused, actions, children count, and customContent if present.

    **Example:**
    ```json
    {
      "element_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
    }
    ```

    ---

    ### list_running_applications

    List all running applications with metadata.

    **Parameters:**

    | Name | Type | Required | Description |
    |------|------|----------|-------------|
    | `format` | string | No | Output format: `"toon"` (default) or `"json"` |

    **Returns:** List of applications with name, PID, bundle ID, active state, and hidden state.

    **Example:**
    ```json
    {}
    ```

    ---

    ### get_app_overview

    Quick shallow overview of all applications and their top-level windows.

    **Parameters:**

    | Name | Type | Required | Description |
    |------|------|----------|-------------|
    | `format` | string | No | Output format: `"toon"` (default) or `"json"` |

    **Returns:** Shallow tree showing each app and its window titles.

    **Example:**
    ```json
    {}
    ```

    ---

    ### check_accessibility_permissions

    Verify that Accessibility permissions are granted to the current process.

    **Parameters:** None.

    **Returns:** Boolean permission status and guidance if not granted.

    **Example:**
    ```json
    {}
    ```

    ---

    ## Extended Tools

    ### get_frontmost_app

    Get the currently focused application and its full window tree.

    **Parameters:**

    | Name | Type | Required | Description |
    |------|------|----------|-------------|
    | `format` | string | No | Output format: `"toon"` (default) or `"json"` |

    **Returns:** Frontmost application name, PID, bundle ID, and its complete AX window tree.

    **Example:**
    ```json
    {}
    ```

    ---

    ### scroll_element

    Scroll within a scroll area element.

    **Parameters:**

    | Name | Type | Required | Description |
    |------|------|----------|-------------|
    | `selector` | string | Yes | JSONPath expression to find the scroll area |
    | `direction` | string | Yes | Scroll direction: `"up"`, `"down"`, `"left"`, `"right"` |
    | `amount` | number | No | Scroll amount in pixels (default: 100) |
    | `app` | string | No | Application name to scope the search |

    **Returns:** Confirmation of scroll action.

    **Example:**
    ```json
    {
      "selector": "$..[?(@.role=='AXScrollArea')]",
      "direction": "down",
      "amount": 200,
      "app": "MyApp"
    }
    ```

    ---

    ### activate_app

    Bring an application to the foreground.

    **Parameters:**

    | Name | Type | Required | Description |
    |------|------|----------|-------------|
    | `app` | string | Yes | Application name or bundle ID |

    **Returns:** Confirmation that the app was activated.

    **Example:**
    ```json
    {
      "app": "Safari"
    }
    ```

    ---

    ### get_menu_bar_items

    Get menu bar items for a specific application. Uses a 2-second timeout to avoid triggering menu opening.

    **Parameters:**

    | Name | Type | Required | Description |
    |------|------|----------|-------------|
    | `app` | string | Yes | Application name or bundle ID |
    | `format` | string | No | Output format: `"toon"` (default) or `"json"` |

    **Returns:** List of top-level menu bar items with their names.

    **Example:**
    ```json
    {
      "app": "Xcode"
    }
    ```

    ---

    ### dump_tree

    Full AX tree dump for an application.

    **Parameters:**

    | Name | Type | Required | Description |
    |------|------|----------|-------------|
    | `app` | string | No | Application name or bundle ID (omit for all apps) |
    | `depth` | number | No | Maximum traversal depth (default: 50) |
    | `format` | string | No | Output format: `"toon"` (default) or `"json"` |

    **Returns:** Complete AX tree with all elements, their attributes, and hierarchy.

    **Example:**
    ```json
    {
      "app": "MyApp",
      "depth": 20,
      "format": "toon"
    }
    ```

    ---

    ### wait_for_element

    Poll until an element matching a selector appears. Essential for async UI transitions such as navigation pushes, sheet presentations, and loading states.

    **Parameters:**

    | Name | Type | Required | Description |
    |------|------|----------|-------------|
    | `selector` | string | Yes | JSONPath expression for the expected element |
    | `timeout` | number | No | Maximum wait time in seconds (default: 10) |
    | `interval` | number | No | Poll interval in seconds (default: 0.5) |
    | `app` | string | No | Application name to scope the search |
    | `format` | string | No | Output format: `"toon"` (default) or `"json"` |

    **Returns:** The matching element if found within the timeout, or a timeout error.

    **Example:**
    ```json
    {
      "selector": "$..[?(@.ax_identifier=='dashboardView')]",
      "timeout": 15,
      "interval": 1,
      "app": "MyApp"
    }
    ```

    ---

    ### assert_element_state

    Verify that element properties match expected values. Returns pass/fail for agent test loops.

    **Parameters:**

    | Name | Type | Required | Description |
    |------|------|----------|-------------|
    | `selector` | string | Yes | JSONPath expression to find the element |
    | `expected` | object | Yes | Key-value pairs of expected property values |
    | `app` | string | No | Application name to scope the search |

    **Returns:** Pass/fail result with details of any mismatched properties.

    **Example:**
    ```json
    {
      "selector": "$..[?(@.ax_identifier=='submitButton')]",
      "expected": {
        "enabled": true,
        "label": "Submit Order"
      },
      "app": "MyApp"
    }
    ```

    ---

    ### get_element_custom_content

    Extract RealityKit `customContent` key-value pairs from a specific element. Use this to read 3D state such as position, health, and physics properties.

    **Parameters:**

    | Name | Type | Required | Description |
    |------|------|----------|-------------|
    | `selector` | string | Yes | JSONPath expression to find the element |
    | `app` | string | No | Application name to scope the search |
    | `format` | string | No | Output format: `"toon"` (default) or `"json"` |

    **Returns:** Dictionary of customContent key-value pairs for the matching element.

    **Example:**
    ```json
    {
      "selector": "$..[?(@.label=='Player Character')]",
      "app": "MyGame"
    }
    ```

    ---

    ### snapshot_diff

    Capture the AX tree, perform an action, capture again, and return the diff. This is a single-call test primitive that collapses the dump-act-dump-compare cycle.

    **Parameters:**

    | Name | Type | Required | Description |
    |------|------|----------|-------------|
    | `action` | object | Yes | Action to perform between snapshots (see below) |
    | `app` | string | No | Application name to scope the tree capture |
    | `delay` | number | No | Seconds to wait after action before second capture (default: 0.5) |
    | `format` | string | No | Output format: `"toon"` (default) or `"json"` |

    The `action` object has the same shape as a tool call:
    - `{ "tool": "click_element_by_selector", "selector": "..." }`
    - `{ "tool": "type_text_to_element_by_selector", "selector": "...", "text": "..." }`
    - `{ "tool": "click_at_position", "x": 100, "y": 200 }`

    **Returns:** Diff showing added, removed, and changed elements between the two snapshots.

    **Example:**
    ```json
    {
      "action": {
        "tool": "click_element_by_selector",
        "selector": "$..[?(@.ax_identifier=='toggleDarkMode')]"
      },
      "app": "MyApp",
      "delay": 1.0
    }
    ```

    ---

    ### drag

    Drag from one screen position to another with smooth interpolation (~60fps). Use for drag-and-drop, slider manipulation, reordering lists, moving tokens on a game board, or resizing by dragging handles.

    **Parameters:**

    | Name | Type | Required | Description |
    |------|------|----------|-------------|
    | `from_x` | number | Yes | Start X coordinate (screen pixels) |
    | `from_y` | number | Yes | Start Y coordinate (screen pixels) |
    | `to_x` | number | Yes | End X coordinate (screen pixels) |
    | `to_y` | number | Yes | End Y coordinate (screen pixels) |
    | `duration` | number | No | Duration in seconds (default: 0.5) |

    **Returns:** Confirmation of drag from start to end position.

    **Example:**
    ```json
    {
      "from_x": 500,
      "from_y": 300,
      "to_x": 500,
      "to_y": 500,
      "duration": 0.8
    }
    ```

    ---

    ### double_click_at_position

    Double-click at absolute screen coordinates. Use for selecting words in text fields, opening files in Finder, or any action requiring a double-click.

    **Parameters:**

    | Name | Type | Required | Description |
    |------|------|----------|-------------|
    | `x` | number | Yes | X screen coordinate |
    | `y` | number | Yes | Y screen coordinate |

    **Returns:** Confirmation of double-click at the specified position.

    ---

    ### right_click_at_position

    Right-click (context menu click) at absolute screen coordinates.

    **Parameters:**

    | Name | Type | Required | Description |
    |------|------|----------|-------------|
    | `x` | number | Yes | X screen coordinate |
    | `y` | number | Yes | Y screen coordinate |

    **Returns:** Confirmation of right-click and context menu trigger.

    ---

    ### key_combination

    Press a key combination (e.g. Cmd+S, Ctrl+C). Use for keyboard shortcuts, navigation, and text editing.

    **Parameters:**

    | Name | Type | Required | Description |
    |------|------|----------|-------------|
    | `key` | string | Yes | Key name (a-z, 0-9, return, tab, escape, space, delete, up, down, left, right, f1-f12) |
    | `modifiers` | array | No | Modifier keys: `"command"`, `"shift"`, `"control"`, `"option"` |

    **Returns:** Confirmation of key press.

    **Example:**
    ```json
    {
      "key": "s",
      "modifiers": ["command"]
    }
    ```

    ### perform_action

    Perform any named AX action on an element found via JSONPath selector. Use for custom actions
    exposed by applications (game actions, app-specific actions) or standard AX actions. First use
    `get_element_details` or `find_elements` to discover an element's available actions list.

    **Parameters:**

    | Name | Type | Required | Description |
    |------|------|----------|-------------|
    | `selector` | string | Yes | JSONPath selector to find the element |
    | `action` | string | Yes | Exact action name (e.g. `"AXPress"`, `"Open Actions"`, `"Move North"`) |
    | `app` | string | No | Filter to a specific app by name |

    **Returns:** OK/FAILED with element UUID and action performed.

    **Example:**
    ```json
    {
      "selector": "$..[?(@.label =~ /Chimera/)]",
      "action": "Open Actions",
      "app": "Mythiq"
    }
    ```
    """#

    // MARK: - references/workflows.md

    public static let workflowsMD: String = #"""
    # agentax Testing Workflows

    Practical patterns for using agentax in agent testing loops.

    ---

    ## 1. Single-Action Verification

    The simplest pattern: perform one action and verify the result.

    **Steps:**

    1. Dump the current state to understand the UI:
       ```json
       { "tool": "dump_tree", "app": "MyApp" }
       ```

    2. Find the target element:
       ```json
       { "tool": "find_elements_in_app", "app": "MyApp", "selector": "$..[?(@.ax_identifier=='saveButton')]" }
       ```

    3. Click the element:
       ```json
       { "tool": "click_element_by_selector", "selector": "$..[?(@.ax_identifier=='saveButton')]", "app": "MyApp" }
       ```

    4. Verify the state changed:
       ```json
       { "tool": "assert_element_state", "selector": "$..[?(@.ax_identifier=='statusLabel')]", "expected": { "value": "Saved" }, "app": "MyApp" }
       ```

    **Shortcut with snapshot_diff:**
    ```json
    {
      "tool": "snapshot_diff",
      "app": "MyApp",
      "action": {
        "tool": "click_element_by_selector",
        "selector": "$..[?(@.ax_identifier=='saveButton')]"
      }
    }
    ```

    ---

    ## 2. Multi-Step Test Flow

    Testing a login form end-to-end.

    **Steps:**

    1. Activate the app and find the login screen:
       ```json
       { "tool": "activate_app", "app": "MyApp" }
       ```
       ```json
       { "tool": "find_elements_in_app", "app": "MyApp", "selector": "$..[?(@.ax_identifier=='loginView')]" }
       ```

    2. Type the username:
       ```json
       {
         "tool": "type_text_to_element_by_selector",
         "selector": "$..[?(@.ax_identifier=='usernameField')]",
         "text": "testuser@example.com",
         "app": "MyApp"
       }
       ```

    3. Type the password:
       ```json
       {
         "tool": "type_text_to_element_by_selector",
         "selector": "$..[?(@.ax_identifier=='passwordField')]",
         "text": "securePassword123",
         "app": "MyApp"
       }
       ```

    4. Click the login button:
       ```json
       { "tool": "click_element_by_selector", "selector": "$..[?(@.ax_identifier=='loginButton')]", "app": "MyApp" }
       ```

    5. Wait for the dashboard to appear (async navigation):
       ```json
       {
         "tool": "wait_for_element",
         "selector": "$..[?(@.ax_identifier=='dashboardView')]",
         "timeout": 10,
         "app": "MyApp"
       }
       ```

    6. Verify a dashboard element is present:
       ```json
       {
         "tool": "assert_element_state",
         "selector": "$..[?(@.ax_identifier=='welcomeLabel')]",
         "expected": { "value": "Welcome, testuser" },
         "app": "MyApp"
       }
       ```

    ---

    ## 3. RealityKit 3D State Validation

    Testing a RealityKit application where entities expose state via `customContent`.

    **Steps:**

    1. Find the game entity by label:
       ```json
       {
         "tool": "find_elements_in_app",
         "app": "MyGame",
         "selector": "$..[?(@.label=='Player Character')]"
       }
       ```

    2. Read its 3D state:
       ```json
       {
         "tool": "get_element_custom_content",
         "selector": "$..[?(@.label=='Player Character')]",
         "app": "MyGame"
       }
       ```
       Returns: `{ "position_x": "12.5", "position_y": "3.0", "position_z": "-7.2", "health": "80" }`

    3. Perform an action (e.g., click a heal button):
       ```json
       { "tool": "click_element_by_selector", "selector": "$..[?(@.ax_identifier=='healButton')]", "app": "MyGame" }
       ```

    4. Re-read customContent and verify health increased:
       ```json
       {
         "tool": "get_element_custom_content",
         "selector": "$..[?(@.label=='Player Character')]",
         "app": "MyGame"
       }
       ```

    5. Find all entities with position data:
       ```json
       {
         "tool": "find_elements_in_app",
         "app": "MyGame",
         "selector": "$..[?(@.customContent.position_x)]"
       }
       ```

    ---

    ## 4. Regression Testing with snapshot_diff

    Use `snapshot_diff` to capture before/after state and detect unintended changes.

    **Pattern:**

    ```json
    {
      "tool": "snapshot_diff",
      "app": "MyApp",
      "action": {
        "tool": "click_element_by_selector",
        "selector": "$..[?(@.ax_identifier=='toggleDarkMode')]"
      },
      "delay": 0.5
    }
    ```

    The diff shows:
    - **Added elements**: New UI that appeared after the action
    - **Removed elements**: UI that disappeared
    - **Changed elements**: Properties that changed (value, enabled, focused, etc.)

    Use this to verify that only the expected changes occurred and nothing else
    broke. Particularly useful for:
    - Theme switching (verify colors/labels updated, layout unchanged)
    - Feature toggles (verify new section appears, existing sections intact)
    - Delete operations (verify item removed, siblings unchanged)

    ---

    ## 5. Accessibility Audit

    Verify that all interactive elements have proper accessibility attributes.

    **Steps:**

    1. Find all buttons and check they have labels:
       ```json
       { "tool": "find_elements_in_app", "app": "MyApp", "selector": "$..[?(@.role=='AXButton')]" }
       ```
       Inspect each result for a non-empty `label` or `ax_identifier`.

    2. Find all text fields and verify identifiers:
       ```json
       { "tool": "find_elements_in_app", "app": "MyApp", "selector": "$..[?(@.role=='AXTextField')]" }
       ```

    3. Find all images and check for descriptions:
       ```json
       { "tool": "find_elements_in_app", "app": "MyApp", "selector": "$..[?(@.role=='AXImage')]" }
       ```

    4. Check that interactive elements are reachable:
       ```json
       { "tool": "find_elements_in_app", "app": "MyApp", "selector": "$..[?(@.role=='AXButton' && @.enabled==true)]" }
       ```

    5. Verify RealityKit entities have accessibility components:
       ```json
       { "tool": "find_elements_in_app", "app": "MyGame", "selector": "$..[?(@.customContent)]" }
       ```

    ---

    ## 6. Wait-Based Patterns for Async UI

    Many UI transitions are asynchronous. Use `wait_for_element` to handle them.

    **Navigation push:**
    ```json
    {
      "tool": "click_element_by_selector",
      "selector": "$..[?(@.ax_identifier=='settingsRow')]",
      "app": "MyApp"
    }
    ```
    ```json
    {
      "tool": "wait_for_element",
      "selector": "$..[?(@.ax_identifier=='settingsView')]",
      "timeout": 5,
      "app": "MyApp"
    }
    ```

    **Sheet presentation:**
    ```json
    {
      "tool": "click_element_by_selector",
      "selector": "$..[?(@.ax_identifier=='addItemButton')]",
      "app": "MyApp"
    }
    ```
    ```json
    {
      "tool": "wait_for_element",
      "selector": "$..[?(@.role=='AXSheet')]",
      "timeout": 5,
      "app": "MyApp"
    }
    ```

    **Loading state completion:**
    ```json
    {
      "tool": "wait_for_element",
      "selector": "$..[?(@.ax_identifier=='contentList' && @.enabled==true)]",
      "timeout": 15,
      "interval": 1,
      "app": "MyApp"
    }
    ```

    **Alert dialog:**
    ```json
    {
      "tool": "click_element_by_selector",
      "selector": "$..[?(@.ax_identifier=='deleteButton')]",
      "app": "MyApp"
    }
    ```
    ```json
    {
      "tool": "wait_for_element",
      "selector": "$..[?(@.role=='AXSheet' || @.role=='AXDialog')]",
      "timeout": 5,
      "app": "MyApp"
    }
    ```
    ```json
    {
      "tool": "click_element_by_selector",
      "selector": "$..[?(@.label=='Confirm')]",
      "app": "MyApp"
    }
    ```
    """#
}

// swiftlint:enable file_length type_body_length
