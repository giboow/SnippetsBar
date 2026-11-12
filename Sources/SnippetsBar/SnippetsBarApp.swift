import SwiftUI
import AppKit
import SnippetsBarCore

@main
struct SnippetsBarApp: App {
    @StateObject private var store = SnippetStore(
        repository: TextReplacementsRepository(),
        commandRepository: JSONCommandSnippetRepository()
    )

    init() {
        // Pas d'icône dans le Dock, même lancé via `swift run`.
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra("Snippets", systemImage: "text.quote") {
            ContentView()
                .environmentObject(store)
        }
        .menuBarExtraStyle(.window)
    }
}
