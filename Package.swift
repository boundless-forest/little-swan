// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ExpressBridge",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "ExpressBridgeCore", targets: ["ExpressBridgeCore"]),
        .executable(name: "ExpressBridge", targets: ["ExpressBridge"]),
        .executable(name: "ExpressBridgeSmokeTests", targets: ["ExpressBridgeSmokeTests"])
    ],
    targets: [
        .target(
            name: "ExpressBridgeCore",
            path: "Sources/ExpressBridgeCore"
        ),
        .executableTarget(
            name: "ExpressBridge",
            dependencies: ["ExpressBridgeCore"],
            path: "Sources/ExpressBridge"
        ),
        .executableTarget(
            name: "ExpressBridgeSmokeTests",
            dependencies: ["ExpressBridgeCore"],
            path: "Tests/ExpressBridgeSmokeTests"
        )
    ]
)
