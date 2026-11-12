import Foundation

/// Snippet dynamique : une commande shell dont la sortie est copiée.
/// Stocké par SnippetsBar, hors de la base des remplacements de texte (non synchronisé par iCloud).
public struct CommandSnippet: Identifiable, Hashable, Codable {
    public let id: UUID
    public var name: String
    public var command: String

    public init(id: UUID = UUID(), name: String, command: String) {
        self.id = id
        self.name = name
        self.command = command
    }
}

public extension Sequence where Element == CommandSnippet {
    /// Recherche insensible à la casse dans le nom et la commande.
    func filtered(by query: String) -> [CommandSnippet] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return Array(self) }
        return filter {
            $0.name.localizedCaseInsensitiveContains(q) || $0.command.localizedCaseInsensitiveContains(q)
        }
    }

    func sortedByName() -> [CommandSnippet] {
        sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

/// Saisie en cours d'une commande et ses règles de validation.
public struct CommandDraft: Equatable {
    public var name: String
    public var command: String

    public init(name: String = "", command: String = "") {
        self.name = name
        self.command = command
    }

    public init(_ snippet: CommandSnippet) {
        self.init(name: snippet.name, command: snippet.command)
    }

    public var normalizedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    public var normalizedCommand: String { command.trimmingCharacters(in: .whitespacesAndNewlines) }

    public var isValid: Bool { !normalizedName.isEmpty && !normalizedCommand.isEmpty }
}
