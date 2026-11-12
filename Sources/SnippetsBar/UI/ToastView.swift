import SwiftUI

/// Feedback message shown at the bottom of the panel.
struct Toast: Equatable, Identifiable {
    enum Kind { case success, info, error }

    let id = UUID()
    let message: String
    let kind: Kind

    /// Errors stay longer: there must be time to read them.
    var duration: TimeInterval { kind == .error ? 4 : 2.5 }
}

struct ToastView: View {
    let toast: Toast
    let onDismiss: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10)
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
            Text(toast.message)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(color.opacity(0.12), in: shape)
        .background(Color(nsColor: .windowBackgroundColor), in: shape)
        .overlay(shape.strokeBorder(color.opacity(0.7), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.2), radius: 10, y: 3)
        .padding(.horizontal, 16)
        .onTapGesture(perform: onDismiss)
        .help("Click to dismiss")
        .accessibilityElement(children: .combine)
    }

    private var icon: String {
        switch toast.kind {
        case .success: return "checkmark.circle.fill"
        case .info:    return "info.circle.fill"
        case .error:   return "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch toast.kind {
        case .success: return .green
        case .info:    return .blue
        case .error:   return .orange
        }
    }
}
