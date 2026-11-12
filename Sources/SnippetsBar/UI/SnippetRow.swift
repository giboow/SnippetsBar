import SwiftUI
import SnippetsBarCore

struct SnippetRow: View {
    let snippet: Snippet
    let onCopy: () -> Void
    let onEdit: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RowBadge(text: snippet.shortcut)
                .frame(maxWidth: 130, alignment: .leading)
                .layoutPriority(1)

            Text(snippet.phrase)
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if hovering {
                HStack(spacing: 4) {
                    RowIconButton(systemImage: "doc.on.doc", help: "Copier le texte", action: onCopy)
                    RowIconButton(systemImage: "pencil", help: "Modifier", action: onEdit)
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
        // VoiceOver : une seule ligne lisible, les boutons au survol deviennent des actions.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(snippet.shortcut) : \(snippet.phrase)")
        .accessibilityHint("Copie le texte")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, onCopy)
        .accessibilityAction(named: "Modifier", onEdit)
    }
}
