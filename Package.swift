// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KCImageCache",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "KCImageCache",
            targets: ["KCImageCache"]
        ),
        .library(
            name: "KCImageCacheUI",
            targets: ["KCImageCacheUI"]
        )
    ],
    targets: [
        .target(
            name: "KCImageCache",
            path: "Sources/KCImageCache",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "KCImageCacheUI",
            dependencies: ["KCImageCache"],
            path: "Sources/KCImageCacheUI",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "KCImageCacheTests",
            dependencies: ["KCImageCache", "KCImageCacheUI"],
            path: "Tests",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
