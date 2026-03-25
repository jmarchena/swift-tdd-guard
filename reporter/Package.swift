// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TDDGuardReporter",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "TDDGuardReporter",
            targets: ["TDDGuardReporter"]
        ),
    ],
    targets: [
        .target(
            name: "TDDGuardReporter",
            path: "Sources/TDDGuardReporter"
        ),
        .testTarget(
            name: "TDDGuardReporterTests",
            dependencies: ["TDDGuardReporter"],
            path: "Tests/TDDGuardReporterTests"
        ),
    ]
)
