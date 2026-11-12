import SwiftUI
import SnippetsBarCore

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
