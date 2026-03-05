import ArgumentParser
import AgentAX

@main
struct AgentAXCLI: AsyncParsableCommand {
    static let version = "0.1.1"

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
        ]
    )

    mutating func run() async throws {
        print("agentax v\(Self.version)")
        print("")
        print(Self.helpMessage())
    }
}
