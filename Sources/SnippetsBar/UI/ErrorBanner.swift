import SwiftUI

struct ErrorBanner: View {
    @EnvironmentObject private var store: SnippetStore
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(message).foregroundStyle(.primary)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Full Disk Access…") { SystemActions.openFullDiskAccessSettings() }
                Button("Retry") { store.reload() }
            }
            .controlSize(.small)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.15))
    }
}
