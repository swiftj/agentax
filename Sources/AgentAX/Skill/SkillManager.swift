import Foundation

/// Information about a skill installation for a given agent and level.
public struct InstallationInfo: Sendable {
    public let agent: AgentConfig
    public let level: InstallLevel
    public let isInstalled: Bool
    public let version: String?
}

/// Errors from skill management operations.
public enum SkillError: Error, Sendable, CustomStringConvertible {
    case unknownAgent(String)
    case invalidLevel(String)
    case fileOperationFailed(String)

    public var description: String {
        switch self {
        case .unknownAgent(let name):
            "Unknown agent '\(name)'. Valid agents: \(SkillConfig.validAgentNames.joined(separator: ", "))"
        case .invalidLevel(let level):
            "Invalid level '\(level)'. Valid levels: project, user"
        case .fileOperationFailed(let msg):
            "File operation failed: \(msg)"
        }
    }
}

/// Manages installation, uninstallation, and status of agentax skills.
public struct SkillManager: Sendable {
    // FileManager.default is thread-safe; access it via computed property to satisfy Sendable.
    private var fm: FileManager { FileManager.default }

    public init() {}

    // MARK: - Install

    /// Install the agentax skill for the given agent at the specified level.
    public func install(agent: AgentConfig, level: InstallLevel) throws {
        switch agent.format {
        case .skillDir:
            try installSkillDir(agent: agent, level: level)
        case .agentsMD:
            try installAgentsMD(agent: agent, level: level)
        }
    }

    // MARK: - Uninstall

    /// Remove the agentax skill for the given agent at the specified level.
    public func uninstall(agent: AgentConfig, level: InstallLevel) throws {
        switch agent.format {
        case .skillDir:
            try uninstallSkillDir(agent: agent, level: level)
        case .agentsMD:
            try uninstallAgentsMD(agent: agent, level: level)
        }
    }

    // MARK: - Status

