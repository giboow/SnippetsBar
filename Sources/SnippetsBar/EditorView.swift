import SwiftUI

struct EditorView: View {
    @EnvironmentObject private var store: SnippetStore
    let target: ContentView.EditTarget
    let onClose: () -> Void

    @State private var shortcut = ""
    @State private var phrase = ""
    @State private var confirmDelete = false
    @FocusState private var focus: Field?

    private enum Field { case shortcut, phrase }

    private var existing: Snippet? {
        if case .existing(let s) = target { return s }
        return nil
    }

    private var trimmedShortcut: String { shortcut.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isDuplicate: Bool { store.isDuplicate(shortcut: trimmedShortcut, excluding: existing?.id) }
    private var shortcutHasSpace: Bool { trimmedShortcut.contains(where: \.isWhitespace) }
    private var canSave: Bool { !trimmedShortcut.isEmpty && !phrase.isEmpty && !shortcutHasSpace }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) {
                    Label("Retour", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .keyboardShortcut(.cancelAction)
                Spacer()
                Text(existing == nil ? "Nouveau snippet" : "Modifier")
                    .font(.headline)
                Spacer()
                Color.clear.frame(width: 60, height: 1)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Raccourci").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    TextField("ex. ;sig", text: $shortcut)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .focused($focus, equals: .shortcut)
                    if shortcutHasSpace {
                        hint("Le raccourci ne doit pas contenir d'espace.", color: .red)
                    } else if isDuplicate {
                        hint("Ce raccourci existe déjà.", color: .orange)
                    } else {
                        hint("Astuce : préfixez par « ; » pour éviter les déclenchements involontaires.", color: .secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("Texte").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(phrase.count) car.").font(.caption2).foregroundStyle(.tertiary)
                    }
                    TextEditor(text: $phrase)
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
                        Text(confirmDelete ? "Confirmer la suppression" : "Supprimer")
                    }
                    .foregroundStyle(.red)
                }
                Spacer()
                Button("Annuler", action: onClose)
                Button("Enregistrer") {
                    if store.save(id: existing?.id, shortcut: trimmedShortcut, phrase: phrase) {
                        onClose()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
        }
        .onAppear {
            shortcut = existing?.shortcut ?? ""
            phrase = existing?.phrase ?? ""
            focus = existing == nil ? .shortcut : .phrase
        }
    }

    private func hint(_ text: String, color: Color) -> some View {
        Text(text).font(.caption2).foregroundStyle(color)
    }
}
