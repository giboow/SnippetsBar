import Foundation
import SnippetsBarCore

@MainActor
final class SnippetStore: ObservableObject {
    @Published private(set) var snippets: [Snippet] = []
    @Published var errorMessage: String?
    @Published var toast: String?

    private let repository: SnippetRepository

    init(repository: SnippetRepository) {
        self.repository = repository
        reload()
    }

    func reload() {
        do {
            snippets = try repository.fetchAll()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func save(id: Int64?, draft: SnippetDraft) -> Bool {
        perform(id == nil ? "Snippet ajouté" : "Snippet modifié") {
            if let id {
                try repository.update(id: id, shortcut: draft.normalizedShortcut, phrase: draft.phrase)
            } else {
                try repository.insert(shortcut: draft.normalizedShortcut, phrase: draft.phrase)
            }
        }
    }

    @discardableResult
    func delete(_ snippet: Snippet) -> Bool {
        perform("Snippet supprimé") { try repository.delete(id: snippet.id) }
    }

    func copy(_ snippet: Snippet) {
        SystemActions.copyToPasteboard(snippet.phrase)
        flash("Copié : \(snippet.shortcut)")
    }

    func backupNow() {
        do {
            SystemActions.revealInFinder(try repository.backup())
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exportPlist() {
        do {
            let url = PlistExporter.defaultURL
            try PlistExporter.export(snippets, to: url)
            SystemActions.revealInFinder(url)
            flash("Exporté dans Téléchargements")
        } catch {
            errorMessage = error.localizedDescription
        }
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
}
