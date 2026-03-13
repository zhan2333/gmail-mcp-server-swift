// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GmailMCPServer",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "GmailMCPServer",
            targets: ["GmailMCPServer"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/zhan2333/FlooMCP.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "GmailMCPServer",
            dependencies: [
                .product(name: "FlooMCP", package: "FlooMCP"),
            ]
        ),
        .testTarget(
            name: "GmailMCPServerTests",
            dependencies: ["GmailMCPServer"]
        ),
    ]
)
