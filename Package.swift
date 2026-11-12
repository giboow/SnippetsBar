// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SnippetsBar",
    platforms: [.macOS(.v13)],
    targets: [
        // Domaine + accès à la base des remplacements de texte (sans UI).
        .target(
            name: "SnippetsBarCore",
            path: "Sources/SnippetsBarCore",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        // Application de barre des menus (SwiftUI/AppKit).
        .executableTarget(
            name: "SnippetsBar",
            dependencies: ["SnippetsBarCore"],
            path: "Sources/SnippetsBar"
        ),
        .testTarget(
            name: "SnippetsBarCoreTests",
            dependencies: ["SnippetsBarCore"],
            path: "Tests/SnippetsBarCoreTests"
        )
    ]
)
