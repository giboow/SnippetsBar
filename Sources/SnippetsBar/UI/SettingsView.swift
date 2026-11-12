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
                        Text(message(for: conflict))
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
                Text("Opens SnippetsBar from any app to pick a snippet with the keyboard. Conflicts with macOS, other global shortcuts and common app shortcuts are detected, but not every menu shortcut inside apps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("About") {
                LabeledContent("Version") {
                    if let label = store.versionLabel {
                        Text(verbatim: label)
                    } else {
                        Text("Development build")
                    }
                }
                Toggle("Check for Updates Automatically", isOn: $store.checksForUpdatesAutomatically)
                HStack {
                    updateStatus
                    Spacer()
                    if let update = store.availableUpdate {
                        Button("Download") { NSWorkspace.shared.open(update.url) }
                            .buttonStyle(.borderedProminent)
                    } else {
                        Button("Check for Updates") { store.checkForUpdates() }
                            .disabled(store.currentVersion == nil || store.updateStatus == .checking)
                    }
                }
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

    @ViewBuilder
    private var updateStatus: some View {
        switch store.updateStatus {
        case .idle:
            EmptyView()
        case .checking:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Checking…").foregroundStyle(.secondary)
            }
        case .upToDate:
            Label("SnippetsBar is up to date", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.secondary)
        case .available(let release):
            Label("Version \(release.version.description) is available", systemImage: "arrow.down.circle.fill")
                .foregroundStyle(Color.accentColor)
        case .failed:
            Label("Couldn’t check for updates", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.secondary)
        }
    }

    private func message(for conflict: SnippetStore.ShortcutChange) -> LocalizedStringKey {
        switch conflict {
        case .tooFewModifiers:
            return "Use at least two of ⌘, ⌥ and ⌃, so the shortcut doesn’t clash with app commands or typing."
        case .commonInApps:
            return "This shortcut is commonly used in apps"
        case .usedByMacOS:
            return "This shortcut is used by macOS (System Settings › Keyboard › Keyboard Shortcuts)"
        case .usedByAnotherApp, .done:
            return "This shortcut is already used by another app"
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
