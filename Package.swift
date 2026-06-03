// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "SessionDeck",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SessionDeck", targets: ["SessionDeckApp"]),
        .library(name: "SessionDeckCore", targets: ["SessionDeckCore"]),
    ],
    targets: [
        .executableTarget(
            name: "SessionDeckApp",
            dependencies: ["SessionDeckCore"],
            path: "Sources/SessionDeckApp"
        ),
        .target(
            name: "SessionDeckCore",
            path: "Sources/SessionDeckCore"
        ),
        .testTarget(
            name: "SessionDeckCoreTests",
            dependencies: ["SessionDeckCore"],
            path: "Tests/SessionDeckCoreTests",
            resources: [
                .process("Fixtures"),
            ]
        ),
    ]
)
