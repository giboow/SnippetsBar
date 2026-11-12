import SwiftUI
import SnippetsBarCore

struct CommandRow: View {
    let command: CommandSnippet
    let isRunning: Bool
    let onRun: () -> Void
    let onEdit: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RowBadge(text: command.name, systemImage: "terminal", monospaced: false)
                .frame(maxWidth: 130, alignment: .leading)
                .layoutPriority(1)

            Text(command.command)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 3)

            if isRunning {
                ProgressView().controlSize(.small)
            } else if hovering {
                HStack(spacing: 4) {
                    RowIconButton(systemImage: "play.fill", help: "Exécuter et copier la sortie", action: onRun)
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
        .onTapGesture(count: 1, perform: onRun)
        .help("Exécuter et copier la sortie")
        .contextMenu {
            Button("Exécuter et copier la sortie", action: onRun)
            Button("Modifier…", action: onEdit)
        }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Commande \(command.name) : \(command.command)")
        .accessibilityHint("Exécute la commande et copie sa sortie")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, onRun)
        .accessibilityAction(named: "Modifier", onEdit)
    }
}
