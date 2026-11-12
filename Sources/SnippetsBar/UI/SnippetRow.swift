import SwiftUI
import SnippetsBarCore

struct SnippetRow: View {
    let snippet: Snippet
    var isSelected = false
    let onCopy: () -> Void
    let onEdit: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            shortcutBadge
                .frame(maxWidth: 130, alignment: .leading)
                .layoutPriority(1)

            Text(snippet.phrase)
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if hovering {
                HStack(spacing: 4) {
                    iconButton("doc.on.doc", help: "Copy Text", action: onCopy)
                    iconButton("pencil", help: "Edit", action: onEdit)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 7)
        .background(background, in: RoundedRectangle(cornerRadius: 7))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(count: 2, perform: onEdit)
        .onTapGesture(count: 1, perform: onCopy)
        .help(snippet.phrase)
        .contextMenu {
            Button("Copy Text", action: onCopy)
            Button("Edit…", action: onEdit)
        }
        .animation(.easeOut(duration: 0.12), value: hovering)
        // VoiceOver: one readable row; the hover buttons become actions.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(snippet.shortcut): \(snippet.phrase)")
        .accessibilityHint("Copies the text")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction(.default, onCopy)
        .accessibilityAction(named: "Edit", onEdit)
    }

    /// Keyboard selection wins over hover.
    private var background: Color {
        if isSelected { return Color.accentColor.opacity(0.18) }
        return hovering ? Color.primary.opacity(0.07) : .clear
    }

    /// Shortcut in the primary text color; the accent color is decoration only.
    private var shortcutBadge: some View {
        let shape = RoundedRectangle(cornerRadius: 5)
        return Text(snippet.shortcut)
            .font(.system(.callout, design: .monospaced).weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Color.accentColor.opacity(0.18), in: shape)
            .overlay(shape.strokeBorder(Color.accentColor.opacity(0.6)))
    }

    private func iconButton(_ name: String, help: LocalizedStringKey, action: @escaping () -> Void) -> some View {
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
