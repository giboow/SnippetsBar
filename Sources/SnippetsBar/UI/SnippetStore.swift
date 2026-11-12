import Foundation
import SnippetsBarCore

@MainActor
final class SnippetStore: ObservableObject {
    @Published private(set) var snippets: [Snippet] = []
    @Published var errorMessage: String?
    @Published var toast: Toast?
    @Published private(set) var launchAtLogin = LaunchAtLogin.isEnabled

    // Keyboard selection in the list (quick pick with ⌃⌘V, ↑ ↓ and ↩).
    @Published var query = "" { didSet { selectFirst() } }
    @Published private(set) var selectedID: Snippet.ID?
    @Published private(set) var searchFocusRequest = 0
    /// Set by ContentView: keys are left to the editor while it is shown.
    var isEditing = false
    /// Set by StatusBarController: closes the panel after a keyboard pick.
    var onRequestClose: (() -> Void)?

    // Global shortcut of the quick pick.
    @Published private(set) var quickPickShortcut = HotKeyShortcut.load()
    /// Set by StatusBarController: registers the global shortcut (nil unregisters);
    /// returns false when another app already uses it.
    var registerShortcut: ((HotKeyShortcut?) -> Bool)?

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
        if !visibleSnippets.contains(where: { $0.id == selectedID }) { selectFirst() }
    }

    // MARK: Quick pick

    var visibleSnippets: [Snippet] { snippets.filtered(by: query) }

    /// Fresh search with the first snippet selected and the search field focused.
    func prepareQuickPick() {
        query = ""
        searchFocusRequest += 1
    }

    func moveSelection(by delta: Int) {
        let items = visibleSnippets
        guard !items.isEmpty else { return }
        let index = items.firstIndex { $0.id == selectedID } ?? -1
        selectedID = items[min(max(index + delta, 0), items.count - 1)].id
    }

    /// Copies the selected snippet and closes the panel; false if nothing is selected.
    @discardableResult
    func copySelection() -> Bool {
        guard let snippet = visibleSnippets.first(where: { $0.id == selectedID }) else { return false }
        copy(snippet)
        onRequestClose?()
        return true
    }

    // MARK: Quick pick shortcut

    enum ShortcutChange { case done, tooFewModifiers, commonInApps, usedByMacOS, usedByAnotherApp }

    /// Keeps the current shortcut when the new one would clash with apps, macOS or another app.
    @discardableResult
    func changeShortcut(to shortcut: HotKeyShortcut) -> ShortcutChange {
        guard let registerShortcut else { return .usedByAnotherApp }
        switch ShortcutRules.problem(with: shortcut.combo) {
        case .tooFewModifiers: return .tooFewModifiers
        case .commonInApps: return .commonInApps
        case nil: break
        }
        if SystemShortcuts.contains(shortcut) {
            _ = registerShortcut(quickPickShortcut)
            return .usedByMacOS
        }
        guard registerShortcut(shortcut) else {
            _ = registerShortcut(quickPickShortcut)
            return .usedByAnotherApp
        }
        quickPickShortcut = shortcut
        shortcut.save()
        return .done
    }

    func suspendShortcut() { _ = registerShortcut?(nil) }
    func resumeShortcut() { _ = registerShortcut?(quickPickShortcut) }

    /// Set by StatusBarController.
    var onOpenSettings: (() -> Void)?
    func openSettings() { onOpenSettings?() }

    // MARK: Version and updates

    enum UpdateStatus: Equatable { case idle, checking, upToDate, available(Release), failed }

    /// nil for development builds (version “0.0.0-dev”), which never check for updates.
    let currentVersion = AppVersion(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
    @Published private(set) var updateStatus = UpdateStatus.idle
    @Published var checksForUpdatesAutomatically = UserDefaults.standard.object(forKey: "checkForUpdates") as? Bool ?? true {
        didSet { UserDefaults.standard.set(checksForUpdatesAutomatically, forKey: "checkForUpdates") }
    }

    var availableUpdate: Release? {
        if case .available(let release) = updateStatus { return release }
        return nil
    }

    /// e.g. “1.2.0 (54)”.
    var versionLabel: String? {
        guard let currentVersion else { return nil }
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? currentVersion.description : "\(currentVersion) (\(build))"
    }

    func checkForUpdates() {
        guard let currentVersion, updateStatus != .checking else { return }
        updateStatus = .checking
        Task {
            do {
                let release = try await UpdateChecker.latestRelease()
                UserDefaults.standard.set(Date(), forKey: "lastUpdateCheck")
                updateStatus = release.version > currentVersion ? .available(release) : .upToDate
            } catch {
                updateStatus = .failed
            }
        }
    }

    /// At most once a day, unless turned off in Settings.
    func checkForUpdatesIfDue() {
        guard checksForUpdatesAutomatically else { return }
        let last = UserDefaults.standard.object(forKey: "lastUpdateCheck") as? Date ?? .distantPast
        if Date().timeIntervalSince(last) > 24 * 60 * 60 { checkForUpdates() }
    }

    private func selectFirst() {
        selectedID = visibleSnippets.first?.id
    }

    @discardableResult
    func save(id: Int64?, draft: SnippetDraft) -> Bool {
        perform(id == nil ? String(localized: "Snippet added") : String(localized: "Snippet updated")) {
            if let id {
                try repository.update(id: id, shortcut: draft.normalizedShortcut, phrase: draft.phrase)
            } else {
                try repository.insert(shortcut: draft.normalizedShortcut, phrase: draft.phrase)
            }
        }
    }

    @discardableResult
    func delete(_ snippet: Snippet) -> Bool {
        perform(String(localized: "Snippet deleted")) { try repository.delete(id: snippet.id) }
    }

    func copy(_ snippet: Snippet) {
        SystemActions.copyToPasteboard(snippet.phrase)
        flash(String(localized: "Copied: \(snippet.shortcut)"))
    }


    /// Imports a .plist in the System Settings format. Exact duplicates are skipped;
    /// for existing shortcuts with a different text, a single question covers them all.
    func importPlist() {
        guard let url = SystemActions.chooseFile(types: [.propertyList]) else { return }
        reload()
        let plan: ImportPlan
        do {
            plan = ImportPlan(importing: try PlistImporter.drafts(from: url), into: snippets)
        } catch {
            return flash(String(localized: "Invalid .plist file"), .error)
        }
        guard !plan.isEmpty else {
            return flash(String(localized: "Nothing to import (already present: \(plan.duplicateCount))"), .info)
        }

        var replace = false
        if !plan.conflicts.isEmpty {
            let count = plan.conflicts.count
            let shortcuts = plan.conflicts.prefix(5).map(\.snippet.shortcut).joined(separator: ", ")
            let choice = SystemActions.ask(
                String(localized: "Shortcuts already used with a different text: \(count)"),
                message: shortcuts + (count > 5 ? "…" : ""),
                buttons: [String(localized: "Replace"), String(localized: "Keep Current"), String(localized: "Cancel")]
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
            flash(String(localized: "Exported to Downloads"))
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
                flash(String(localized: "Allow it in System Settings"), .info)
            } else {
                flash(enabled ? String(localized: "Launch at login enabled") : String(localized: "Launch at login disabled"))
            }
        } catch {
            flash(String(localized: "Couldn’t change launch at login"), .error)
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
