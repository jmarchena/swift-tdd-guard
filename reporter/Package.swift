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
        .executable(
            name: "tdd-guard-swift-test",
            targets: ["TDDGuardTestParser"]
        ),
    ],
    targets: [
        .target(
            name: "TDDGuardReporter",
            path: "Sources/TDDGuardReporter"
        ),
        .executableTarget(
            name: "TDDGuardTestParser",
            path: "Sources/TDDGuardTestParser"
        ),
        .testTarget(
            name: "TDDGuardReporterTests",
            dependencies: ["TDDGuardReporter"],
            path: "Tests/TDDGuardReporterTests"
        ),
    ]
)
