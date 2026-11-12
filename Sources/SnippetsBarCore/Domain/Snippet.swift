import Foundation

public struct Snippet: Identifiable, Hashable {
    public let id: Int64          // Z_PK in the Core Data store
    public var shortcut: String
    public var phrase: String
    public var modified: Date?

    public init(id: Int64, shortcut: String, phrase: String, modified: Date? = nil) {
        self.id = id
        self.shortcut = shortcut
        self.phrase = phrase
        self.modified = modified
    }
}

public extension Sequence where Element == Snippet {
    /// Case-insensitive search in the shortcut and the text.
    func filtered(by query: String) -> [Snippet] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return Array(self) }
        return filter {
            $0.shortcut.localizedCaseInsensitiveContains(q) || $0.phrase.localizedCaseInsensitiveContains(q)
        }
    }

    func containsShortcut(_ shortcut: String, excluding id: Int64?) -> Bool {
        contains { $0.shortcut == shortcut && $0.id != id }
    }
}
