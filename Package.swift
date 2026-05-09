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
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.22.0")
        // DocC plugin временно отключен для ускорения тестов
        // Включить перед генерацией документации: swift package generate-documentation
        // .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.3")
        // SwiftLint отключен для ускорения сборки на Linux
        // См. BACKLOG.md: "SwiftLint через pre-commit hook"
        // .package(url: "https://github.com/realm/SwiftLint", from: "0.57.0")
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                "TDLibAdapter",
                "DigestCore",
                "BotBridge"
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
            name: "FoundationExtensions",
            dependencies: [],
            path: "Sources/FoundationExtensions"
        ),
        .target(
            name: "TGClientInterfaces",
            dependencies: [],
            path: "Sources/TGClientInterfaces"
        ),
        .target(
            name: "TgClientModels",
            dependencies: ["TGClientInterfaces", "FoundationExtensions"],
            path: "Sources/TgClientModels"
        ),
        .target(
            name: "TDLibAdapter",
            dependencies: [
                "CTDLib",
                "TGClientInterfaces",
                "TgClientModels",
                "FoundationExtensions",
                .product(name: "Logging", package: "swift-log")
            ],
            path: "Sources/TDLibAdapter"
        ),
        .target(
            name: "TgClient",
            dependencies: ["TDLibAdapter"],
            path: "Sources/TgClient"
            // DocC resources временно отключены для ускорения тестов
            // resources: [
            //     .copy("TgClient.docc")
            // ]
        ),
        .target(
            name: "DigestCore",
            dependencies: ["TGClientInterfaces", "TgClientModels"],
            path: "Sources/DigestCore",
            exclude: ["Generators/SummaryGenerator.md"]
        ),
        .target(
            name: "BotBridge",
            dependencies: [
                "DigestCore",
                "TDLibAdapter",
                "TgClientModels",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Hummingbird", package: "hummingbird")
            ],
            path: "Sources/BotBridge"
        ),
        // Test targets
        .target(
            name: "TestHelpers",
            dependencies: ["TGClientInterfaces", "TgClientModels", "FoundationExtensions", "TDLibAdapter", "DigestCore"],
            path: "Tests/TestHelpers"
        ),
        .testTarget(
            name: "TgClientUnitTests",
            dependencies: ["FoundationExtensions", "TDLibAdapter", "DigestCore", "TestHelpers"],
            path: "Tests/TgClientUnitTests"
        ),
        .testTarget(
            name: "TgClientComponentTests",
            dependencies: ["TDLibAdapter", "DigestCore", "TestHelpers"],
            path: "Tests/TgClientComponentTests"
        ),
        .testTarget(
            name: "TgClientE2ETests",
            dependencies: ["TDLibAdapter", "DigestCore", "App", "TestHelpers"],
            path: "Tests/TgClientE2ETests"
        )
    ]
)
