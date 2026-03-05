import Foundation

/// Level at which a skill is installed.
public enum InstallLevel: String, Sendable, CaseIterable {
    case project
    case user
}

/// Delivery format for skill content.
public enum SkillFormat: Sendable {
    /// SKILL.md + references/ directory
    case skillDir
    /// Marker-delimited section in AGENTS.md file
    case agentsMD
}

/// Configuration for a supported AI coding agent.
public struct AgentConfig: Sendable {
    public let name: String
    public let displayName: String
    public let format: SkillFormat
    public let userPathSuffix: String
    public let projectPathSuffix: String

    public func path(level: InstallLevel) -> String {
        let suffix: String
        switch level {
        case .user: suffix = userPathSuffix
        case .project: suffix = projectPathSuffix
        }
        // If the suffix is already an absolute path, use it directly (supports testing)
        if suffix.hasPrefix("/") { return suffix }
        switch level {
        case .user:
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            return "\(home)/\(suffix)"
        case .project:
            return "./\(suffix)"
        }
    }
}

/// Central registry of skill configuration and supported agents.
public enum SkillConfig {
    public static let skillName = "agentax"
    public static let version = "0.1.0"

    public static let agents: [AgentConfig] = [
        AgentConfig(
            name: "claude-code", displayName: "Claude Code",
            format: .skillDir,
            userPathSuffix: ".claude/skills/agentax",
            projectPathSuffix: ".claude/skills/agentax"
        ),
        AgentConfig(
            name: "gemini-cli", displayName: "Gemini CLI",
            format: .skillDir,
            userPathSuffix: ".gemini/skills/agentax",
            projectPathSuffix: ".gemini/skills/agentax"
        ),
        AgentConfig(
            name: "codex", displayName: "Codex",
            format: .agentsMD,
            userPathSuffix: ".codex/AGENTS.md",
            projectPathSuffix: "AGENTS.md"
        ),
        AgentConfig(
            name: "antigravity", displayName: "Antigravity",
            format: .skillDir,
            userPathSuffix: ".gemini/antigravity/skills/agentax",
            projectPathSuffix: ".agent/skills/agentax"
        ),
        AgentConfig(
            name: "opencode", displayName: "OpenCode",
            format: .skillDir,
            userPathSuffix: ".config/opencode/skills/agentax",
            projectPathSuffix: ".opencode/skills/agentax"
        ),
    ]

    public static func findAgent(name: String) -> AgentConfig? {
        agents.first { $0.name == name }
    }

    public static let validAgentNames: [String] = agents.map(\.name)
}
