import Foundation

/// Persistance des commandes.
public protocol CommandSnippetRepository {
    func fetchAll() throws -> [CommandSnippet]
    func saveAll(_ commands: [CommandSnippet]) throws
}
