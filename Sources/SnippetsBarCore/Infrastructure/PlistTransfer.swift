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

/// Lit un .plist au format des Réglages Système (celui produit par PlistExporter).
public enum PlistImporter {
    public static func drafts(from data: Data) throws -> [SnippetDraft] {
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        guard let items = plist as? [[String: Any]] else { throw DBError.schema("le fichier n'est pas une liste de remplacements de texte") }
        return items.compactMap { item in
            guard let shortcut = item["shortcut"] as? String, let phrase = item["phrase"] as? String else { return nil }
            let draft = SnippetDraft(shortcut: shortcut, phrase: phrase)
            return draft.isValid ? draft : nil
        }
    }

    public static func drafts(from url: URL) throws -> [SnippetDraft] {
        try drafts(from: Data(contentsOf: url))
    }
}
