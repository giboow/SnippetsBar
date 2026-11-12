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
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if let editing {
                EditorView(target: editing) { self.editing = nil }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                listScreen
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            if let toast = store.toast {
                ToastView(toast: toast) { store.dismissToast() }
                    .padding(.bottom, 48)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: editing)
        .animation(.easeOut(duration: 0.2), value: store.toast)
        .frame(width: 380, height: 480)
        .background(Color(nsColor: .windowBackgroundColor))
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
            TextField("Rechercher un raccourci ou un texte", text: $query)
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
        if items.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: query.isEmpty ? "text.badge.plus" : "magnifyingglass")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(query.isEmpty ? "Aucun snippet pour l'instant" : "Aucun résultat")
                    .foregroundStyle(.secondary)
                if query.isEmpty {
                    Button("Créer un snippet") { editing = .new }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(items) { snippet in
                        SnippetRow(snippet: snippet,
                                   onCopy: { store.copy(snippet) },
                                   onEdit: { editing = .existing(snippet) })
                    }
                }
                .padding(6)
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("\(store.snippets.count) snippet\(store.snippets.count > 1 ? "s" : "")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Menu {
                Button("Exporter en .plist…") { store.exportPlist() }
                Button("Importer un .plist…") { store.importPlist() }
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
}
