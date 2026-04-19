// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BudgetGoat",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "BudgetCore", targets: ["BudgetCore"]),
        .library(name: "BudgetData", targets: ["BudgetData"]),
        .library(name: "SecureStorage", targets: ["SecureStorage"]),
        .library(name: "PlaidKit", targets: ["PlaidKit"]),
        .library(name: "TransactionEngine", targets: ["TransactionEngine"]),
        .library(name: "BudgetUI", targets: ["BudgetUI"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "BudgetCore",
            path: "Sources/BudgetCore"
        ),
        .target(
            name: "SecureStorage",
            dependencies: ["BudgetCore"],
            path: "Sources/SecureStorage"
        ),
        .target(
            name: "BudgetData",
            dependencies: ["BudgetCore", "SecureStorage"],
            path: "Sources/BudgetData"
        ),
        .target(
            name: "PlaidKit",
            dependencies: ["BudgetCore", "SecureStorage"],
            path: "Sources/PlaidKit"
        ),
        .target(
            name: "TransactionEngine",
            dependencies: ["BudgetCore"],
            path: "Sources/TransactionEngine"
        ),
        .target(
            name: "BudgetUI",
            dependencies: ["BudgetCore", "BudgetData", "PlaidKit", "TransactionEngine", "SecureStorage"],
            path: "Sources/BudgetUI"
        ),
        .testTarget(
            name: "BudgetCoreTests",
            dependencies: ["BudgetCore"],
            path: "Tests/BudgetCoreTests"
        ),
        .testTarget(
            name: "BudgetDataTests",
            dependencies: ["BudgetData"],
            path: "Tests/BudgetDataTests"
        ),
        .testTarget(
            name: "SecureStorageTests",
            dependencies: ["SecureStorage"],
            path: "Tests/SecureStorageTests"
        ),
        .testTarget(
            name: "TransactionEngineTests",
            dependencies: ["TransactionEngine"],
            path: "Tests/TransactionEngineTests"
        ),
    ]
)
