import AppKit
import SwiftUI

/// Icône de la barre des menus : clic gauche = panneau des snippets, clic droit = réglages.
@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    private let store: SnippetStore
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private var outsideClickMonitor: Any?

    init(store: SnippetStore) {
        self.store = store
        super.init()

        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 380, height: 480)
        popover.contentViewController = NSHostingController(rootView: ContentView().environmentObject(store))

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "text.quote", accessibilityDescription: "SnippetsBar")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "SnippetsBar — clic droit : réglages"
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
        // App sans Dock : sans activation, les champs de saisie ne reçoivent pas le clavier.
        NSApp.activate(ignoringOtherApps: true)
        popover.contentViewController?.view.window?.makeKey()
        // .transient ne voit pas toujours les clics dans les autres apps quand l'app n'a pas de Dock :
        // on ferme nous-mêmes au premier clic extérieur. (Pas d'autorisation requise pour la souris.)
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.popover.performClose(nil)
        }
    }

    func popoverDidClose(_ notification: Notification) {
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        outsideClickMonitor = nil
    }

    private func showSettingsMenu() {
        popover.performClose(nil)
        // Menu attaché le temps d'un clic : sinon il remplacerait aussi le clic gauche.
        statusItem.menu = makeSettingsMenu()
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    /// Mêmes actions que le menu ⋯ du panneau.
    private func makeSettingsMenu() -> NSMenu {
        store.refreshLaunchAtLogin()
        let menu = NSMenu()
        menu.addItem(ActionMenuItem("Exporter en .plist…") { [store] in store.exportPlist() })
        // Panneau ouvert ensuite pour montrer le résultat (toast et nouvelles entrées).
        menu.addItem(ActionMenuItem("Importer un .plist…") { [weak self] in
            self?.store.importPlist()
            self?.showPopover()
        })
        menu.addItem(.separator())
        let launch = ActionMenuItem("Ouvrir au démarrage") { [store] in store.setLaunchAtLogin(!store.launchAtLogin) }
        launch.state = store.launchAtLogin ? .on : .off
        menu.addItem(launch)
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem("Quitter SnippetsBar", key: "q") { NSApp.terminate(nil) })
        return menu
    }
}

/// NSMenuItem qui exécute une closure.
private final class ActionMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, key: String = "", handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: key)
        target = self
    }

    required init(coder: NSCoder) { fatalError("init(coder:) non pris en charge") }

    @objc private func run() { handler() }
}
