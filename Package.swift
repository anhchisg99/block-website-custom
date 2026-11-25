// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "WebBlocker",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "WebBlockerCore"),
        .executableTarget(name: "WebBlocker", dependencies: ["WebBlockerCore"]),
        .testTarget(name: "WebBlockerCoreTests", dependencies: ["WebBlockerCore"]),
    ]
)
