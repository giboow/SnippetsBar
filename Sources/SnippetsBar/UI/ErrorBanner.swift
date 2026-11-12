import SwiftUI

struct ErrorBanner: View {
    @EnvironmentObject private var store: SnippetStore
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Accès complet au disque…") { SystemActions.openFullDiskAccessSettings() }
                Button("Réessayer") { store.reload() }
            }
            .controlSize(.small)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
    }
}
