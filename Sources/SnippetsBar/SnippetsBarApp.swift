import AppKit
import SnippetsBarCore

/// AppKit entry point, without any SwiftUI scene: a scene (even an empty `Settings`) opened
/// whenever the app was activated, e.g. for the import file picker.
@main
enum SnippetsBarApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // No Dock icon, even when launched with `swift run`.
        NSApp.setActivationPolicy(.accessory)
        NSApp.mainMenu = Self.editMenu()
        LaunchAtLogin.enableOnFirstLaunch()
        statusBar = StatusBarController(store: SnippetStore(repository: TextReplacementsRepository()))
    }

    /// Invisible menu (no Dock icon) but required for the editing shortcuts
    /// of text fields (⌘Z, ⇧⌘Z, ⌘X, ⌘C, ⌘V, ⌘A) and ⌘W in the Settings window.
    private static func editMenu() -> NSMenu {
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let window = NSMenu(title: "Window")
        window.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        let main = NSMenu()
        main.addItem(NSMenuItem())   // app menu slot, ignored by AppKit
        for submenu in [edit, window] {
            let item = NSMenuItem()
            item.submenu = submenu
            main.addItem(item)
        }
        return main
    }
}
