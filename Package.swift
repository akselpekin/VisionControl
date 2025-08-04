// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "HandControl",
    platforms: [
        .macOS(.v15),
    ],
    targets: [
        .executableTarget(
            name: "HandControl",
            dependencies: ["GUI", "LOGIC"],
        ),
        .target(
            name: "LOGIC"
        ),
        .target(
            name: "GUI",
            dependencies: ["LOGIC"]
        ),
    ]
)
