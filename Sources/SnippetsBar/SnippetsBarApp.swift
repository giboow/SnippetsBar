import AppKit
import SnippetsBarCore

/// Démarrage AppKit, sans scène SwiftUI : une scène (même un `Settings` vide) s'ouvrait
/// quand l'app était activée, par exemple pour le sélecteur de fichier de l'import.
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
        // Pas d'icône dans le Dock, même lancé via `swift run`.
        NSApp.setActivationPolicy(.accessory)
        NSApp.mainMenu = Self.editMenu()
        LaunchAtLogin.enableOnFirstLaunch()
        statusBar = StatusBarController(store: SnippetStore(repository: TextReplacementsRepository()))
    }

    /// Menu invisible (app sans Dock) mais nécessaire aux raccourcis d'édition
    /// des champs de saisie : ⌘Z, ⇧⌘Z, ⌘X, ⌘C, ⌘V, ⌘A.
    private static func editMenu() -> NSMenu {
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let editItem = NSMenuItem()
        editItem.submenu = edit
        let main = NSMenu()
        main.addItem(NSMenuItem())   // emplacement du menu de l'app, ignoré par AppKit
        main.addItem(editItem)
        return main
    }
}
