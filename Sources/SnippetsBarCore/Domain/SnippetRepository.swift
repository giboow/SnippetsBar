import Foundation

/// Persistance des snippets.
public protocol SnippetRepository {
    func fetchAll() throws -> [Snippet]
    func insert(shortcut: String, phrase: String) throws
    func update(id: Int64, shortcut: String, phrase: String) throws
    func delete(id: Int64) throws
    /// Sauvegarde complète du stockage ; renvoie l'emplacement de la copie.
    @discardableResult
    func backup() throws -> URL
}
