import SwiftUI
import Carbon.HIToolbox

/// Content of the Settings window.
struct SettingsView: View {
    @EnvironmentObject private var store: SnippetStore

    @State private var recording = false
    @State private var keyMonitor: Any?
    @State private var conflict: SnippetStore.ShortcutChange?

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at Login", isOn: Binding(
                    get: { store.launchAtLogin },
                    set: { store.setLaunchAtLogin($0) }
                ))
            }

            Section {
                LabeledContent("Shortcut") {
                    Button(action: recording ? { stopRecording(cancelled: true) } : startRecording) {
                        if recording {
                            Text("Press the new shortcut…")
                                .foregroundStyle(Color.accentColor)
                        } else {
                            Text(verbatim: store.quickPickShortcut.label)
                                .font(.body.weight(.semibold))
                        }
                    }
                    .help("Record New Shortcut")
                }
                if let conflict {
                    Label {
                        Text(conflict == .usedByMacOS
                             ? LocalizedStringKey("This shortcut is used by macOS (System Settings › Keyboard › Keyboard Shortcuts)")
                             : LocalizedStringKey("This shortcut is already used by another app"))
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                    .font(.callout)
                }
                HStack {
                    Spacer()
                    Button("Reset to Default (\(HotKeyShortcut.default.label))") {
                        apply(store.changeShortcut(to: .default))
                    }
                    .disabled(recording || store.quickPickShortcut == .default)
                }
            } header: {
                Text("Quick Pick")
            } footer: {
                Text("Opens SnippetsBar from any app to pick a snippet with the keyboard. Use at least ⌘, ⌃ or ⌥. Conflicts with macOS and other global shortcuts are detected, but not with menu shortcuts inside apps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { store.refreshLaunchAtLogin() }
        .onDisappear { if recording { stopRecording(cancelled: true) } }
    }

    private func startRecording() {
        // The current shortcut would otherwise fire instead of being recorded.
        store.suspendShortcut()
        conflict = nil
        recording = true
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if Int(event.keyCode) == kVK_Escape {
                stopRecording(cancelled: true)
            } else if let shortcut = HotKeyShortcut(event: event) {
                stopRecording(cancelled: false)
                apply(store.changeShortcut(to: shortcut))
            } else {
                NSSound.beep()
            }
            return nil
        }
    }

    private func apply(_ result: SnippetStore.ShortcutChange) {
        conflict = result == .done ? nil : result
    }

    private func stopRecording(cancelled: Bool) {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        recording = false
        if cancelled { store.resumeShortcut() }
    }
}

/// Settings window, created on first use.
@MainActor
final class SettingsWindowController {
    private let store: SnippetStore
    private var window: NSWindow?

    init(store: SnippetStore) {
        self.store = store
    }

    func show() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView().environmentObject(store)))
            window.title = String(localized: "SnippetsBar Settings")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        // No Dock icon: the app must be activated for the window to come to the front.
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
