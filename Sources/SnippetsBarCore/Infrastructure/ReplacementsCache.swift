import Foundation

/// Copy of the text replacements that apps actually read.
public protocol ReplacementsCache {
    func update(with snippets: [Snippet])
}

/// macOS keeps a copy of the text replacements in the global preferences
/// (`NSUserDictionaryReplacementItems`), which Cocoa apps such as Mail read at launch.
/// keyboardservicesd does not refresh it when the database is modified directly,
/// so it is rewritten after every change.
public struct GlobalPreferencesReplacementsCache: ReplacementsCache {
    static let key = "NSUserDictionaryReplacementItems" as CFString

    public init() {}

    public func update(with snippets: [Snippet]) {
        CFPreferencesSetValue(Self.key, Self.items(for: snippets) as CFArray,
                              kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }

    /// Same format as the one written by macOS.
    static func items(for snippets: [Snippet]) -> [[String: Any]] {
        snippets.map { ["on": 1, "replace": $0.shortcut, "with": $0.phrase] }
    }
}
