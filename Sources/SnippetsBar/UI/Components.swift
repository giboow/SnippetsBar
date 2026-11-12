import SwiftUI

/// Étiquette d'une ligne : texte en couleur principale, l'accent ne sert qu'au décor.
struct RowBadge: View {
    let text: String
    var systemImage: String?
    var monospaced = true

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 5)
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage).font(.caption.weight(.bold))
            }
            Text(text)
                .font(monospaced ? .system(.callout, design: .monospaced).weight(.semibold)
                                 : .callout.weight(.semibold))
        }
        .foregroundStyle(.primary)
        .lineLimit(1)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Color.accentColor.opacity(0.18), in: shape)
        .overlay(shape.strokeBorder(Color.accentColor.opacity(0.6)))
    }
}

/// Petit bouton icône affiché au survol d'une ligne.
struct RowIconButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 22, height: 22)
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// Texte d'aide sous un champ. La couleur ne porte que l'icône :
/// le texte reste lisible quel que soit le fond.
struct FormHint: View {
    let text: String
    var icon: String?
    var color: Color = .secondary

    init(_ text: String, icon: String? = nil, color: Color = .secondary) {
        self.text = text
        self.icon = icon
        self.color = color
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if let icon {
                Image(systemName: icon).foregroundStyle(color)
            }
            Text(text).foregroundStyle(icon == nil ? .secondary : .primary)
        }
        .font(.caption)
    }
}

/// Barre du haut des écrans d'édition : retour + titre centré.
struct EditorHeader: View {
    let title: String
    let onClose: () -> Void

    var body: some View {
        HStack {
            Button(action: onClose) {
                Label("Retour", systemImage: "chevron.left")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .keyboardShortcut(.cancelAction)
            Spacer()
            Text(title)
                .font(.headline)
            Spacer()
            Color.clear.frame(width: 60, height: 1)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}
