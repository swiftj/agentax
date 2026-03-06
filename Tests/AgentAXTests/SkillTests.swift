import Testing
import Foundation
@testable import AgentAX

// MARK: - SkillConfig Tests

@Suite("SkillConfig")
struct SkillConfigTests {

    @Test("All 5 agents are registered")
    func agentCount() {
        #expect(SkillConfig.agents.count == 5)
    }

    @Test("validAgentNames contains all 5 agent names")
    func validAgentNames() {
        let expected: Set<String> = [
            "claude-code", "gemini-cli", "codex", "antigravity", "opencode"
        ]
        #expect(Set(SkillConfig.validAgentNames) == expected)
    }

    @Test("skillName is agentax")
    func skillName() {
        #expect(SkillConfig.skillName == "agentax")
    }

    @Test("version is a valid semver string")
    func versionFormat() {
        let parts = SkillConfig.version.split(separator: ".")
        #expect(parts.count == 3, "Version should be semver (major.minor.patch)")
        for part in parts {
            #expect(Int(part) != nil, "Each version component should be numeric")
        }
    }

    @Test(
        "findAgent returns correct agent for each known name",
        arguments: ["claude-code", "gemini-cli", "codex", "antigravity", "opencode"]
    )
    func findAgentKnown(name: String) {
        let agent = SkillConfig.findAgent(name: name)
        #expect(agent != nil, "findAgent should return an agent for '\(name)'")
        #expect(agent?.name == name)
    }

    @Test("findAgent returns nil for unknown agent name")
    func findAgentUnknown() {
        #expect(SkillConfig.findAgent(name: "nonexistent") == nil)
        #expect(SkillConfig.findAgent(name: "") == nil)
        #expect(SkillConfig.findAgent(name: "Claude-Code") == nil) // case sensitive
    }

    @Test("Claude Code uses skillDir format")
    func claudeCodeFormat() {
        let agent = SkillConfig.findAgent(name: "claude-code")!
        if case .skillDir = agent.format {
            // pass
        } else {
            Issue.record("Claude Code should use skillDir format")
        }
    }

    @Test("Gemini CLI uses skillDir format")
    func geminiCLIFormat() {
        let agent = SkillConfig.findAgent(name: "gemini-cli")!
        if case .skillDir = agent.format {
            // pass
        } else {
            Issue.record("Gemini CLI should use skillDir format")
        }
    }

    @Test("Codex uses agentsMD format")
    func codexFormat() {
        let agent = SkillConfig.findAgent(name: "codex")!
        if case .agentsMD = agent.format {
            // pass
        } else {
            Issue.record("Codex should use agentsMD format")
        }
    }

    @Test("Antigravity uses skillDir format")
    func antigravityFormat() {
        let agent = SkillConfig.findAgent(name: "antigravity")!
        if case .skillDir = agent.format {
            // pass
        } else {
            Issue.record("Antigravity should use skillDir format")
        }
    }

    @Test("OpenCode uses skillDir format")
    func openCodeFormat() {
        let agent = SkillConfig.findAgent(name: "opencode")!
        if case .skillDir = agent.format {
            // pass
        } else {
            Issue.record("OpenCode should use skillDir format")
        }
    }

    @Test("User paths contain home directory prefix")
    func userPathsContainHome() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        for agent in SkillConfig.agents {
            let userPath = agent.path(level: .user)
            #expect(
                userPath.hasPrefix(home),
                "User path for \(agent.name) should start with home directory"
            )
        }
    }

    @Test("Project paths start with ./ prefix")
    func projectPathsAreRelative() {
        for agent in SkillConfig.agents {
            let projectPath = agent.path(level: .project)
            #expect(
                projectPath.hasPrefix("./"),
                "Project path for \(agent.name) should start with './' but got: \(projectPath)"
            )
        }
    }

    @Test("Agent display names are non-empty human-readable strings")
    func displayNames() {
        for agent in SkillConfig.agents {
            #expect(!agent.displayName.isEmpty, "Display name should not be empty for \(agent.name)")
            #expect(agent.displayName.contains(" ") || agent.displayName == "Codex" || agent.displayName == "Antigravity" || agent.displayName == "OpenCode",
                    "Display name '\(agent.displayName)' should be human-readable")
        }
    }

    @Test("Each agent name is unique")
    func uniqueNames() {
        let names = SkillConfig.agents.map(\.name)
        #expect(Set(names).count == names.count, "Agent names must be unique")
    }

    @Test("Claude Code user path suffix contains .claude")
    func claudeCodeUserPath() {
        let agent = SkillConfig.findAgent(name: "claude-code")!
        #expect(agent.userPathSuffix.contains(".claude"))
    }

    @Test("Codex project path suffix is AGENTS.md")
    func codexProjectPath() {
        let agent = SkillConfig.findAgent(name: "codex")!
        #expect(agent.projectPathSuffix == "AGENTS.md")
    }

    @Test("OpenCode user path suffix contains .config/opencode")
    func openCodeUserPath() {
        let agent = SkillConfig.findAgent(name: "opencode")!
        #expect(agent.userPathSuffix.contains(".config/opencode"))
    }
}

