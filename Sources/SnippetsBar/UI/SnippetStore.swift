import Foundation
import SnippetsBarCore

@MainActor
final class SnippetStore: ObservableObject {
    @Published private(set) var snippets: [Snippet] = []
    @Published private(set) var commands: [CommandSnippet] = []
    @Published private(set) var runningCommand: CommandSnippet.ID?
    @Published var errorMessage: String?
    @Published var toast: String?
    @Published private(set) var launchAtLogin = LaunchAtLogin.isEnabled

    private let repository: SnippetRepository
    private let commandRepository: CommandSnippetRepository

    init(repository: SnippetRepository, commandRepository: CommandSnippetRepository) {
        self.repository = repository
        self.commandRepository = commandRepository
        reload()
    }

    func reload() {
        do {
            snippets = try repository.fetchAll()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        do {
            commands = try commandRepository.fetchAll().sortedByName()
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

    // MARK: Commandes

    @discardableResult
    func saveCommand(id: CommandSnippet.ID?, draft: CommandDraft) -> Bool {
        var all = commands
        if let id, let index = all.firstIndex(where: { $0.id == id }) {
            all[index].name = draft.normalizedName
            all[index].command = draft.normalizedCommand
        } else {
            all.append(CommandSnippet(name: draft.normalizedName, command: draft.normalizedCommand))
        }
        return perform(id == nil ? "Commande ajoutée" : "Commande modifiée") {
            try commandRepository.saveAll(all.sortedByName())
        }
    }

    @discardableResult
    func deleteCommand(_ command: CommandSnippet) -> Bool {
        perform("Commande supprimée") {
            try commandRepository.saveAll(commands.filter { $0.id != command.id })
        }
    }

    /// Exécute la commande et copie sa sortie.
    func run(_ command: CommandSnippet) {
        guard runningCommand == nil else { return }
        runningCommand = command.id
        Task {
            let result = await ShellCommandRunner.run(command.command)
            runningCommand = nil
            guard result.succeeded else { return flash(result.failureSummary) }
            SystemActions.copyToPasteboard(result.output)
            flash(result.output.isEmpty ? "\(command.name) : aucune sortie" : "Copié : \(command.name)")
        }
    }

    // MARK: Fichiers

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

    func refreshLaunchAtLogin() {
        launchAtLogin = LaunchAtLogin.isEnabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.setEnabled(enabled)
            if LaunchAtLogin.requiresApproval {
                LaunchAtLogin.openSystemSettings()
                flash("À autoriser dans Réglages Système")
            } else {
                flash(enabled ? "Ouverture au démarrage activée" : "Ouverture au démarrage désactivée")
            }
        } catch {
            flash("Impossible de modifier l'ouverture au démarrage")
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

    private func flash(_ message: String) {
        toast = message
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if toast == message { toast = nil }
        }
    }
}
