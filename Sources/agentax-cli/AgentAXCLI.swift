import ArgumentParser
import AgentAX

@main
struct AgentAXCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "agentax",
        abstract: "Native accessibility testing harness for SwiftUI and RealityKit applications",
        version: "0.1.0",
        subcommands: [
            DumpCommand.self,
            QueryCommand.self,
            FindCommand.self,
            ActionCommand.self,
            InfoCommand.self,
            TestCommand.self,
        ]
    )
}
