// swift-tools-version: 6.2
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
        .package(url: "https://github.com/apple/swift-log", from: "1.6.4")
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                "TelegramCore"
            ]
        ),
        .target(name: "TelegramCore"),
        .testTarget(
            name: "TelegramCoreTests",
            path: "Tests/TelegramCoreTests",
            dependencies: ["TelegramCore"]
        )
    ]
)
