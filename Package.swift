// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "OcclusionKit",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(name: "OcclusionKit", targets: ["OcclusionKit"])
    ],
    targets: [
        .target(name: "OcclusionKit"),
        .testTarget(name: "OcclusionKitTests", dependencies: ["OcclusionKit"])
    ]
)
