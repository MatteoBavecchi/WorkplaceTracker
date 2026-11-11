// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "WorkplaceTracker",
    platforms: [.macOS(.v13)],
    targets: [
        // Pure logic (no UI, no system APIs) so it can be tested in isolation.
        .target(name: "WorkplaceCore"),
        .executableTarget(name: "WorkplaceTracker", dependencies: ["WorkplaceCore"]),
        .testTarget(name: "WorkplaceCoreTests", dependencies: ["WorkplaceCore"]),
    ]
)
