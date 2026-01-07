// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ReceiptSorterCore",
    platforms: [
        .macOS(.v12) // Ensure we target macOS Monterey or later for Vision/Async features
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
        )
    ],
    targets: [
        // Core Logic
        .target(
            name: "ReceiptSorterCore"
        ),
        // CLI Tool
        .executableTarget(
            name: "ReceiptCLI",
            dependencies: ["ReceiptSorterCore"]
        ),
        // Tests
        .testTarget(
            name: "ReceiptSorterCoreTests",
            dependencies: ["ReceiptSorterCore"]
        ),
    ]
)