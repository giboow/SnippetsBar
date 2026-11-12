import AppKit
import Carbon.HIToolbox

/// Keyboard shortcut of the quick pick, saved in the user defaults.
struct HotKeyShortcut: Equatable {
    let keyCode: Int
    let modifiers: NSEvent.ModifierFlags
    /// Key as displayed, e.g. "V" or "Space".
    let key: String

    static let `default` = HotKeyShortcut(keyCode: kVK_ANSI_V, modifiers: [.control, .command], key: "V")

    init(keyCode: Int, modifiers: NSEvent.ModifierFlags, key: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection([.control, .option, .shift, .command])
        self.key = key
    }

    /// nil when the key press cannot be a global shortcut: it needs ⌘, ⌃ or ⌥.
    init?(event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.control, .option, .shift, .command])
        guard !modifiers.isDisjoint(with: [.control, .option, .command]) else { return nil }
        self.init(keyCode: Int(event.keyCode), modifiers: modifiers, key: Self.keyName(for: event))
    }

    /// Standard macOS notation, e.g. “⌃⌘V”.
    var label: String {
        var label = ""
        if modifiers.contains(.control) { label += "⌃" }
        if modifiers.contains(.option) { label += "⌥" }
        if modifiers.contains(.shift) { label += "⇧" }
        if modifiers.contains(.command) { label += "⌘" }
        return label + key
    }

    var carbonModifiers: Int {
        var flags = 0
        if modifiers.contains(.control) { flags |= controlKey }
        if modifiers.contains(.option) { flags |= optionKey }
        if modifiers.contains(.shift) { flags |= shiftKey }
        if modifiers.contains(.command) { flags |= cmdKey }
        return flags
    }

    private static let specialKeys: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]

    private static func keyName(for event: NSEvent) -> String {
        specialKeys[Int(event.keyCode)] ?? event.charactersIgnoringModifiers?.uppercased() ?? "?"
    }

    // MARK: Persistence

    private enum Keys {
        static let keyCode = "quickPickKeyCode", modifiers = "quickPickModifiers", key = "quickPickKey"
    }

    static func load(from defaults: UserDefaults = .standard) -> HotKeyShortcut {
        guard let key = defaults.string(forKey: Keys.key) else { return .default }
        return HotKeyShortcut(keyCode: defaults.integer(forKey: Keys.keyCode),
                              modifiers: NSEvent.ModifierFlags(rawValue: UInt(defaults.integer(forKey: Keys.modifiers))),
                              key: key)
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(keyCode, forKey: Keys.keyCode)
        defaults.set(Int(modifiers.rawValue), forKey: Keys.modifiers)
        defaults.set(key, forKey: Keys.key)
    }
}
