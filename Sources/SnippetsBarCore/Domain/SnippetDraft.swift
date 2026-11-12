import Foundation

/// Snippet being edited (new or existing) and its validation rules.
public struct SnippetDraft: Equatable {
    public var shortcut: String
    public var phrase: String

    public init(shortcut: String = "", phrase: String = "") {
        self.shortcut = shortcut
        self.phrase = phrase
    }

    public init(_ snippet: Snippet) {
        self.init(shortcut: snippet.shortcut, phrase: snippet.phrase)
    }

    /// Shortcut as it will be saved.
    public var normalizedShortcut: String {
        shortcut.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var shortcutHasWhitespace: Bool {
        normalizedShortcut.contains(where: \.isWhitespace)
    }

    /// A duplicate is only a warning: it does not prevent saving.
    public var isValid: Bool {
        !normalizedShortcut.isEmpty && !phrase.isEmpty && !shortcutHasWhitespace
    }

    public func isDuplicate(in snippets: [Snippet], excluding id: Int64?) -> Bool {
        snippets.containsShortcut(normalizedShortcut, excluding: id)
    }
}
