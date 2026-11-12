import Foundation

/// Saisie en cours d'un snippet (création ou modification) et ses règles de validation.
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

    /// Raccourci tel qu'il sera enregistré.
    public var normalizedShortcut: String {
        shortcut.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var shortcutHasWhitespace: Bool {
        normalizedShortcut.contains(where: \.isWhitespace)
    }

    /// Un doublon n'est qu'un avertissement : il ne bloque pas l'enregistrement.
    public var isValid: Bool {
        !normalizedShortcut.isEmpty && !phrase.isEmpty && !shortcutHasWhitespace
    }

    public func isDuplicate(in snippets: [Snippet], excluding id: Int64?) -> Bool {
        snippets.containsShortcut(normalizedShortcut, excluding: id)
    }
}
