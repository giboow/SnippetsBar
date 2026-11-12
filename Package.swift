// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SnippetsBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SnippetsBar",
            path: "Sources/SnippetsBar",
            linkerSettings: [.linkedLibrary("sqlite3")]
        )
    ]
)
