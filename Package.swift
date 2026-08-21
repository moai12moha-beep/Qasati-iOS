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
        .library(name: "QasatiPersistence", targets: ["QasatiPersistence"])
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
        )
    ]
)
