// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "swift-apple-freeform",
    // SQLite is read through swift-sqlite-reader; nothing is vendored. macOS
    // only — Freeform's store on a Mac is the one this reads.
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "AppleFreeform", targets: ["AppleFreeform"]),
    ],
    dependencies: [
        .package(url: "https://github.com/arraypress/swift-sqlite-reader.git", from: "0.2.0"),
    ],
    targets: [
        .target(name: "AppleFreeform", dependencies: [
            .product(name: "SQLiteReader", package: "swift-sqlite-reader"),
        ]),
        .testTarget(name: "AppleFreeformTests", dependencies: ["AppleFreeform"]),
    ]
)

// Swift 7's import rule, today: a file must import every module whose members
// it uses, rather than leaning on another file's imports.
for target in package.targets where target.type != .system && target.type != .binary && target.type != .plugin {
    target.swiftSettings = (target.swiftSettings ?? []) + [.enableUpcomingFeature("MemberImportVisibility")]
}
