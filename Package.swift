// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "tg-client",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "tg-client", targets: ["App"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log", from: "1.6.4"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.3")
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                "TDLibAdapter"
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
        .systemLibrary(
            name: "CTDLib",
            pkgConfig: "tdjson",
            providers: [
                .brew(["tdlib"]),
                .apt(["libtdjson-dev"])
            ]
        ),
        .target(
            name: "TDLibAdapter",
            dependencies: [
                "CTDLib",
                .product(name: "Logging", package: "swift-log")
            ],
            path: "Sources/TDLibAdapter",
            resources: [
                .copy("README.md")
            ]
        ),
        .target(
            name: "TgClient",
            dependencies: ["TDLibAdapter"],
            path: "Sources/TgClient",
            resources: [
                .copy("TgClient.docc")
            ]
        ),
        // Test targets
        .testTarget(
            name: "TgClientUnitTests",
            dependencies: ["TDLibAdapter"],
            path: "Tests/TgClientUnitTests"
        ),
        .testTarget(
            name: "TgClientComponentTests",
            dependencies: ["TDLibAdapter"],
            path: "Tests/TgClientComponentTests"
        ),
        .testTarget(
            name: "TgClientE2ETests",
            dependencies: ["TDLibAdapter", "App"],
            path: "Tests/TgClientE2ETests"
        )
    ]
)
