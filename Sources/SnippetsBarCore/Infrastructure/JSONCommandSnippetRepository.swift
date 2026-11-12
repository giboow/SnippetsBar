import Foundation

/// Commandes enregistrées dans ~/Library/Application Support/SnippetsBar/commands.json.
public final class JSONCommandSnippetRepository: CommandSnippetRepository {
    public static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SnippetsBar/commands.json")
    }

    public let url: URL

    public init(url: URL = JSONCommandSnippetRepository.defaultURL) {
        self.url = url
    }

    public func fetchAll() throws -> [CommandSnippet] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([CommandSnippet].self, from: Data(contentsOf: url))
    }

    public func saveAll(_ commands: [CommandSnippet]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(commands).write(to: url, options: .atomic)
    }
}