// MARK: - SkillContent Tests

@Suite("SkillContent")
struct SkillContentTests {

    @Test("skillMD is non-empty")
    func skillMDNonEmpty() {
        #expect(!SkillContent.skillMD.isEmpty)
    }

    @Test("skillMD contains VERSION placeholder")
    func skillMDVersionPlaceholder() {
        #expect(
            SkillContent.skillMD.contains("{{VERSION}}"),
            "skillMD should contain {{VERSION}} placeholder for version injection"
        )
    }

    @Test("skillMD contains YAML frontmatter")
    func skillMDFrontmatter() {
        #expect(
            SkillContent.skillMD.hasPrefix("---"),
            "skillMD should start with YAML frontmatter delimiter '---'"
        )
        // Should have closing frontmatter delimiter too
        let lines = SkillContent.skillMD.components(separatedBy: "\n")
        let frontmatterDelimiters = lines.filter { $0.trimmingCharacters(in: .whitespaces) == "---" }
        #expect(
            frontmatterDelimiters.count >= 2,
            "skillMD should have at least two '---' delimiters for YAML frontmatter"
        )
    }

    @Test("agentsSectionMD is non-empty")
    func agentsSectionMDNonEmpty() {
        #expect(!SkillContent.agentsSectionMD.isEmpty)
    }

    @Test("agentsSectionMD contains BEGIN marker")
    func agentsSectionMDBeginMarker() {
        #expect(
            SkillContent.agentsSectionMD.contains("<!-- BEGIN AGENTAX SKILL"),
            "agentsSectionMD should contain BEGIN marker"
        )
    }

    @Test("agentsSectionMD contains END marker")
    func agentsSectionMDEndMarker() {
        #expect(
            SkillContent.agentsSectionMD.contains("<!-- END AGENTAX SKILL"),
            "agentsSectionMD should contain END marker"
        )
    }

    @Test("agentsSectionMD contains VERSION in markers")
    func agentsSectionMDVersionInMarkers() {
        #expect(
            SkillContent.agentsSectionMD.contains("<!-- BEGIN AGENTAX SKILL v{{VERSION}}"),
            "BEGIN marker should include {{VERSION}} placeholder"
        )
    }

    @Test("toolReferenceMD is non-empty")
    func toolReferenceMDNonEmpty() {
        #expect(!SkillContent.toolReferenceMD.isEmpty)
    }

    @Test(
        "toolReferenceMD mentions all 23 MCP tools",
        arguments: [
            // Core 9 tools
            "find_elements",
            "find_elements_in_app",
            "click_element_by_selector",
            "click_at_position",
            "type_text_to_element_by_selector",
            "get_element_details",
            "list_running_applications",
            "get_app_overview",
            "check_accessibility_permissions",
            // Additional 9 tools
            "get_frontmost_app",
            "scroll_element",
            "activate_app",
            "get_menu_bar_items",
            "dump_tree",
            "wait_for_element",
            "assert_element_state",
            "get_element_custom_content",
            "snapshot_diff",
            // Input tools
            "drag",
            "double_click_at_position",
            "right_click_at_position",
            "key_combination",
            // Action tools
            "perform_action",
        ]
    )
    func toolReferenceMDContainsTool(toolName: String) {
        #expect(
            SkillContent.toolReferenceMD.contains(toolName),
            "toolReferenceMD should document the '\(toolName)' tool"
        )
    }

    @Test("workflowsMD is non-empty")
    func workflowsMDNonEmpty() {
        #expect(!SkillContent.workflowsMD.isEmpty)
    }

    @Test("workflowsMD contains workflow patterns")
    func workflowsMDContainsPatterns() {
        // The workflows doc should describe testing patterns per the spec:
        // single-action verification, multi-step test flows, RealityKit 3D state,
        // regression testing, accessibility audits
        let content = SkillContent.workflowsMD.lowercased()
        #expect(content.contains("workflow") || content.contains("pattern"),
                "workflowsMD should describe workflow patterns")
    }

    @Test("All content strings are substantial (not just whitespace)")
    func allContentSubstantial() {
        let contents: [(String, String)] = [
            ("skillMD", SkillContent.skillMD),
            ("agentsSectionMD", SkillContent.agentsSectionMD),
            ("toolReferenceMD", SkillContent.toolReferenceMD),
            ("workflowsMD", SkillContent.workflowsMD),
        ]
        for (name, content) in contents {
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            #expect(trimmed.count > 50, "\(name) should have substantial content, got \(trimmed.count) chars")
        }
    }
}

