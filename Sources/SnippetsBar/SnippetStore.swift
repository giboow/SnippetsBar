import Foundation
import AppKit

@MainActor
final class SnippetStore: ObservableObject {
    @Published private(set) var snippets: [Snippet] = []
    @Published var errorMessage: String?
    @Published var toast: String?

    private let db = TextReplacementsDB()

    init() { reload() }

    func reload() {
        do {
            snippets = try db.fetchAll()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func filtered(by query: String) -> [Snippet] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return snippets }
        return snippets.filter {
            $0.shortcut.localizedCaseInsensitiveContains(q) || $0.phrase.localizedCaseInsensitiveContains(q)
        }
    }

    func isDuplicate(shortcut: String, excluding id: Int64?) -> Bool {
        snippets.contains { $0.shortcut == shortcut && $0.id != id }
    }

    @discardableResult
    func save(id: Int64?, shortcut: String, phrase: String) -> Bool {
        perform(id == nil ? "Snippet ajouté" : "Snippet modifié") {
            if let id {
                try db.update(id: id, shortcut: shortcut, phrase: phrase)
            } else {
                try db.insert(shortcut: shortcut, phrase: phrase)
            }
        }
    }

    @discardableResult
    func delete(_ snippet: Snippet) -> Bool {
        perform("Snippet supprimé") { try db.delete(id: snippet.id) }
    }

    func copy(_ snippet: Snippet) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(snippet.phrase, forType: .string)
        flash("Copié : \(snippet.shortcut)")
    }

    func backupNow() {
        do {
            let url = try db.backup()
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Méthode « officielle » : génère un .plist à glisser dans
    /// Réglages Système › Clavier › Remplacements de texte.
    func exportPlist() {
        let items = snippets.map { ["phrase": $0.phrase, "shortcut": $0.shortcut] }
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: items, format: .xml, options: 0)
            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
            let url = downloads.appendingPathComponent("Text Substitutions.plist")
            try data.write(to: url, options: .atomic)
            NSWorkspace.shared.activateFileViewerSelecting([url])
            flash("Exporté dans Téléchargements")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openKeyboardSettings() {
        open("x-apple.systempreferences:com.apple.Keyboard-Settings.extension")
    }

    func openFullDiskAccessSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
    }

    // MARK: -

    private func perform(_ success: String, _ action: () throws -> Void) -> Bool {
        do {
            try action()
            reload()
            flash(success)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func flash(_ message: String) {
        toast = message
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if toast == message { toast = nil }
        }
    }

    private func open(_ string: String) {
        if let url = URL(string: string) { NSWorkspace.shared.open(url) }
    }
}
