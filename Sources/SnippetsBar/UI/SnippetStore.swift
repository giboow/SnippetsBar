import Foundation
import SnippetsBarCore

@MainActor
final class SnippetStore: ObservableObject {
    @Published private(set) var snippets: [Snippet] = []
    @Published var errorMessage: String?
    @Published var toast: Toast?
    @Published private(set) var launchAtLogin = LaunchAtLogin.isEnabled

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


    /// Importe un .plist au format des Réglages Système. Les doublons exacts sont ignorés ;
    /// pour les raccourcis existants avec un autre texte, une seule question pour tous.
    func importPlist() {
        guard let url = SystemActions.chooseFile(types: [.propertyList]) else { return }
        reload()
        let plan: ImportPlan
        do {
            plan = ImportPlan(importing: try PlistImporter.drafts(from: url), into: snippets)
        } catch {
            return flash("Fichier .plist invalide", .error)
        }
        guard !plan.isEmpty else {
            return flash("Rien à importer (\(plan.duplicateCount) déjà présent\(plan.duplicateCount > 1 ? "s" : ""))", .info)
        }

        var replace = false
        if !plan.conflicts.isEmpty {
            let count = plan.conflicts.count
            let shortcuts = plan.conflicts.prefix(5).map(\.snippet.shortcut).joined(separator: ", ")
            let choice = SystemActions.ask(
                count > 1 ? "\(count) raccourcis existent déjà avec un texte différent"
                          : "1 raccourci existe déjà avec un texte différent",
                message: shortcuts + (count > 5 ? "…" : ""),
                buttons: ["Remplacer", "Conserver les actuels", "Annuler"]
            )
            switch choice {
            case 0: replace = true
            case 1: replace = false
            default: return
            }
        }
        _ = perform(plan.summary(replacingConflicts: replace)) {
            try repository.apply(plan, replacingConflicts: replace)
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

    func refreshLaunchAtLogin() {
        launchAtLogin = LaunchAtLogin.isEnabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.setEnabled(enabled)
            if LaunchAtLogin.requiresApproval {
                LaunchAtLogin.openSystemSettings()
                flash("À autoriser dans Réglages Système", .info)
            } else {
                flash(enabled ? "Ouverture au démarrage activée" : "Ouverture au démarrage désactivée")
            }
        } catch {
            flash("Impossible de modifier l'ouverture au démarrage", .error)
        }
        refreshLaunchAtLogin()
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

    func dismissToast() {
        toast = nil
    }

    private func flash(_ message: String, _ kind: Toast.Kind = .success) {
        let toast = Toast(message: message, kind: kind)
        self.toast = toast
        SystemActions.announce(message)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(toast.duration * 1_000_000_000))
            if self.toast?.id == toast.id { self.toast = nil }
        }
    }
}
