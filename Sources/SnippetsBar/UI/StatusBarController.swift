import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Menu bar icon: left click = snippets panel, right click = settings,
/// ⌃⌘V from anywhere = panel ready to pick a snippet with the keyboard.
@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    private let store: SnippetStore
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private var outsideClickMonitor: Any?
    private var keyMonitor: Any?
    private var hotKey: GlobalHotKey?
    private lazy var settings = SettingsWindowController(store: store)

    init(store: SnippetStore) {
        self.store = store
        super.init()

        // Closing is handled here (click in another app, app switch) rather than by .transient:
        // the import file picker and alerts must not close the panel.
        popover.behavior = .applicationDefined
        popover.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(closePopover),
                                               name: NSApplication.didResignActiveNotification, object: nil)
        popover.contentSize = NSSize(width: 380, height: 480)
        popover.contentViewController = NSHostingController(rootView: ContentView().environmentObject(store))

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "text.quote", accessibilityDescription: "SnippetsBar")
            image?.isTemplate = true
            button.image = image
            button.toolTip = String(localized: "SnippetsBar — right-click for settings")
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        store.onRequestClose = { [weak self] in self?.closePopover() }
        store.registerShortcut = { [weak self] shortcut in
            guard let self else { return false }
            self.hotKey = nil   // unregisters the previous shortcut
            guard let shortcut else { return true }
            self.hotKey = GlobalHotKey(keyCode: shortcut.keyCode, modifiers: shortcut.carbonModifiers) { [weak self] in
                self?.toggleFromHotKey()
            }
            return self.hotKey != nil
        }
        store.resumeShortcut()
        store.onOpenSettings = { [weak self] in
            self?.closePopover()
            self?.settings.show()
        }
        store.checkForUpdatesIfDue()
    }

    private func toggleFromHotKey() {
        if popover.isShown && NSApp.isActive {
            closePopover()
        } else {
            showPopover()
        }
    }

    @objc private func handleClick() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showSettingsMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button, !popover.isShown else { return }
        store.reload()
        store.refreshLaunchAtLogin()
        store.prepareQuickPick()
        store.checkForUpdatesIfDue()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // No Dock icon: without activation, text fields don't receive keyboard input.
        NSApp.activate(ignoringOtherApps: true)
        popover.contentViewController?.view.window?.makeKey()
        SystemActions.menuBarPanel = popover.contentViewController?.view.window
        // Click in another app: close. (No permission needed for mouse events.)
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
        // Keyboard pick in the list: ↑ ↓ to select, ↩ to copy, Escape to close.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, !self.store.isEditing,
                  event.window === self.popover.contentViewController?.view.window else { return event }
            switch Int(event.keyCode) {
            case kVK_UpArrow:   self.store.moveSelection(by: -1); return nil
            case kVK_DownArrow: self.store.moveSelection(by: 1); return nil
            case kVK_Return, kVK_ANSI_KeypadEnter: return self.store.copySelection() ? nil : event
            case kVK_Escape:    self.closePopover(); return nil
            default:            return event
            }
        }
    }

    @objc private func closePopover() {
        // During a dialog (file picker, alert) the panel stays open: the file picker partly runs
        // in another process, so its clicks look like outside clicks.
        guard popover.isShown, NSApp.modalWindow == nil else { return }
        popover.performClose(nil)
    }

    func popoverDidClose(_ notification: Notification) {
        for monitor in [outsideClickMonitor, keyMonitor].compactMap({ $0 }) { NSEvent.removeMonitor(monitor) }
        outsideClickMonitor = nil
        keyMonitor = nil
    }

    private func showSettingsMenu() {
        popover.performClose(nil)
        // Menu attached for one click only: otherwise it would replace the left click too.
        statusItem.menu = makeSettingsMenu()
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    /// Same actions as the panel's ⋯ menu.
    private func makeSettingsMenu() -> NSMenu {
        store.refreshLaunchAtLogin()
        let menu = NSMenu()
        if let version = store.currentVersion {
            let title = NSMenuItem(title: "SnippetsBar \(version)", action: nil, keyEquivalent: "")
            title.isEnabled = false
            menu.addItem(title)
        }
        if let update = store.availableUpdate {
            menu.addItem(ActionMenuItem(String(localized: "Update available: \(update.version.description)")) {
                NSWorkspace.shared.open(update.url)
            })
        }
        if menu.numberOfItems > 0 { menu.addItem(.separator()) }
        menu.addItem(ActionMenuItem(String(localized: "Export as .plist…")) { [store] in store.exportPlist() })
        // Open the panel afterwards to show the result (toast and new entries).
        menu.addItem(ActionMenuItem(String(localized: "Import a .plist…")) { [weak self] in
            self?.store.importPlist()
            self?.showPopover()
        })
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem(String(localized: "Settings…"), key: ",") { [store] in store.openSettings() })
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem(String(localized: "SnippetsBar on GitHub")) { SystemActions.openRepository() })
        menu.addItem(ActionMenuItem(String(localized: "Report an Issue…")) { SystemActions.openIssues() })
        menu.addItem(ActionMenuItem(String(localized: "Quit SnippetsBar"), key: "q") { NSApp.terminate(nil) })
        return menu
    }
}

/// NSMenuItem that runs a closure.
private final class ActionMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, key: String = "", handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: key)
        target = self
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func run() { handler() }
}
