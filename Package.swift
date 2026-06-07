// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Since",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "Since", path: "Sources/Since"),
        .testTarget(
            name: "SinceTests", dependencies: ["Since"], path: "Tests/SinceTests",
            resources: [.copy("Fixtures")]),
    ]
)
