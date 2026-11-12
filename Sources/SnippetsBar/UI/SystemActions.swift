import AppKit
import UniformTypeIdentifiers

/// Interactions avec macOS : presse-papiers, Finder, dialogues, Réglages Système.
enum SystemActions {
    static func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Choix d'un fichier ; nil si annulé.
    static func chooseFile(types: [UTType]) -> URL? {
        // App sans Dock : il faut l'activer pour que le dialogue passe au premier plan.
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = types
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Alerte modale ; renvoie l'index du bouton choisi. Échap choisit le dernier bouton.
    static func ask(_ title: String, message: String, buttons: [String]) -> Int {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        buttons.forEach { alert.addButton(withTitle: $0) }
        alert.buttons.last?.keyEquivalent = "\u{1b}"
        return alert.runModal().rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
    }

    static func openFullDiskAccessSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
    }

    private static func open(_ string: String) {
        if let url = URL(string: string) { NSWorkspace.shared.open(url) }
    }
}
