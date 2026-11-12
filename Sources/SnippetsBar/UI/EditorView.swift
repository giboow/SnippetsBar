import SwiftUI
import SnippetsBarCore

struct EditorView: View {
    @EnvironmentObject private var store: SnippetStore
    let target: ContentView.EditTarget
    let onClose: () -> Void

    @State private var draft = SnippetDraft()
    @State private var confirmDelete = false
    @FocusState private var focus: Field?

    private enum Field { case shortcut, phrase }

    private var existing: Snippet? {
        if case .existing(let s) = target { return s }
        return nil
    }

    private var isDuplicate: Bool { draft.isDuplicate(in: store.snippets, excluding: existing?.id) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .keyboardShortcut(.cancelAction)
                Spacer()
                Text(existing == nil ? LocalizedStringKey("New Snippet") : LocalizedStringKey("Edit Snippet"))
                    .font(.headline)
                Spacer()
                Color.clear.frame(width: 60, height: 1)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Shortcut").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    TextField("e.g. ;sig", text: $draft.shortcut)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .focused($focus, equals: .shortcut)
                    if draft.shortcutHasWhitespace {
                        hint("The shortcut must not contain spaces.", icon: "xmark.octagon.fill", color: .red)
                    } else if isDuplicate {
                        hint("This shortcut already exists.", icon: "exclamationmark.triangle.fill", color: .orange)
                    } else {
                        hint("Tip: start with “;” to avoid accidental triggers.")
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("Text").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Spacer()
                        Text("Length: \(draft.phrase.count)").font(.caption).foregroundStyle(.secondary)
                    }
                    TextEditor(text: $draft.phrase)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.12)))
                        .focused($focus, equals: .phrase)
                }
            }
            .padding(14)

            Divider()

            HStack {
                if let existing {
                    Button(role: .destructive) {
                        if confirmDelete {
                            if store.delete(existing) { onClose() }
                        } else {
                            confirmDelete = true
                        }
                    } label: {
                        Text(confirmDelete ? LocalizedStringKey("Confirm Deletion") : LocalizedStringKey("Delete"))
                    }
                    .foregroundStyle(.red)
                }
                Spacer()
                Button("Cancel", action: onClose)
                Button("Save") {
                    if store.save(id: existing?.id, draft: draft) {
                        onClose()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!draft.isValid)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
        }
        .onAppear {
            draft = existing.map(SnippetDraft.init) ?? SnippetDraft()
            focus = existing == nil ? .shortcut : .phrase
        }
    }

    /// Only the icon carries the color: the text stays readable on any background.
    private func hint(_ text: LocalizedStringKey, icon: String? = nil, color: Color = .secondary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if let icon {
                Image(systemName: icon).foregroundStyle(color)
            }
            Text(text).foregroundStyle(icon == nil ? .secondary : .primary)
        }
        .font(.caption)
    }
}
