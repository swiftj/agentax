import ArgumentParser
import AgentAX

@main
struct AgentAXCLI: AsyncParsableCommand {
    static var version: String { agentaxVersion }

    static let configuration = CommandConfiguration(
        commandName: "agentax",
        abstract: "Native accessibility testing harness for SwiftUI and RealityKit applications",
        version: version,
        subcommands: [
            DumpCommand.self,
            QueryCommand.self,
            FindCommand.self,
            ActionCommand.self,
            InfoCommand.self,
            TestCommand.self,
            ServeCommand.self,
            SkillCommand.self,
            WaitCommand.self,
            AssertCommand.self,
            SnapshotDiffCommand.self,
            ActivateCommand.self,
            FrontmostCommand.self,
            ClickAtCommand.self,
            TypeCommand.self,
            DetailsCommand.self,
            MenuCommand.self,
            CustomContentCommand.self,
        ]
    )

    mutating func run() async throws {
        print("agentax v\(Self.version)")
        print("")
        print(Self.helpMessage())
    }
}
