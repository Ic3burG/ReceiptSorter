// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ReceiptSorterCore",
    platforms: [
        .macOS(.v13) // Target macOS 13 (Ventura) for Grid and modern concurrency
    ],
    products: [
        // The library containing core logic
        .library(
            name: "ReceiptSorterCore",
            targets: ["ReceiptSorterCore"]
        ),
        // The CLI tool to run the logic
        .executable(
            name: "receipt-cli",
            targets: ["ReceiptCLI"]
        ),
        // The macOS GUI App
        .executable(
            name: "ReceiptSorterApp",
            targets: ["ReceiptSorterApp"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Kitura/Swift-JWT.git", from: "4.0.0")
    ],
    targets: [
        // Core Logic
        .target(
            name: "ReceiptSorterCore",
            dependencies: [
                .product(name: "SwiftJWT", package: "Swift-JWT")
            ]
        ),
        // CLI Tool
        .executableTarget(
            name: "ReceiptCLI",
            dependencies: ["ReceiptSorterCore"]
        ),
        // macOS GUI App
        .executableTarget(
            name: "ReceiptSorterApp",
            dependencies: ["ReceiptSorterCore"],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", "Sources/ReceiptSorterApp/Info.plist"])
            ]
        ),
        // Tests
        .testTarget(
            name: "ReceiptSorterCoreTests",
            dependencies: ["ReceiptSorterCore"]
        ),
    ]
)