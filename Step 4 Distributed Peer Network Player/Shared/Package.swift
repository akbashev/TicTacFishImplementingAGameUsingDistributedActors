// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Package description for the shared modules.
*/
import PackageDescription

var globalSwiftSettings: [SwiftSetting] = []

var targets: [Target] = [
    .target(
        name: "Client",
        dependencies: [
            "NaiveLogging",
            "Types",
            .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
        ],
        plugins: [.plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")]
    ),
    .target(
        name: "NaiveLogging"
    ),
    .target(
        name: "Native",
        dependencies: [
            "ViewModel",
            .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
        ]
    ),
    .target(
        name: "Types",
        dependencies: [.product(name: "OpenAPIRuntime", package: "swift-openapi-runtime")],
        plugins: [.plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")]
    ),
    .target(
        name: "ViewModel",
        dependencies: [
            "Client",
            "Types",
            .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
        ]
    ),
    .executableTarget(
        name: "Server",
        dependencies: [
            "Client",
            "NaiveLogging",
            "Types",
            .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            .product(name: "OpenAPIHummingbird", package: "swift-openapi-hummingbird"),
            .product(name: "DistributedCluster", package: "swift-distributed-actors"),
            .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
            .product(name: "VirtualActors", package: "cluster-virtual-actors"),
            .product(name: "EventSourcing", package: "cluster-event-sourcing"),
            .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
        ],
        plugins: [.plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")]
    ),
]

let package = Package(
    name: "TicTacFishPackage",
    platforms: [
        .macOS(.v15),
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "Native",
            targets: ["Native"]
        ),
        .executable(
            name: "Server",
            targets: ["Server"]
        )
    ],
    dependencies: [
        // clustersystem+plugins
        .package(url: "https://github.com/akbashev/swift-distributed-actors.git", branch: "presentation"),
        .package(url: "https://github.com/akbashev/cluster-event-sourcing.git", branch: "main"),
        .package(url: "https://github.com/akbashev/cluster-virtual-actors", branch: "main"),
        // openapi
        .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.6.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.7.0"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession", from: "1.0.0"),
        .package(url: "https://github.com/swift-server/swift-openapi-hummingbird", from: "2.0.0"),
        // utils
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.6.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "1.0.0"),
        
    ],
    targets: targets.map { target in
        var swiftSettings = target.swiftSettings ?? []
        if target.type != .plugin {
            swiftSettings.append(contentsOf: globalSwiftSettings)
        }
        if !swiftSettings.isEmpty {
            target.swiftSettings = swiftSettings
        }
        return target
    }
)
