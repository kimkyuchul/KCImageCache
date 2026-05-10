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
        .testTarget(
            name: "KCImageCacheTests",
            dependencies: ["KCImageCache"],
            path: "Tests/KCImageCacheTests",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
