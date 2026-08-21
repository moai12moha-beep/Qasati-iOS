// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QasatiDomain",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "QasatiDomain", targets: ["QasatiDomain"])
    ],
    targets: [
        .target(
            name: "QasatiDomain"
        ),
        .testTarget(
            name: "QasatiDomainTests",
            dependencies: ["QasatiDomain"]
        )
    ]
)
