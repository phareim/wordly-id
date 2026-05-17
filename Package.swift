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
        // No pkgConfig: rely on the SDK's libsqlite3 on Apple platforms
        // (works for macOS, iOS, iOS Simulator) and the system libsqlite3
        // on Linux. The shim's `link "sqlite3"` directive injects -lsqlite3.
        .systemLibrary(
            name: "CSQLite",
            providers: [
                .apt(["libsqlite3-dev"]),
            ]
        ),
        .target(
            name: "WordlyRefs",
            dependencies: [
                "WordlyID",
                .target(name: "CSQLite", condition: .when(platforms: [.linux])),
            ]
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
