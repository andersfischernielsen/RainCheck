// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RainCheck",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "RainCheckLib", targets: ["RainCheckLib"]),
        .executable(name: "RainCheck", targets: ["RainCheck"]),
    ],
    targets: [
        .target(name: "RainCheckLib"),
        .executableTarget(
            name: "RainCheck",
            dependencies: ["RainCheckLib"]
        ),
    ]
)
