// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "VisionControl",
    platforms: [
        .macOS(.v15),
    ],
    targets: [
        .executableTarget(
            name: "VisionControl",
            dependencies: ["LOGIC"],
        ),
        .target(
            name: "LOGIC"
        ),
    ]
)
