import ServiceManagement

/// Ouverture de l'app à la connexion (Réglages Système › Général › Ouverture).
/// Ne fonctionne que depuis le bundle SnippetsBar.app, pas avec `swift run`.
enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// L'utilisateur a désactivé l'élément dans les Réglages : il doit le réautoriser lui-même.
    static var requiresApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    /// Active l'ouverture au démarrage une seule fois, au premier lancement de l'app installée.
    /// L'utilisateur peut ensuite la désactiver (menu ou Réglages) : on ne la réactive plus.
    static func enableOnFirstLaunch() {
        let key = "didEnableLaunchAtLoginOnFirstLaunch"
        guard Bundle.main.bundleURL.pathExtension == "app",
              !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        try? setEnabled(true)
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
