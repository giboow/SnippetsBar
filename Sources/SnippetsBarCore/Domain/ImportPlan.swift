import Foundation

/// Imported shortcut that already exists with a different text.
public struct ImportConflict: Equatable {
    public let snippet: Snippet
    public let phrase: String
}

/// Sorting of imported entries: additions, conflicts and exact duplicates (skipped).
public struct ImportPlan: Equatable {
    public private(set) var additions: [SnippetDraft] = []
    public private(set) var conflicts: [ImportConflict] = []
    public private(set) var duplicateCount = 0

    public init(importing drafts: [SnippetDraft], into existing: [Snippet]) {
        var seen = Set<String>()
        for draft in drafts {
            let shortcut = draft.normalizedShortcut
            // Same shortcut repeated in the file: only the first occurrence counts.
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

    /// Short summary, e.g. “Imported: 5 · Replaced: 3 · Skipped: 2”.
    public func summary(replacingConflicts: Bool) -> String {
        let ignored = duplicateCount + (replacingConflicts ? 0 : conflicts.count)
        var parts = [String(localized: "Imported: \(additions.count)")]
        if replacingConflicts && !conflicts.isEmpty {
            parts.append(String(localized: "Replaced: \(conflicts.count)"))
        }
        if ignored > 0 { parts.append(String(localized: "Skipped: \(ignored)")) }
        return parts.joined(separator: " · ")
    }
}
