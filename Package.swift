// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "YiLi",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "YiLiCore", targets: ["YiLiCore"]),
        .executable(name: "YiLiMac", targets: ["YiLiMac"]),
    ],
    targets: [
        .target(name: "YiLiCore"),
        .executableTarget(name: "YiLiMac", dependencies: ["YiLiCore"]),
        .testTarget(name: "YiLiCoreTests", dependencies: ["YiLiCore"]),
    ]
)
