// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "wordly-id",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "WordlyID", targets: ["WordlyID"]),
        .library(name: "WordlyRefs", targets: ["WordlyRefs"]),
    ],
    targets: [
        .target(
            name: "WordlyID",
            resources: [.process("Resources")]
        ),
        .target(
            name: "WordlyRefs",
            dependencies: ["WordlyID"]
        ),
        .testTarget(
            name: "WordlyIDTests",
            dependencies: ["WordlyID"]
        ),
        .testTarget(
            name: "WordlyRefsTests",
            dependencies: ["WordlyRefs"]
        ),
    ]
)
