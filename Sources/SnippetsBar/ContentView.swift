import SwiftUI
import AppKit

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
        .onAppear { store.reload() }
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
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .background(Color.accentColor.opacity(0.15), in: Circle())
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
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
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var list: some View {
        let items = store.filtered(by: query)
        if items.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: query.isEmpty ? "text.badge.plus" : "magnifyingglass")
                    .font(.system(size: 28))
                    .foregroundStyle(.tertiary)
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
                Button("Actualiser") { store.reload() }
                    .keyboardShortcut("r")
                Divider()
                Button("Exporter en .plist…") { store.exportPlist() }
                Button("Sauvegarder la base…") { store.backupNow() }
                Button("Ouvrir les réglages Clavier") { store.openKeyboardSettings() }
                Divider()
                Button("Quitter SnippetsBar") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

// MARK: - Ligne

struct SnippetRow: View {
    let snippet: Snippet
    let onCopy: () -> Void
    let onEdit: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(snippet.shortcut)
                .font(.system(.callout, design: .monospaced).weight(.semibold))
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 5))
                .foregroundStyle(Color.accentColor)
                .lineLimit(1)
                .frame(maxWidth: 130, alignment: .leading)
                .layoutPriority(1)

            Text(snippet.phrase)
                .font(.callout)
                .foregroundStyle(.primary.opacity(0.85))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if hovering {
                HStack(spacing: 4) {
                    iconButton("doc.on.doc", help: "Copier le texte", action: onCopy)
                    iconButton("pencil", help: "Modifier", action: onEdit)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 7)
        .background(hovering ? Color.primary.opacity(0.07) : .clear,
                    in: RoundedRectangle(cornerRadius: 7))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(count: 2, perform: onEdit)
        .onTapGesture(count: 1, perform: onCopy)
        .help(snippet.phrase)
        .contextMenu {
            Button("Copier le texte", action: onCopy)
            Button("Modifier…", action: onEdit)
        }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }

    private func iconButton(_ name: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 22, height: 22)
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

// MARK: - Erreur

struct ErrorBanner: View {
    @EnvironmentObject private var store: SnippetStore
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Accès complet au disque…") { store.openFullDiskAccessSettings() }
                Button("Réessayer") { store.reload() }
            }
            .controlSize(.small)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
    }
}
