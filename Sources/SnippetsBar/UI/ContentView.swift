import SwiftUI
import AppKit
import SnippetsBarCore

struct ContentView: View {
    @EnvironmentObject private var store: SnippetStore
    @State private var query = ""
    @State private var editing: EditTarget?

    enum EditTarget: Equatable {
        case new
        case existing(Snippet)
        case newCommand
        case existingCommand(CommandSnippet)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if let editing {
                editor(for: editing)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                listScreen
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            if let toast = store.toast {
                Text(toast)
                    .font(.callout.weight(.medium))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.thickMaterial, in: Capsule())
                    .padding(.bottom, 44)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: editing)
        .animation(.easeOut(duration: 0.2), value: store.toast)
        .frame(width: 380, height: 480)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            store.reload()
            store.refreshLaunchAtLogin()
        }
    }

    @ViewBuilder
    private func editor(for target: EditTarget) -> some View {
        switch target {
        case .new, .existing:
            EditorView(target: target) { editing = nil }
        case .newCommand:
            CommandEditorView(existing: nil) { editing = nil }
        case .existingCommand(let command):
            CommandEditorView(existing: command) { editing = nil }
        }
    }

    // MARK: Liste

    private var listScreen: some View {
        VStack(spacing: 0) {
            header
            searchField
            Divider()
            if let error = store.errorMessage {
                ErrorBanner(message: error)
            }
            list
            Divider()
            footer
        }
    }

    private var header: some View {
        HStack {
            Label("Remplacements de texte", systemImage: "text.quote")
                .font(.headline)
            Spacer()
            Button { editing = .new } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 26, height: 26)
                    .background(Color.accentColor, in: Circle())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Nouveau snippet")
            .keyboardShortcut("n")
            .help("Nouveau snippet (⌘N)")
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Rechercher un snippet ou une commande", text: $query)
                .textFieldStyle(.plain)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Effacer la recherche")
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var list: some View {
        let items = store.snippets.filtered(by: query)
        let commands = store.commands.filtered(by: query)
        if store.snippets.isEmpty && store.commands.isEmpty {
            emptyState(icon: "text.badge.plus", message: "Aucun snippet pour l'instant") {
                Button("Créer un snippet") { editing = .new }
            }
        } else if !query.isEmpty && items.isEmpty && commands.isEmpty {
            emptyState(icon: "magnifyingglass", message: "Aucun résultat") { EmptyView() }
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(items) { snippet in
                        SnippetRow(snippet: snippet,
                                   onCopy: { store.copy(snippet) },
                                   onEdit: { editing = .existing(snippet) })
                    }
                    if query.isEmpty || !commands.isEmpty {
                        commandsHeader
                        ForEach(commands) { command in
                            CommandRow(command: command,
                                       isRunning: store.runningCommand == command.id,
                                       onRun: { store.run(command) },
                                       onEdit: { editing = .existingCommand(command) })
                        }
                        if store.commands.isEmpty {
                            FormHint("Exécutez une commande shell et copiez sa sortie, ex. date +%F.")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                        }
                    }
                }
                .padding(6)
            }
        }
    }

    private var commandsHeader: some View {
        HStack {
            Text("Commandes")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button { editing = .newCommand } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 18, height: 18)
                    .background(Color.primary.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .help("Nouvelle commande (⇧⌘N)")
            .accessibilityLabel("Nouvelle commande")
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private func emptyState<Action: View>(icon: String, message: String,
                                          @ViewBuilder action: () -> Action) -> some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(message)
                .foregroundStyle(.secondary)
            action()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        HStack {
            Text(countLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Menu {
                Button("Nouvelle commande…") { editing = .newCommand }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button("Actualiser") { store.reload() }
                    .keyboardShortcut("r")
                Divider()
                Button("Exporter en .plist…") { store.exportPlist() }
                Button("Sauvegarder la base…") { store.backupNow() }
                Button("Ouvrir les réglages Clavier") { SystemActions.openKeyboardSettings() }
                Divider()
                Toggle("Ouvrir au démarrage", isOn: Binding(
                    get: { store.launchAtLogin },
                    set: { store.setLaunchAtLogin($0) }
                ))
                Divider()
                Button("Quitter SnippetsBar") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Plus d'actions")
            .accessibilityLabel("Plus d'actions")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var countLabel: String {
        let snippets = store.snippets.count, commands = store.commands.count
        var label = "\(snippets) snippet\(snippets > 1 ? "s" : "")"
        if commands > 0 { label += " · \(commands) commande\(commands > 1 ? "s" : "")" }
        return label
    }
}
