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
            EditorHeader(title: existing == nil ? "Nouveau snippet" : "Modifier", onClose: onClose)

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Raccourci").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    TextField("ex. ;sig", text: $draft.shortcut)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .focused($focus, equals: .shortcut)
                    if draft.shortcutHasWhitespace {
                        FormHint("Le raccourci ne doit pas contenir d'espace.", icon: "xmark.octagon.fill", color: .red)
                    } else if isDuplicate {
                        FormHint("Ce raccourci existe déjà.", icon: "exclamationmark.triangle.fill", color: .orange)
                    } else {
                        FormHint("Astuce : préfixez par « ; » pour éviter les déclenchements involontaires.")
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("Texte").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(draft.phrase.count) car.").font(.caption).foregroundStyle(.secondary)
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
                        Text(confirmDelete ? "Confirmer la suppression" : "Supprimer")
                    }
                    .foregroundStyle(.red)
                }
                Spacer()
                Button("Annuler", action: onClose)
                Button("Enregistrer") {
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
}
