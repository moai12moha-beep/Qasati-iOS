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
        .library(name: "QasatiDashboardFeature", targets: ["QasatiDashboardFeature"]),
        .library(name: "QasatiTransactionFormsFeature", targets: ["QasatiTransactionFormsFeature"]),
        .library(name: "QasatiPresentation", targets: ["QasatiPresentation"]),
        .library(name: "QasatiHistoryFeature", targets: ["QasatiHistoryFeature"]),
        .library(name: "QasatiBackupService", targets: ["QasatiBackupService"]),
        .library(name: "QasatiSettingsFeature", targets: ["QasatiSettingsFeature"]),
        .library(name: "QasatiSecurityFeature", targets: ["QasatiSecurityFeature"])
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
            dependencies: ["QasatiDomain", "QasatiPersistence", "QasatiPresentation"]
        ),
        .testTarget(
            name: "QasatiDashboardFeatureTests",
            dependencies: ["QasatiDashboardFeature", "QasatiDomain", "QasatiPersistence"]
        ),
        .target(
            name: "QasatiTransactionFormsFeature",
            dependencies: ["QasatiDomain", "QasatiTransactionService"]
        ),
        .testTarget(
            name: "QasatiTransactionFormsFeatureTests",
            dependencies: ["QasatiTransactionFormsFeature", "QasatiDomain", "QasatiPersistence"]
        ),
        .target(
            name: "QasatiPresentation"
        ),
        .testTarget(
            name: "QasatiPresentationTests",
            dependencies: ["QasatiPresentation"]
        ),
        .target(
            name: "QasatiHistoryFeature",
            dependencies: ["QasatiDomain", "QasatiPersistence", "QasatiPresentation", "QasatiTransactionService", "QasatiTransactionFormsFeature"]
        ),
        .testTarget(
            name: "QasatiHistoryFeatureTests",
            dependencies: ["QasatiHistoryFeature", "QasatiDomain", "QasatiPersistence"]
        ),
        .target(
            name: "QasatiBackupService",
            dependencies: ["QasatiDomain", "QasatiPersistence"]
        ),
        .testTarget(
            name: "QasatiBackupServiceTests",
            dependencies: ["QasatiBackupService", "QasatiDomain", "QasatiPersistence"]
        ),
        .target(
            name: "QasatiSettingsFeature",
            dependencies: ["QasatiPersistence", "QasatiBackupService", "QasatiPresentation"]
        ),
        .testTarget(
            name: "QasatiSettingsFeatureTests",
            dependencies: ["QasatiSettingsFeature", "QasatiDomain", "QasatiPersistence", "QasatiBackupService"]
        ),
        .target(
            name: "QasatiSecurityFeature"
        ),
        .testTarget(
            name: "QasatiSecurityFeatureTests",
            dependencies: ["QasatiSecurityFeature"]
        )
    ]
)
