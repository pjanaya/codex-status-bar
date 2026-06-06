// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodexStatusBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CodexStatusBar", targets: ["CodexStatusBar"])
    ],
    targets: [
        .target(name: "CodexStatusCore"),
        .executableTarget(
            name: "CodexStatusBar",
            dependencies: ["CodexStatusCore"]
        ),
        .testTarget(
            name: "CodexStatusCoreTests",
            dependencies: ["CodexStatusCore"]
        )
    ]
)
