// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Saywise",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "SaywiseCore", targets: ["SaywiseCore"]),
        .executable(name: "Saywise", targets: ["Saywise"]),
        .executable(name: "SaywiseSmokeTests", targets: ["SaywiseSmokeTests"])
    ],
    targets: [
        .target(
            name: "SaywiseCore",
            path: "Sources/SaywiseCore"
        ),
        .executableTarget(
            name: "Saywise",
            dependencies: ["SaywiseCore"],
            path: "Sources/Saywise"
        ),
        .executableTarget(
            name: "SaywiseSmokeTests",
            dependencies: ["SaywiseCore"],
            path: "Tests/SaywiseSmokeTests"
        )
    ]
)
