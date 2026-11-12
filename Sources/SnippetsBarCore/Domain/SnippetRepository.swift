import Foundation

/// Snippet persistence.
public protocol SnippetRepository {
    func fetchAll() throws -> [Snippet]
    func insert(shortcut: String, phrase: String) throws
    func update(id: Int64, shortcut: String, phrase: String) throws
    func delete(id: Int64) throws
    /// Applies an import in a single transaction; conflicts are replaced only when requested.
    func apply(_ plan: ImportPlan, replacingConflicts: Bool) throws
    /// Full backup of the store; returns the location of the copy.
    @discardableResult
    func backup() throws -> URL
}
