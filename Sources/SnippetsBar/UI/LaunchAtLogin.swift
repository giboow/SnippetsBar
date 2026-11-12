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

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