// MARK: - SkillManager Tests

@Suite("SkillManager")
struct SkillManagerTests {

    // MARK: - Helpers

    /// Creates a unique temporary directory for test isolation.
    private func makeTempDir() throws -> String {
        let path = NSTemporaryDirectory() + "agentax-test-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }

    /// Removes a temporary directory and all its contents.
    private func cleanupTempDir(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    /// Creates an AgentConfig that uses skillDir format with paths inside the given temp directory.
    private func makeSkillDirAgent(basePath: String) -> AgentConfig {
        AgentConfig(
            name: "test-skilldir",
            displayName: "Test SkillDir Agent",
            format: .skillDir,
            userPathSuffix: basePath + "/user/skills/agentax",
            projectPathSuffix: basePath + "/project/skills/agentax"
        )
    }

    /// Creates an AgentConfig that uses agentsMD format with paths inside the given temp directory.
    private func makeAgentsMDAgent(basePath: String) -> AgentConfig {
        AgentConfig(
            name: "test-agentsmd",
            displayName: "Test AgentsMD Agent",
            format: .agentsMD,
            userPathSuffix: basePath + "/user/AGENTS.md",
            projectPathSuffix: basePath + "/project/AGENTS.md"
        )
    }

    // NOTE: Since AgentConfig.path(level: .user) prepends the home directory to
    // userPathSuffix, but for testing we want full control over the path, we use
    // the userPathSuffix with an absolute temp path. This means path(level: .user)
    // will return "$HOME/<tempDir>/user/..." which is not the temp dir directly.
    //
    // To work around this, we use path(level: .project) which returns "./<suffix>"
    // but the suffix here is our absolute temp path, so that won't work either.
    //
    // The cleanest approach: test SkillManager by invoking install/uninstall and
    // checking the paths that SkillManager actually writes to. If SkillManager
    // uses agent.path(level:) internally, we need the resolved path. We compute
    // it the same way AgentConfig.path does so our assertions match.

    /// Returns the resolved path that AgentConfig.path(level:) would produce.
    private func resolvedPath(agent: AgentConfig, level: InstallLevel) -> String {
        agent.path(level: level)
    }

    // MARK: - SkillDir Format Install Tests

    @Test("Install skillDir format creates SKILL.md and references directory")
    func installSkillDir() throws {
        let tempDir = try makeTempDir()
        defer { cleanupTempDir(tempDir) }

        // Use project level with a suffix that is our temp path
        // Since project path = "./" + projectPathSuffix, we need to handle this
        // We will directly create the agent config to point at temp paths
        let skillPath = tempDir + "/skill-agent"
        let agent = AgentConfig(
            name: "test-sd",
            displayName: "Test",
            format: .skillDir,
            userPathSuffix: skillPath,
            projectPathSuffix: skillPath
        )

        let manager = SkillManager()
        try manager.install(agent: agent, level: .user)

        let resolvedDir = agent.path(level: .user)
        let fm = FileManager.default

        #expect(fm.fileExists(atPath: resolvedDir + "/SKILL.md"),
                "SKILL.md should exist after install")
        #expect(fm.fileExists(atPath: resolvedDir + "/references/tool-reference.md"),
                "references/tool-reference.md should exist after install")
        #expect(fm.fileExists(atPath: resolvedDir + "/references/workflows.md"),
                "references/workflows.md should exist after install")
    }

    @Test("Install replaces VERSION placeholder with actual version")
    func installReplacesVersion() throws {
        let tempDir = try makeTempDir()
        defer { cleanupTempDir(tempDir) }

        let skillPath = tempDir + "/version-agent"
        let agent = AgentConfig(
            name: "test-ver",
            displayName: "Test",
            format: .skillDir,
            userPathSuffix: skillPath,
            projectPathSuffix: skillPath
        )

        let manager = SkillManager()
        try manager.install(agent: agent, level: .user)

        let resolvedDir = agent.path(level: .user)
        let skillMD = try String(contentsOfFile: resolvedDir + "/SKILL.md", encoding: .utf8)

        #expect(!skillMD.contains("{{VERSION}}"),
                "Installed SKILL.md should NOT contain {{VERSION}} placeholder")
        #expect(skillMD.contains(SkillConfig.version),
                "Installed SKILL.md should contain the actual version '\(SkillConfig.version)'")
    }

    @Test("Install is idempotent - second install does not fail")
    func installIdempotent() throws {
        let tempDir = try makeTempDir()
        defer { cleanupTempDir(tempDir) }

        let skillPath = tempDir + "/idempotent-agent"
        let agent = AgentConfig(
            name: "test-idem",
            displayName: "Test",
            format: .skillDir,
            userPathSuffix: skillPath,
            projectPathSuffix: skillPath
        )

        let manager = SkillManager()
        try manager.install(agent: agent, level: .user)
        try manager.install(agent: agent, level: .user)

        let resolvedDir = agent.path(level: .user)
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: resolvedDir + "/SKILL.md"))
        #expect(fm.fileExists(atPath: resolvedDir + "/references/tool-reference.md"))
        #expect(fm.fileExists(atPath: resolvedDir + "/references/workflows.md"))
    }

    @Test("Uninstall skillDir removes the entire directory")
    func uninstallSkillDir() throws {
        let tempDir = try makeTempDir()
        defer { cleanupTempDir(tempDir) }

        let skillPath = tempDir + "/uninstall-agent"
        let agent = AgentConfig(
            name: "test-unsd",
            displayName: "Test",
            format: .skillDir,
            userPathSuffix: skillPath,
            projectPathSuffix: skillPath
        )

        let manager = SkillManager()
        try manager.install(agent: agent, level: .user)

        let resolvedDir = agent.path(level: .user)
        #expect(FileManager.default.fileExists(atPath: resolvedDir + "/SKILL.md"))

        try manager.uninstall(agent: agent, level: .user)
        #expect(!FileManager.default.fileExists(atPath: resolvedDir),
                "Skill directory should be removed after uninstall")
    }

    @Test("Uninstall non-existent skill does not throw")
    func uninstallNonExistent() throws {
        let tempDir = try makeTempDir()
        defer { cleanupTempDir(tempDir) }

        let skillPath = tempDir + "/never-installed"
        let agent = AgentConfig(
            name: "test-ghost",
            displayName: "Test",
            format: .skillDir,
            userPathSuffix: skillPath,
            projectPathSuffix: skillPath
        )

        let manager = SkillManager()
        // Should not throw
        try manager.uninstall(agent: agent, level: .user)
    }

    // MARK: - AgentsMD Format Install Tests

    @Test("Install agentsMD format creates file with markers")
    func installAgentsMD() throws {
        let tempDir = try makeTempDir()
        defer { cleanupTempDir(tempDir) }

        let agentsPath = tempDir + "/agents-install"
        // Ensure parent directory exists for the AGENTS.md file
        try FileManager.default.createDirectory(
            atPath: agentsPath, withIntermediateDirectories: true
        )

        let agent = AgentConfig(
            name: "test-amd",
            displayName: "Test",
            format: .agentsMD,
            userPathSuffix: agentsPath + "/AGENTS.md",
            projectPathSuffix: agentsPath + "/AGENTS.md"
        )

        let manager = SkillManager()
        try manager.install(agent: agent, level: .user)

        let resolvedFile = agent.path(level: .user)
        let content = try String(contentsOfFile: resolvedFile, encoding: .utf8)

        #expect(content.contains("<!-- BEGIN AGENTAX SKILL"),
                "AGENTS.md should contain BEGIN marker after install")
        #expect(content.contains("<!-- END AGENTAX SKILL"),
                "AGENTS.md should contain END marker after install")
    }

    @Test("Install agentsMD preserves existing content")
    func installAgentsMDPreservesContent() throws {
        let tempDir = try makeTempDir()
        defer { cleanupTempDir(tempDir) }

        let agentsPath = tempDir + "/agents-preserve"
        try FileManager.default.createDirectory(
            atPath: agentsPath, withIntermediateDirectories: true
        )

        let agent = AgentConfig(
            name: "test-pres",
            displayName: "Test",
            format: .agentsMD,
            userPathSuffix: agentsPath + "/AGENTS.md",
            projectPathSuffix: agentsPath + "/AGENTS.md"
        )

        let resolvedFile = agent.path(level: .user)
        let existingContent = "# My Project Agents\n\nThis file has existing content.\n"
        try existingContent.write(toFile: resolvedFile, atomically: true, encoding: .utf8)

        let manager = SkillManager()
        try manager.install(agent: agent, level: .user)

        let content = try String(contentsOfFile: resolvedFile, encoding: .utf8)

        #expect(content.contains("My Project Agents"),
                "Existing content should be preserved after install")
        #expect(content.contains("<!-- BEGIN AGENTAX SKILL"),
                "Markers should be present after install")
    }

    @Test("Install agentsMD twice produces only one set of markers")
    func installAgentsMDReplacesExisting() throws {
        let tempDir = try makeTempDir()
        defer { cleanupTempDir(tempDir) }

        let agentsPath = tempDir + "/agents-replace"
        try FileManager.default.createDirectory(
            atPath: agentsPath, withIntermediateDirectories: true
        )

        let agent = AgentConfig(
            name: "test-repl",
            displayName: "Test",
            format: .agentsMD,
            userPathSuffix: agentsPath + "/AGENTS.md",
            projectPathSuffix: agentsPath + "/AGENTS.md"
        )

        let manager = SkillManager()
        try manager.install(agent: agent, level: .user)
        try manager.install(agent: agent, level: .user)

        let resolvedFile = agent.path(level: .user)
        let content = try String(contentsOfFile: resolvedFile, encoding: .utf8)

        let beginCount = content.components(separatedBy: "<!-- BEGIN AGENTAX SKILL").count - 1
        let endCount = content.components(separatedBy: "<!-- END AGENTAX SKILL").count - 1

        #expect(beginCount == 1,
                "Should have exactly one BEGIN marker after two installs, got \(beginCount)")
        #expect(endCount == 1,
                "Should have exactly one END marker after two installs, got \(endCount)")
    }

    @Test("Uninstall agentsMD removes marker section")
    func uninstallAgentsMDRemovesSection() throws {
        let tempDir = try makeTempDir()
        defer { cleanupTempDir(tempDir) }

        let agentsPath = tempDir + "/agents-unsection"
        try FileManager.default.createDirectory(
            atPath: agentsPath, withIntermediateDirectories: true
        )

        let agent = AgentConfig(
            name: "test-unsec",
            displayName: "Test",
            format: .agentsMD,
            userPathSuffix: agentsPath + "/AGENTS.md",
            projectPathSuffix: agentsPath + "/AGENTS.md"
        )

        let manager = SkillManager()
        try manager.install(agent: agent, level: .user)
        try manager.uninstall(agent: agent, level: .user)

        let resolvedFile = agent.path(level: .user)
        // File may or may not exist after uninstall (spec says delete if empty)
        if FileManager.default.fileExists(atPath: resolvedFile) {
            let content = try String(contentsOfFile: resolvedFile, encoding: .utf8)
            #expect(!content.contains("<!-- BEGIN AGENTAX SKILL"),
                    "BEGIN marker should be removed after uninstall")
            #expect(!content.contains("<!-- END AGENTAX SKILL"),
                    "END marker should be removed after uninstall")
        }
        // If file does not exist, that is also acceptable (empty file removal)
    }

    @Test("Uninstall agentsMD preserves other content in the file")
    func uninstallAgentsMDPreservesOtherContent() throws {
        let tempDir = try makeTempDir()
        defer { cleanupTempDir(tempDir) }

        let agentsPath = tempDir + "/agents-keepother"
        try FileManager.default.createDirectory(
            atPath: agentsPath, withIntermediateDirectories: true
        )

        let agent = AgentConfig(
            name: "test-keep",
            displayName: "Test",
            format: .agentsMD,
            userPathSuffix: agentsPath + "/AGENTS.md",
            projectPathSuffix: agentsPath + "/AGENTS.md"
        )

        let resolvedFile = agent.path(level: .user)
        let otherContent = "# Other Agent Config\n\nThis must survive uninstall.\n"
        try otherContent.write(toFile: resolvedFile, atomically: true, encoding: .utf8)

        let manager = SkillManager()
        try manager.install(agent: agent, level: .user)
        try manager.uninstall(agent: agent, level: .user)

        #expect(FileManager.default.fileExists(atPath: resolvedFile),
                "AGENTS.md should still exist when it has other content")

        let content = try String(contentsOfFile: resolvedFile, encoding: .utf8)
        #expect(content.contains("Other Agent Config"),
                "Other content should be preserved after uninstall")
        #expect(content.contains("This must survive uninstall"),
                "Other content body should be preserved after uninstall")
        #expect(!content.contains("<!-- BEGIN AGENTAX SKILL"),
                "Agentax markers should be gone after uninstall")
    }

    // MARK: - isInstalled / installedVersion Tests

    @Test("isInstalled returns true after install for skillDir")
    func isInstalledTrueSkillDir() throws {
        let tempDir = try makeTempDir()
        defer { cleanupTempDir(tempDir) }

        let skillPath = tempDir + "/installed-check"
        let agent = AgentConfig(
            name: "test-chk",
            displayName: "Test",
            format: .skillDir,
            userPathSuffix: skillPath,
            projectPathSuffix: skillPath
        )

        let manager = SkillManager()
        #expect(!manager.isInstalled(agent: agent, level: .user),
                "Should not be installed before install")

        try manager.install(agent: agent, level: .user)
        #expect(manager.isInstalled(agent: agent, level: .user),
                "Should be installed after install")
    }

    @Test("isInstalled returns false after uninstall for skillDir")
    func isInstalledFalseAfterUninstall() throws {
        let tempDir = try makeTempDir()
        defer { cleanupTempDir(tempDir) }

        let skillPath = tempDir + "/installed-uncheck"
        let agent = AgentConfig(
            name: "test-unchk",
            displayName: "Test",
            format: .skillDir,
            userPathSuffix: skillPath,
            projectPathSuffix: skillPath
        )

        let manager = SkillManager()
        try manager.install(agent: agent, level: .user)
        try manager.uninstall(agent: agent, level: .user)

        #expect(!manager.isInstalled(agent: agent, level: .user),
                "Should not be installed after uninstall")
    }

    @Test("isInstalled returns true after install for agentsMD")
    func isInstalledTrueAgentsMD() throws {
        let tempDir = try makeTempDir()
        defer { cleanupTempDir(tempDir) }

        let agentsPath = tempDir + "/installed-amd"
        try FileManager.default.createDirectory(
            atPath: agentsPath, withIntermediateDirectories: true
        )

        let agent = AgentConfig(
            name: "test-amdchk",
            displayName: "Test",
            format: .agentsMD,
            userPathSuffix: agentsPath + "/AGENTS.md",
            projectPathSuffix: agentsPath + "/AGENTS.md"
        )

        let manager = SkillManager()
        #expect(!manager.isInstalled(agent: agent, level: .user))

        try manager.install(agent: agent, level: .user)
        #expect(manager.isInstalled(agent: agent, level: .user))
    }

    @Test("installedVersion returns correct version after install")
    func installedVersionCorrect() throws {
        let tempDir = try makeTempDir()
        defer { cleanupTempDir(tempDir) }

        let skillPath = tempDir + "/version-check"
        let agent = AgentConfig(
            name: "test-verchk",
            displayName: "Test",
            format: .skillDir,
            userPathSuffix: skillPath,
            projectPathSuffix: skillPath
        )

        let manager = SkillManager()
        #expect(manager.installedVersion(agent: agent, level: .user) == nil,
                "Version should be nil before install")

        try manager.install(agent: agent, level: .user)
        let version = manager.installedVersion(agent: agent, level: .user)
        #expect(version == SkillConfig.version,
                "Installed version should match SkillConfig.version, got: \(version ?? "nil")")
    }

    @Test("installedVersion returns correct version for agentsMD after install")
    func installedVersionAgentsMD() throws {
        let tempDir = try makeTempDir()
        defer { cleanupTempDir(tempDir) }

        let agentsPath = tempDir + "/version-amd"
        try FileManager.default.createDirectory(
            atPath: agentsPath, withIntermediateDirectories: true
        )

        let agent = AgentConfig(
            name: "test-veramd",
            displayName: "Test",
            format: .agentsMD,
            userPathSuffix: agentsPath + "/AGENTS.md",
            projectPathSuffix: agentsPath + "/AGENTS.md"
        )

        let manager = SkillManager()
        try manager.install(agent: agent, level: .user)

        let version = manager.installedVersion(agent: agent, level: .user)
        #expect(version == SkillConfig.version,
                "Installed version from AGENTS.md marker should match SkillConfig.version")
    }

    @Test("installedVersion returns nil after uninstall")
    func installedVersionNilAfterUninstall() throws {
        let tempDir = try makeTempDir()
        defer { cleanupTempDir(tempDir) }

        let skillPath = tempDir + "/version-uninst"
        let agent = AgentConfig(
            name: "test-verun",
            displayName: "Test",
            format: .skillDir,
            userPathSuffix: skillPath,
            projectPathSuffix: skillPath
        )

        let manager = SkillManager()
        try manager.install(agent: agent, level: .user)
        try manager.uninstall(agent: agent, level: .user)

        #expect(manager.installedVersion(agent: agent, level: .user) == nil,
                "Version should be nil after uninstall")
    }
}

