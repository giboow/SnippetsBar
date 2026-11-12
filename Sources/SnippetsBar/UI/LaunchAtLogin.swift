import ServiceManagement

/// Launch at login (System Settings › General › Login Items).
/// Only works from the SnippetsBar.app bundle, not with `swift run`.
enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// The user disabled the item in System Settings: they must re-allow it themselves.
    static var requiresApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    /// Enables launch at login once, on the first launch of the installed app.
    /// The user can then turn it off (menu or System Settings): it is never re-enabled.
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
