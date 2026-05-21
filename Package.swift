// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "stylus",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "stylus", targets: ["stylus"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-configuration.git", from: "0.2.0", traits: ["YAMLSupport"]),
        .package(url: "https://github.com/jpsim/Yams", from: "6.2.0"),
        .package(url: "https://github.com/rapierorg/telegram-bot-swift", from: "2.1.3"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "stylus",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "TelegramBotSDK", package: "telegram-bot-swift"),
                .product(name: "Configuration", package: "swift-configuration"),
                "Yams",
            ],
        ),
        .testTarget(
            name: "stylusTests",
            dependencies: ["stylus"],
        ),
    ],
)