// MARK: - AgentConfig Path Tests

@Suite("AgentConfig Paths")
struct AgentConfigPathTests {

    @Test("Codex user path ends with AGENTS.md")
    func codexUserPathFile() {
        let agent = SkillConfig.findAgent(name: "codex")!
        let path = agent.path(level: .user)
        #expect(path.hasSuffix("AGENTS.md"),
                "Codex user path should end with AGENTS.md")
    }

    @Test("Codex project path ends with AGENTS.md")
    func codexProjectPathFile() {
        let agent = SkillConfig.findAgent(name: "codex")!
        let path = agent.path(level: .project)
        #expect(path.hasSuffix("AGENTS.md"),
                "Codex project path should end with AGENTS.md")
    }

    @Test("SkillDir agents user paths end with agentax")
    func skillDirUserPathsEndWithAgentax() {
        let skillDirAgents = SkillConfig.agents.filter {
            if case .skillDir = $0.format { return true }
            return false
        }

        for agent in skillDirAgents {
            let path = agent.path(level: .user)
            #expect(path.hasSuffix("/agentax") || path.hasSuffix("/agentax/"),
                    "\(agent.name) user path should end with 'agentax', got: \(path)")
        }
    }

    @Test("SkillDir agents project paths end with agentax")
    func skillDirProjectPathsEndWithAgentax() {
        let skillDirAgents = SkillConfig.agents.filter {
            if case .skillDir = $0.format { return true }
            return false
        }

        for agent in skillDirAgents {
            let path = agent.path(level: .project)
            #expect(path.hasSuffix("/agentax") || path.hasSuffix("/agentax/"),
                    "\(agent.name) project path should end with 'agentax', got: \(path)")
        }
    }

    @Test("Antigravity user path contains gemini/antigravity")
    func antigravityUserPath() {
        let agent = SkillConfig.findAgent(name: "antigravity")!
        let path = agent.path(level: .user)
        #expect(path.contains(".gemini/antigravity"),
                "Antigravity user path should route through .gemini/antigravity")
    }

    @Test("Antigravity project path contains .agent")
    func antigravityProjectPath() {
        let agent = SkillConfig.findAgent(name: "antigravity")!
        let path = agent.path(level: .project)
        #expect(path.contains(".agent/"),
                "Antigravity project path should use .agent/ directory")
    }
}

// MARK: - InstallLevel Tests

@Suite("InstallLevel")
struct InstallLevelTests {

    @Test("InstallLevel has exactly two cases")
    func caseCount() {
        #expect(InstallLevel.allCases.count == 2)
    }

    @Test("InstallLevel raw values are lowercase strings")
    func rawValues() {
        #expect(InstallLevel.project.rawValue == "project")
        #expect(InstallLevel.user.rawValue == "user")
    }

    @Test("InstallLevel is Sendable")
    func sendable() {
        // Compile-time check: if this compiles, InstallLevel conforms to Sendable
        let level: any Sendable = InstallLevel.project
        #expect(level is InstallLevel)
    }
}
