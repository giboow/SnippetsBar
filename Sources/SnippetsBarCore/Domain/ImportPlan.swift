import Foundation

/// Raccourci importé déjà présent avec un texte différent.
public struct ImportConflict: Equatable {
    public let snippet: Snippet
    public let phrase: String
}

/// Tri des entrées d'un import : ajouts, conflits et doublons exacts (ignorés).
public struct ImportPlan: Equatable {
    public private(set) var additions: [SnippetDraft] = []
    public private(set) var conflicts: [ImportConflict] = []
    public private(set) var duplicateCount = 0

    public init(importing drafts: [SnippetDraft], into existing: [Snippet]) {
        var seen = Set<String>()
        for draft in drafts {
            let shortcut = draft.normalizedShortcut
            // Un même raccourci répété dans le fichier : seule la première occurrence compte.
            guard seen.insert(shortcut).inserted else {
                duplicateCount += 1
                continue
            }
            if let current = existing.first(where: { $0.shortcut == shortcut }) {
                if current.phrase == draft.phrase {
                    duplicateCount += 1
                } else {
                    conflicts.append(ImportConflict(snippet: current, phrase: draft.phrase))
                }
            } else {
                additions.append(SnippetDraft(shortcut: shortcut, phrase: draft.phrase))
            }
        }
    }

    public var isEmpty: Bool { additions.isEmpty && conflicts.isEmpty }

    /// Récapitulatif court, ex. « 5 importés, 3 remplacés, 2 ignorés ».
    public func summary(replacingConflicts: Bool) -> String {
        let ignored = duplicateCount + (replacingConflicts ? 0 : conflicts.count)
        var parts = ["\(additions.count) importé\(additions.count > 1 ? "s" : "")"]
        if replacingConflicts && !conflicts.isEmpty {
            parts.append("\(conflicts.count) remplacé\(conflicts.count > 1 ? "s" : "")")
        }
        if ignored > 0 { parts.append("\(ignored) ignoré\(ignored > 1 ? "s" : "")") }
        return parts.joined(separator: ", ")
    }
}
