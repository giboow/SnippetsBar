import SwiftUI
import AppKit
import SnippetsBarCore

@main
struct SnippetsBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // L'icône de la barre des menus est gérée par StatusBarController (AppKit) :
        // MenuBarExtra ne distingue pas le clic droit. SwiftUI exige au moins une scène.
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Pas d'icône dans le Dock, même lancé via `swift run`.
        NSApp.setActivationPolicy(.accessory)
        statusBar = StatusBarController(store: SnippetStore(repository: TextReplacementsRepository()))
    }
}
