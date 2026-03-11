// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NailUI",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "NailUI",
            targets: ["NailUI"]
        ),
    ],
    targets: [
        .target(
            name: "NailUI"
        ),
        .testTarget(
            name: "NailUITests",
            dependencies: ["NailUI"]
        ),
    ]
)
