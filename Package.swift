// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MIRA",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MIRA", targets: ["MIRA"]),
        .library(name: "MIRACore", targets: ["MIRACore"])
    ],
    targets: [
        .target(name: "MIRACore", swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(
            name: "MIRA",
            dependencies: ["MIRACore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "MIRACoreTests", dependencies: ["MIRACore"])
    ]
)