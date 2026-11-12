import SwiftUI
import Carbon.HIToolbox

/// Screen to change the quick pick shortcut.
struct ShortcutView: View {
    @EnvironmentObject private var store: SnippetStore
    let onClose: () -> Void

    @State private var recording = false
    @State private var keyMonitor: Any?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .keyboardShortcut(.cancelAction)
                Spacer()
                Text("Quick Pick Shortcut")
                    .font(.headline)
                Spacer()
                Color.clear.frame(width: 60, height: 1)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                Text("Opens SnippetsBar from any app to pick a snippet with the keyboard.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Group {
                    if recording {
                        Text("Press the new shortcut…")
                            .font(.title3)
                            .foregroundStyle(Color.accentColor)
                    } else {
                        Text(verbatim: store.quickPickShortcut.label)
                            .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 72)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(recording ? Color.accentColor : Color.primary.opacity(0.12),
                                  lineWidth: recording ? 2 : 1))
                .accessibilityElement(children: .combine)

                // Stacked so that long translations are never truncated.
                VStack(alignment: .leading, spacing: 8) {
                    if recording {
                        Button("Cancel") { stopRecording(cancelled: true) }
                    } else {
                        Button("Record New Shortcut", action: startRecording)
                            .buttonStyle(.borderedProminent)
                    }
                    Button("Reset to Default (\(HotKeyShortcut.default.label))") {
                        store.changeShortcut(to: .default)
                    }
                    .disabled(recording || store.quickPickShortcut == .default)
                }

                Text("Use at least ⌘, ⌃ or ⌥. Some system shortcuts can’t be detected as conflicts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding(14)
        }
        .onDisappear { if recording { stopRecording(cancelled: true) } }
    }

    private func startRecording() {
        // The current shortcut would otherwise fire instead of being recorded.
        store.suspendShortcut()
        recording = true
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if Int(event.keyCode) == kVK_Escape {
                stopRecording(cancelled: true)
            } else if let shortcut = HotKeyShortcut(event: event) {
                stopRecording(cancelled: false)
                store.changeShortcut(to: shortcut)
            } else {
                NSSound.beep()
            }
            return nil
        }
    }

    private func stopRecording(cancelled: Bool) {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        recording = false
        if cancelled { store.resumeShortcut() }
    }
}
