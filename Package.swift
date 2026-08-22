// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QasatiDomain",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "QasatiDomain", targets: ["QasatiDomain"]),
        .library(name: "QasatiPersistence", targets: ["QasatiPersistence"]),
        .library(name: "QasatiTransactionService", targets: ["QasatiTransactionService"]),
        .library(name: "QasatiDashboardFeature", targets: ["QasatiDashboardFeature"])
    ],
    targets: [
        .target(
            name: "QasatiDomain"
        ),
        .testTarget(
            name: "QasatiDomainTests",
            dependencies: ["QasatiDomain"]
        ),
        .target(
            name: "QasatiPersistence",
            dependencies: ["QasatiDomain"]
        ),
        .testTarget(
            name: "QasatiPersistenceTests",
            dependencies: ["QasatiPersistence", "QasatiDomain"]
        ),
        .target(
            name: "QasatiTransactionService",
            dependencies: ["QasatiDomain", "QasatiPersistence"]
        ),
        .testTarget(
            name: "QasatiTransactionServiceTests",
            dependencies: ["QasatiTransactionService", "QasatiDomain", "QasatiPersistence"]
        ),
        .target(
            name: "QasatiDashboardFeature",
            dependencies: ["QasatiDomain", "QasatiPersistence"]
        ),
        .testTarget(
            name: "QasatiDashboardFeatureTests",
            dependencies: ["QasatiDashboardFeature", "QasatiDomain", "QasatiPersistence"]
        )
    ]
)
