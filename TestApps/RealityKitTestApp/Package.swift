// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RealityKitTestApp",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "RealityKitTestApp",
            dependencies: [
                .product(name: "AgentAXBridge", package: "agentax"),
            ],
            path: "Sources"
        ),
    ]
)
