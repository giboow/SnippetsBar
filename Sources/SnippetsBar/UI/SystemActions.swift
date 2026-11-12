import AppKit
import UniformTypeIdentifiers

/// Interactions avec macOS : presse-papiers, Finder, dialogues, Réglages Système.
enum SystemActions {
    /// Fenêtre du panneau de la barre des menus, renseignée par StatusBarController.
    static weak var menuBarPanel: NSWindow?

    static func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Choix d'un fichier ; nil si annulé.
    static func chooseFile(types: [UTType]) -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = types
        panel.allowsMultipleSelection = false
        return inFrontOfMenuBarPanel { panel.runModal() == .OK ? panel.url : nil }
    }

    /// Alerte modale ; renvoie l'index du bouton choisi. Échap choisit le dernier bouton.
    static func ask(_ title: String, message: String, buttons: [String]) -> Int {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        buttons.forEach { alert.addButton(withTitle: $0) }
        alert.buttons.last?.keyEquivalent = "\u{1b}"
        let response = inFrontOfMenuBarPanel { alert.runModal() }
        return response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
    }

    /// Lit le message avec VoiceOver (sans effet si VoiceOver est inactif).
    static func announce(_ message: String) {
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                             userInfo: [.announcement: message,
                                        .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    static func openFullDiskAccessSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
    }

    /// Le panneau de la barre des menus est à un niveau élevé, au-dessus des dialogues (dont le
    /// sélecteur de fichier, affiché en partie par un autre processus) : on l'abaisse le temps du dialogue.
    private static func inFrontOfMenuBarPanel<T>(_ runDialog: () -> T) -> T {
        // App sans Dock : il faut l'activer pour que le dialogue passe au premier plan.
        NSApp.activate(ignoringOtherApps: true)
        let panel = menuBarPanel
        let level = panel?.level
        panel?.level = .normal
        defer { if let level { panel?.level = level } }
        return runDialog()
    }

    private static func open(_ string: String) {
        if let url = URL(string: string) { NSWorkspace.shared.open(url) }
    }
}