    /// Check whether the skill is installed for the given agent and level.
    public func isInstalled(agent: AgentConfig, level: InstallLevel) -> Bool {
        switch agent.format {
        case .skillDir:
            let skillMDPath = agent.path(level: level) + "/SKILL.md"
            return fm.fileExists(atPath: skillMDPath)
        case .agentsMD:
            let filePath = agent.path(level: level)
            guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
                return false
            }
            return content.contains("<!-- BEGIN AGENTAX SKILL")
        }
    }

    /// Extract the installed version for the given agent and level, or nil if not installed.
    public func installedVersion(agent: AgentConfig, level: InstallLevel) -> String? {
        switch agent.format {
        case .skillDir:
            let skillMDPath = agent.path(level: level) + "/SKILL.md"
            guard let content = try? String(contentsOfFile: skillMDPath, encoding: .utf8) else {
                return nil
            }
            return extractVersionFromYAML(content)
        case .agentsMD:
            let filePath = agent.path(level: level)
            guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
                return nil
            }
            return extractVersionFromMarker(content)
        }
    }

    /// List installation status for all agents at both levels.
    public func listAll() -> [InstallationInfo] {
        var results: [InstallationInfo] = []
        for agent in SkillConfig.agents {
            for level in InstallLevel.allCases {
                let installed = isInstalled(agent: agent, level: level)
                let version = installed ? installedVersion(agent: agent, level: level) : nil
                results.append(InstallationInfo(
                    agent: agent,
                    level: level,
                    isInstalled: installed,
                    version: version
                ))
            }
        }
        return results
    }

    // MARK: - Update

    /// Re-install skill for all currently installed agent+level pairs.
    public func updateAll() throws {
        for agent in SkillConfig.agents {
            for level in InstallLevel.allCases {
                if isInstalled(agent: agent, level: level) {
                    try install(agent: agent, level: level)
                }
            }
        }
    }

    /// Re-install skill for a specific agent at all levels where it is currently installed.
    public func update(agent: AgentConfig) throws {
        for level in InstallLevel.allCases {
            if isInstalled(agent: agent, level: level) {
                try install(agent: agent, level: level)
            }
        }
    }

    // MARK: - Private: Skill Directory Format

    private func installSkillDir(agent: AgentConfig, level: InstallLevel) throws {
        let basePath = agent.path(level: level)
        let refsPath = basePath + "/references"

        // Create directories
        try fm.createDirectory(atPath: refsPath, withIntermediateDirectories: true)

        // Prepare content with version injection
        let skillContent = SkillContent.skillMD.replacingOccurrences(
            of: "{{VERSION}}", with: SkillConfig.version
        )
        let toolRefContent = SkillContent.toolReferenceMD.replacingOccurrences(
            of: "{{VERSION}}", with: SkillConfig.version
        )
        let workflowsContent = SkillContent.workflowsMD.replacingOccurrences(
            of: "{{VERSION}}", with: SkillConfig.version
        )

        // Atomic writes
        try atomicWrite(skillContent, to: basePath + "/SKILL.md")
        try atomicWrite(toolRefContent, to: refsPath + "/tool-reference.md")
        try atomicWrite(workflowsContent, to: refsPath + "/workflows.md")
    }

    private func uninstallSkillDir(agent: AgentConfig, level: InstallLevel) throws {
        let basePath = agent.path(level: level)
        guard fm.fileExists(atPath: basePath) else { return }
        try fm.removeItem(atPath: basePath)
    }

    // MARK: - Private: AGENTS.md Format

    private func installAgentsMD(agent: AgentConfig, level: InstallLevel) throws {
        let filePath = agent.path(level: level)
        let section = SkillContent.agentsSectionMD.replacingOccurrences(
            of: "{{VERSION}}", with: SkillConfig.version
        )

        if fm.fileExists(atPath: filePath) {
            var content = try String(contentsOfFile: filePath, encoding: .utf8)

            if let range = findMarkerRange(in: content) {
                // Replace existing section
                content.replaceSubrange(range, with: section)
            } else {
                // Append with separator
                if !content.hasSuffix("\n") {
                    content += "\n"
                }
                content += "\n" + section
            }

            try atomicWrite(content, to: filePath)
        } else {
            // Create parent directory and write new file
            let parentDir = (filePath as NSString).deletingLastPathComponent
            try fm.createDirectory(atPath: parentDir, withIntermediateDirectories: true)
            try atomicWrite(section, to: filePath)
        }
    }

    private func uninstallAgentsMD(agent: AgentConfig, level: InstallLevel) throws {
        let filePath = agent.path(level: level)
        guard fm.fileExists(atPath: filePath) else { return }

        var content = try String(contentsOfFile: filePath, encoding: .utf8)

        guard let range = findMarkerRange(in: content) else { return }

        content.replaceSubrange(range, with: "")

        // Clean up trailing whitespace from removal
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            try fm.removeItem(atPath: filePath)
        } else {
            try atomicWrite(content, to: filePath)
        }
    }

    // MARK: - Private: Marker Handling

    private static let beginMarkerPrefix = "<!-- BEGIN AGENTAX SKILL"
    private static let endMarker = "<!-- END AGENTAX SKILL -->"

    /// Find the full range of the agentax marker section in the given content.
    private func findMarkerRange(in content: String) -> Range<String.Index>? {
        guard let beginRange = content.range(of: Self.beginMarkerPrefix) else { return nil }
        guard let endRange = content.range(of: Self.endMarker, range: beginRange.lowerBound..<content.endIndex) else {
            return nil
        }
        return beginRange.lowerBound..<endRange.upperBound
    }

    /// Extract version from YAML frontmatter: `version: "X.Y.Z"`
    private func extractVersionFromYAML(_ content: String) -> String? {
        let pattern = #"version:\s*"([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                  in: content,
                  range: NSRange(content.startIndex..., in: content)
              ),
              let versionRange = Range(match.range(at: 1), in: content)
        else { return nil }
        return String(content[versionRange])
    }

    /// Extract version from begin marker: `<!-- BEGIN AGENTAX SKILL vX.Y.Z -->`
    private func extractVersionFromMarker(_ content: String) -> String? {
        let pattern = #"<!-- BEGIN AGENTAX SKILL v([^\s]+)\s*-->"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                  in: content,
                  range: NSRange(content.startIndex..., in: content)
              ),
              let versionRange = Range(match.range(at: 1), in: content)
        else { return nil }
        return String(content[versionRange])
    }

    // MARK: - Private: Atomic Write

    private func atomicWrite(_ content: String, to path: String) throws {
        let url = URL(fileURLWithPath: path)
        let tempURL = url.appendingPathExtension("tmp")
        try content.write(to: tempURL, atomically: true, encoding: .utf8)
        if fm.fileExists(atPath: path) {
            try fm.removeItem(at: url)
        }
        try fm.moveItem(at: tempURL, to: url)
    }
}
