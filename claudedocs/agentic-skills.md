# Agentic Skills System

agentax supports the [Agentic Skills](https://agentskills.io) specification — a lightweight open format for teaching AI agents how to use tools. A single `skill install` command gives any supported agent full knowledge of agentax's capabilities.

Follows the exact same pattern as [Synapse's skill system](https://github.com/swiftj/synapse#agentic-skills).

## Supported Agents

| Agent | Format | User Path | Project Path |
|-------|--------|-----------|--------------|
| Claude Code | `SKILL.md` + `references/` | `~/.claude/skills/agentax/` | `.claude/skills/agentax/` |
| Gemini CLI | `SKILL.md` + `references/` | `~/.gemini/skills/agentax/` | `.gemini/skills/agentax/` |
| Codex | `AGENTS.md` section | `~/.codex/AGENTS.md` | `AGENTS.md` |
| Antigravity | `SKILL.md` + `references/` | `~/.gemini/antigravity/skills/agentax/` | `.agent/skills/agentax/` |
| OpenCode | `SKILL.md` + `references/` | `~/.config/opencode/skills/agentax/` | `.opencode/skills/agentax/` |

## Two Delivery Formats

### SKILL.md directory (Claude Code, Gemini CLI, Antigravity, OpenCode)

Installs into a skill directory:
```
<skill_path>/agentax/
  SKILL.md                    # YAML frontmatter + markdown body
  references/
    tool-reference.md         # Complete MCP tool docs with params and examples
    workflows.md              # Testing workflow patterns and best practices
```

### AGENTS.md section (Codex)

Appends a marker-delimited section to existing `AGENTS.md`:
```
<!-- BEGIN AGENTAX SKILL vX.Y.Z -->
... skill content ...
<!-- END AGENTAX SKILL -->
```

Existing content is preserved. Reinstalling replaces only the agentax section.

## Installation Levels

- `--level project` (default) — Installs into current project directory
- `--level user` — Installs into user's home directory (global)

## CLI Commands

```bash
agentax skill install claude-code                # Project-level (default)
agentax skill install claude-code --level user   # Global
agentax skill install gemini-cli --level user
agentax skill uninstall claude-code --level user
agentax skill list                               # Show all installation status
agentax skill update                             # Update all installed skills
agentax skill update claude-code                 # Update specific agent
agentax skill show                               # Print embedded SKILL.md
```

## Implementation

Source: `Sources/AgentAX/Skill/`

### SkillConfig.swift

Agent registry. Each `AgentConfig` defines:
- `name`, `displayName`
- `format`: `.skillDir` or `.agentsMD`
- `userPath()` and `projectPath()` functions
- `SkillName = "agentax"`

### SkillInstall.swift

`install(agentName:level:version:)` dispatches by format:
- **skillDir**: Create directory, write SKILL.md + references/
- **agentsMD**: Read existing file, find markers → replace section; or append if not found

Key behaviors:
- Idempotent — calling twice overwrites cleanly
- Atomic write: temp file + rename
- Version injection via `{{VERSION}}` placeholder replacement
- `updateAll(version:)` re-installs for all currently installed agents

### SkillUninstall.swift

`uninstall(agentName:level:)`:
- **skillDir**: `FileManager.removeItem` on the directory
- **agentsMD**: Strip marker section. Delete file if empty after removal.

### SkillStatus.swift

- `isInstalled(agentName:level:)` — checks SKILL.md existence or marker presence
- `installedVersion(agentName:level:)` — extracts version from YAML frontmatter or marker comment
- `list()` — returns `[InstallationInfo]` for all agents at both levels

### Embedded Content

Skill content files embedded into the binary via Swift resource bundle (`Bundle.module`) or static data approach.

Source: `Sources/AgentAX/Skill/SkillData/`

Files:
- `SKILL.md` — What agentax is, when to use it, core workflow, all MCP tools, TOON format, RealityKit customContent patterns, JSONPath selectors, error recovery
- `AGENTS_SECTION.md` — Compact version for AGENTS.md agents
- `references/tool-reference.md` — Complete MCP tool documentation with all parameters, types, required/optional flags, examples
- `references/workflows.md` — Testing workflow patterns: single-action verification, multi-step test flows, RealityKit 3D state validation, regression testing loops, accessibility audits

### Marker Format

```
<!-- BEGIN AGENTAX SKILL v1.0.0 -->
... content with {{VERSION}} replaced ...
<!-- END AGENTAX SKILL -->
```

Markers found via string search. `findMarkers()` returns byte offsets for begin/end. Version extracted from the begin marker comment.
