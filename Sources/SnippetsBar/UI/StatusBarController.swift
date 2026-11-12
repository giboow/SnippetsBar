import AppKit
import SwiftUI

/// Menu bar icon: left click = snippets panel, right click = settings.
@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    private let store: SnippetStore
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private var outsideClickMonitor: Any?

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
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // No Dock icon: without activation, text fields don't receive keyboard input.
        NSApp.activate(ignoringOtherApps: true)
        popover.contentViewController?.view.window?.makeKey()
        SystemActions.menuBarPanel = popover.contentViewController?.view.window
        // Click in another app: close. (No permission needed for mouse events.)
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }

    @objc private func closePopover() {
        // During a dialog (file picker, alert) the panel stays open: the file picker partly runs
        // in another process, so its clicks look like outside clicks.
        guard popover.isShown, NSApp.modalWindow == nil else { return }
        popover.performClose(nil)
    }

    func popoverDidClose(_ notification: Notification) {
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        outsideClickMonitor = nil
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
        menu.addItem(ActionMenuItem(String(localized: "Export as .plist…")) { [store] in store.exportPlist() })
        // Open the panel afterwards to show the result (toast and new entries).
        menu.addItem(ActionMenuItem(String(localized: "Import a .plist…")) { [weak self] in
            self?.store.importPlist()
            self?.showPopover()
        })
        menu.addItem(.separator())
        let launch = ActionMenuItem(String(localized: "Launch at Login")) { [store] in store.setLaunchAtLogin(!store.launchAtLogin) }
        launch.state = store.launchAtLogin ? .on : .off
        menu.addItem(launch)
        menu.addItem(.separator())
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
