// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LittleSwan",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "LittleSwanCore", targets: ["LittleSwanCore"]),
        .executable(name: "LittleSwan", targets: ["LittleSwan"]),
        .executable(name: "LittleSwanSmokeTests", targets: ["LittleSwanSmokeTests"])
    ],
    targets: [
        .target(
            name: "LittleSwanCore",
            path: "Sources/LittleSwanCore"
        ),
        .executableTarget(
            name: "LittleSwan",
            dependencies: ["LittleSwanCore"],
            path: "Sources/LittleSwan"
        ),
        .executableTarget(
            name: "LittleSwanSmokeTests",
            dependencies: ["LittleSwanCore"],
            path: "Tests/LittleSwanSmokeTests"
        )
    ]
)
