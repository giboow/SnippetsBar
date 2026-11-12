import AppKit
import UniformTypeIdentifiers

/// macOS interactions: pasteboard, Finder, dialogs, System Settings.
enum SystemActions {
    /// Window of the menu bar panel, set by StatusBarController.
    static weak var menuBarPanel: NSWindow?

    static func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// File picker; nil if cancelled.
    static func chooseFile(types: [UTType]) -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = types
        panel.allowsMultipleSelection = false
        return inFrontOfMenuBarPanel { panel.runModal() == .OK ? panel.url : nil }
    }

    /// Modal alert; returns the index of the chosen button. Escape picks the last button.
    static func ask(_ title: String, message: String, buttons: [String]) -> Int {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        buttons.forEach { alert.addButton(withTitle: $0) }
        alert.buttons.last?.keyEquivalent = "\u{1b}"
        let response = inFrontOfMenuBarPanel { alert.runModal() }
        return response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
    }

    /// Reads the message with VoiceOver (no effect when VoiceOver is off).
    static func announce(_ message: String) {
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                             userInfo: [.announcement: message,
                                        .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    static func openFullDiskAccessSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
    }

    /// The menu bar panel sits at a high window level, above dialogs (including the file picker,
    /// partly drawn by another process): it is lowered for the duration of the dialog.
    private static func inFrontOfMenuBarPanel<T>(_ runDialog: () -> T) -> T {
        // No Dock icon: the app must be activated for the dialog to come to the front.
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
