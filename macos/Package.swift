// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ReceiptSorterCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "ReceiptSorterCore", targets: ["ReceiptSorterCore"]),
        .executable(name: "receipt-cli", targets: ["ReceiptCLI"]),
        .executable(name: "ReceiptSorterApp", targets: ["ReceiptSorterApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/openid/AppAuth-iOS.git", from: "1.6.2"),
        .package(url: "https://github.com/CoreOffice/CoreXLSX.git", from: "0.14.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift", branch: "main"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", branch: "main")
    ],
    targets: [
        .target(
            name: "ReceiptSorterCore",
            dependencies: [
                .product(name: "AppAuth", package: "AppAuth-iOS"),
                .product(name: "CoreXLSX", package: "CoreXLSX"),
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm")
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