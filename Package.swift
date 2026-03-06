// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "agentax",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "agentax", targets: ["agentax-cli"]),
        .library(name: "AgentAX", targets: ["AgentAX"]),
        .library(name: "AgentAXBridge", targets: ["AgentAXBridge"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk", from: "0.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "agentax-cli",
            dependencies: [
                "AgentAX",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "AgentAX",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "MCP", package: "swift-sdk"),
            ]
        ),
        .target(
            name: "AgentAXBridge",
            dependencies: []
        ),
        .testTarget(
            name: "AgentAXTests",
            dependencies: ["AgentAX"]
        ),
        .testTarget(
            name: "AgentAXBridgeTests",
            dependencies: ["AgentAXBridge"]
        ),
    ]
)
