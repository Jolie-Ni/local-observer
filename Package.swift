// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ObserverDaemon",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.27.0"),
    ],
    targets: [
        .target(
            name: "ObserverCore",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .executableTarget(
            name: "ObserverDaemon",
            dependencies: ["ObserverCore"]
        ),
        .target(
            name: "ObserverAnalyzer",
            dependencies: ["ObserverCore"]
        ),
        .executableTarget(
            name: "ObserverDashboard",
            dependencies: ["ObserverCore", "ObserverAnalyzer"]
        ),
    ]
)
