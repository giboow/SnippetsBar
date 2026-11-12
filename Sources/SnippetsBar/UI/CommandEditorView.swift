import SwiftUI
import SnippetsBarCore

struct CommandEditorView: View {
    @EnvironmentObject private var store: SnippetStore
    let existing: CommandSnippet?
    let onClose: () -> Void

    @State private var draft = CommandDraft()
    @State private var confirmDelete = false
    @State private var testing = false
    @State private var testResult: CommandResult?
    @FocusState private var focus: Field?

    private enum Field { case name, command }

    var body: some View {
        VStack(spacing: 0) {
            EditorHeader(title: existing == nil ? "Nouvelle commande" : "Modifier la commande", onClose: onClose)

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Nom").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    TextField("ex. Date du jour", text: $draft.name)
                        .textFieldStyle(.roundedBorder)
                        .focused($focus, equals: .name)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("Commande").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Spacer()
                        Button("Tester", action: test)
                            .controlSize(.small)
                            .disabled(draft.normalizedCommand.isEmpty || testing)
                    }
                    TextEditor(text: $draft.command)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.12)))
                        .frame(minHeight: 60)
                        .focused($focus, equals: .command)
                    FormHint("Exécutée avec zsh (shell de connexion), délai de \(Int(ShellCommandRunner.defaultTimeout)) s. Un clic sur la ligne copie la sortie.")
                }

                testOutput
            }
            .padding(14)

            Divider()

            HStack {
                if let existing {
                    Button(role: .destructive) {
                        if confirmDelete {
                            if store.deleteCommand(existing) { onClose() }
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
                    if store.saveCommand(id: existing?.id, draft: draft) {
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
            draft = existing.map(CommandDraft.init) ?? CommandDraft()
            focus = existing == nil ? .name : .command
        }
        .onChange(of: draft.command) { _ in testResult = nil }
    }

    @ViewBuilder
    private var testOutput: some View {
        if testing {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Exécution…").font(.caption).foregroundStyle(.secondary)
            }
        } else if let result = testResult {
            let text = result.succeeded ? (result.output.isEmpty ? "(aucune sortie)" : result.output) : result.errorOutput
            VStack(alignment: .leading, spacing: 5) {
                if result.succeeded {
                    FormHint("Sortie", icon: "checkmark.circle.fill", color: .green)
                } else {
                    FormHint(result.failureSummary, icon: "xmark.octagon.fill", color: .red)
                }
                if !text.isEmpty {
                    ScrollView {
                        Text(text)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                    }
                    .frame(maxHeight: 90)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    private func test() {
        testing = true
        Task {
            testResult = await ShellCommandRunner.run(draft.normalizedCommand)
            testing = false
        }
    }
}
