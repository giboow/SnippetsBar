import XCTest
@testable import SnippetsBarCore

final class ImportTests: XCTestCase {
    private let existing = [
        Snippet(id: 1, shortcut: ";sig", phrase: "Cordialement"),
        Snippet(id: 2, shortcut: "omw", phrase: "On my way!"),
    ]

    func testPlanSortsAdditionsConflictsAndDuplicates() {
        let plan = ImportPlan(importing: [
            SnippetDraft(shortcut: "omw", phrase: "On my way!"),        // doublon exact
            SnippetDraft(shortcut: ";sig", phrase: "Bien à vous"),      // conflit
            SnippetDraft(shortcut: " ;adr ", phrase: "1 rue de la Paix"), // ajout
            SnippetDraft(shortcut: ";adr", phrase: "Autre adresse"),    // répété dans le fichier
        ], into: existing)

        XCTAssertEqual(plan.additions, [SnippetDraft(shortcut: ";adr", phrase: "1 rue de la Paix")])
        XCTAssertEqual(plan.conflicts, [ImportConflict(snippet: existing[0], phrase: "Bien à vous")])
        XCTAssertEqual(plan.duplicateCount, 2)
        XCTAssertFalse(plan.isEmpty)
    }

    func testSummary() {
        let plan = ImportPlan(importing: [
            SnippetDraft(shortcut: "omw", phrase: "On my way!"),
            SnippetDraft(shortcut: ";sig", phrase: "Bien à vous"),
            SnippetDraft(shortcut: ";a", phrase: "a"),
            SnippetDraft(shortcut: ";b", phrase: "b"),
        ], into: existing)
        XCTAssertEqual(plan.summary(replacingConflicts: true), "2 importés, 1 remplacé, 1 ignoré")
        XCTAssertEqual(plan.summary(replacingConflicts: false), "2 importés, 2 ignorés")
    }

    func testNothingToImport() {
        let plan = ImportPlan(importing: [SnippetDraft(shortcut: "omw", phrase: "On my way!")], into: existing)
        XCTAssertTrue(plan.isEmpty)
        XCTAssertEqual(plan.summary(replacingConflicts: false), "0 importé, 1 ignoré")
    }

    func testPlistRoundTripAndInvalidEntries() throws {
        let exported = try PlistExporter.data(for: existing)
        XCTAssertEqual(try PlistImporter.drafts(from: exported), existing.map(SnippetDraft.init))

        let items: [[String: Any]] = [
            ["shortcut": ";ok", "phrase": "ok"],
            ["shortcut": ";vide", "phrase": ""],     // texte vide
            ["shortcut": "a b", "phrase": "espace"], // raccourci invalide
            ["phrase": "sans raccourci"],
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: items, format: .xml, options: 0)
        XCTAssertEqual(try PlistImporter.drafts(from: data), [SnippetDraft(shortcut: ";ok", phrase: "ok")])
    }

    func testInvalidFileThrows() throws {
        let dict = try PropertyListSerialization.data(fromPropertyList: ["a": 1], format: .xml, options: 0)
        XCTAssertThrowsError(try PlistImporter.drafts(from: dict))
        XCTAssertThrowsError(try PlistImporter.drafts(from: Data("pas un plist".utf8)))
    }
}

extension TextReplacementsRepositoryTests {
    func testApplyImportPlan() throws {
        // La base de test contient ;bj = « Bonjour ».
        let plan = ImportPlan(importing: [
            SnippetDraft(shortcut: ";bj", phrase: "Bonjour à tous"),
            SnippetDraft(shortcut: ";a", phrase: "a"),
            SnippetDraft(shortcut: ";b", phrase: "b"),
        ], into: try repository.fetchAll())

        try repository.apply(plan, replacingConflicts: false)
        XCTAssertEqual(try repository.fetchAll().map(\.shortcut), [";a", ";b", ";bj"])
        XCTAssertEqual(try repository.fetchAll().last?.phrase, "Bonjour")

        try repository.apply(ImportPlan(importing: [SnippetDraft(shortcut: ";bj", phrase: "Bonjour à tous")],
                                        into: try repository.fetchAll()),
                             replacingConflicts: true)
        XCTAssertEqual(try repository.fetchAll().last?.phrase, "Bonjour à tous")
        XCTAssertEqual(try repository.fetchAll().map(\.id), [2, 3, 1])
    }
}
