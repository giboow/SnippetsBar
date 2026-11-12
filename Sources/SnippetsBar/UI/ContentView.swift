import SwiftUI
import AppKit
import SnippetsBarCore

struct ContentView: View {
    @EnvironmentObject private var store: SnippetStore
    @State private var editing: EditTarget?
    @FocusState private var searchFocused: Bool

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
        .onChange(of: editing) { store.isEditing = $0 != nil }
        .onChange(of: store.searchFocusRequest) { _ in searchFocused = true }
    }

    // MARK: List

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
        HStack(spacing: 10) {
            Image(systemName: "text.quote")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 7))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                // App name: a brand, not localized.
                Text(verbatim: "SnippetsBar")
                    .font(.title3.weight(.bold))
                Text("Text Replacements")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer()
            Button { editing = .new } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 26, height: 26)
                    .background(Color.accentColor, in: Circle())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New Snippet")
            .keyboardShortcut("n")
            .help("New Snippet (⌘N)")
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search shortcuts or text", text: $store.query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
            if !store.query.isEmpty {
                Button { store.query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear Search")
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var list: some View {
        let items = store.visibleSnippets
        let query = store.query
        if items.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: query.isEmpty ? "text.badge.plus" : "magnifyingglass")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(query.isEmpty ? LocalizedStringKey("No snippets yet") : LocalizedStringKey("No results"))
                    .foregroundStyle(.secondary)
                if query.isEmpty {
                    Button("Create a Snippet") { editing = .new }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(items) { snippet in
                            SnippetRow(snippet: snippet,
                                       isSelected: snippet.id == store.selectedID,
                                       onCopy: { store.copy(snippet) },
                                       onEdit: { editing = .existing(snippet) })
                                .id(snippet.id)
                        }
                    }
                    .padding(6)
                }
                .onChange(of: store.selectedID) { id in
                    if let id { proxy.scrollTo(id) }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("Snippets: \(store.snippets.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("Open from anywhere: \(store.quickPickShortcut.label)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Menu {
                Button("Export as .plist…") { store.exportPlist() }
                Button("Import a .plist…") { store.importPlist() }
                Divider()
                Button("Settings…") { store.openSettings() }
                    .keyboardShortcut(",")
                Divider()
                Button("SnippetsBar on GitHub") { SystemActions.openRepository() }
                Button("Report an Issue…") { SystemActions.openIssues() }
                Button("Quit SnippetsBar") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("More Actions")
            .accessibilityLabel("More Actions")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}
