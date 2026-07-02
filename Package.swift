// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "twall",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "TwallCore", targets: ["TwallCore"]),
        .executable(name: "twall", targets: ["twall"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "TwallCore",
            dependencies: []
        ),
        .executableTarget(
            name: "twall",
            dependencies: [
                "TwallCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "TwallCoreTests",
            dependencies: ["TwallCore"]
        ),
    ]
)
