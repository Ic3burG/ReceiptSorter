// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ReceiptSorterCore",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "ReceiptSorterCore", targets: ["ReceiptSorterCore"]),
        .executable(name: "receipt-cli", targets: ["ReceiptCLI"]),
        .executable(name: "ReceiptSorterApp", targets: ["ReceiptSorterApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/openid/AppAuth-iOS.git", from: "1.6.2"),
        .package(url: "https://github.com/CoreOffice/CoreXLSX.git", from: "0.14.0")
    ],
    targets: [
        .target(
            name: "ReceiptSorterCore",
            dependencies: [
                .product(name: "AppAuth", package: "AppAuth-iOS"),
                .product(name: "CoreXLSX", package: "CoreXLSX")
            ]
        ),
        .executableTarget(
            name: "ReceiptCLI",
            dependencies: ["ReceiptSorterCore"]
        ),
        .executableTarget(
            name: "ReceiptSorterApp",
            dependencies: ["ReceiptSorterCore"]
        ),
        .testTarget(
            name: "ReceiptSorterCoreTests",
            dependencies: ["ReceiptSorterCore"]
        ),
    ]
)