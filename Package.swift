// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NowPlayingBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "NowPlayingBar", targets: ["NowPlayingBar"])
    ],
    targets: [
        .executableTarget(
            name: "NowPlayingBar",
            path: "Sources/NowPlayingBar",
            resources: [
                .copy("Resources")
            ]
        )
    ]
)
