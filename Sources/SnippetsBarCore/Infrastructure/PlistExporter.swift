import Foundation

/// Méthode « officielle » : génère un .plist à glisser dans
/// Réglages Système › Clavier › Remplacements de texte.
public enum PlistExporter {
    public static var defaultURL: URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Text Substitutions.plist")
    }

    public static func data(for snippets: [Snippet]) throws -> Data {
        let items = snippets.map { ["phrase": $0.phrase, "shortcut": $0.shortcut] }
        return try PropertyListSerialization.data(fromPropertyList: items, format: .xml, options: 0)
    }

    public static func export(_ snippets: [Snippet], to url: URL = defaultURL) throws {
        try data(for: snippets).write(to: url, options: .atomic)
    }
}
