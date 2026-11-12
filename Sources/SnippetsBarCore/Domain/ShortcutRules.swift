import Carbon.HIToolbox

/// Key combination, independent of AppKit (key codes are Carbon virtual key codes).
public struct KeyCombo: Hashable {
    public let keyCode: Int
    public let command: Bool
    public let option: Bool
    public let control: Bool
    public let shift: Bool

    public init(keyCode: Int, command: Bool = false, option: Bool = false, control: Bool = false, shift: Bool = false) {
        self.keyCode = keyCode
        self.command = command
        self.option = option
        self.control = control
        self.shift = shift
    }
}

/// Rules that keep a global shortcut away from app commands and typing.
public enum ShortcutRules {
    public enum Problem: Equatable {
        /// ⌘X or ⇧⌘X are app commands, ⌥X types characters, ⌃X drives terminals and text fields.
        case tooFewModifiers
        /// A two-modifier combination that many apps use.
        case commonInApps
    }

    public static func problem(with combo: KeyCombo) -> Problem? {
        let modifiers = [combo.command, combo.option, combo.control].filter { $0 }.count
        if modifiers < 2 { return .tooFewModifiers }
        if commonInApps.contains(combo) { return .commonInApps }
        return nil
    }

    private static func cmdOpt(_ key: Int, shift: Bool = false) -> KeyCombo {
        KeyCombo(keyCode: key, command: true, option: true, shift: shift)
    }

    private static func cmdCtrl(_ key: Int) -> KeyCombo {
        KeyCombo(keyCode: key, command: true, control: true)
    }

    static let commonInApps: Set<KeyCombo> = [
        cmdCtrl(kVK_ANSI_F),            // Enter Full Screen
        cmdCtrl(kVK_ANSI_Q),            // Lock Screen
        cmdCtrl(kVK_ANSI_D),            // Look Up
        cmdCtrl(kVK_ANSI_N),            // Finder: New Folder with Selection
        cmdOpt(kVK_ANSI_V),             // Finder: Move Item Here; paste variants
        cmdOpt(kVK_ANSI_V, shift: true), // Paste and Match Style
        cmdOpt(kVK_ANSI_C),             // Copy Style
        cmdOpt(kVK_ANSI_H),             // Hide Others
        cmdOpt(kVK_ANSI_M),             // Minimize All
        cmdOpt(kVK_ANSI_W),             // Close All
        cmdOpt(kVK_ANSI_I),             // Browser developer tools, Inspector
        cmdOpt(kVK_ANSI_J),             // Browser JavaScript console
        cmdOpt(kVK_ANSI_U),             // View Source
        cmdOpt(kVK_ANSI_S),             // Show Sidebar
        cmdOpt(kVK_ANSI_T),             // Show Toolbar
        cmdOpt(kVK_ANSI_L),             // Downloads
        cmdOpt(kVK_ANSI_F),             // Search field
        cmdOpt(kVK_ANSI_P),             // Finder: Show Path Bar
        cmdOpt(kVK_ANSI_D),             // Show/Hide Dock
        cmdOpt(kVK_Escape),             // Force Quit
    ]
}
