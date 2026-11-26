// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Gaia",
    platforms: [.iOS("27.0"), .macOS(.v14)],
    products: [
        .library(name: "Gaia", targets: ["Gaia"])
    ],
    targets: [
        .target(
            name: "Gaia",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "GaiaTests",
            dependencies: ["Gaia"]
        )
    ]
)
