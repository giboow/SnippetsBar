import XCTest
@testable import SnippetsBarCore

final class ImportTests: XCTestCase {
    private let existing = [
        Snippet(id: 1, shortcut: ";sig", phrase: "Cordialement"),
        Snippet(id: 2, shortcut: "omw", phrase: "On my way!"),
    ]

    func testPlanSortsAdditionsConflictsAndDuplicates() {
        let plan = ImportPlan(importing: [
            SnippetDraft(shortcut: "omw", phrase: "On my way!"),        // exact duplicate
            SnippetDraft(shortcut: ";sig", phrase: "Bien à vous"),      // conflict
            SnippetDraft(shortcut: " ;adr ", phrase: "1 rue de la Paix"), // addition
            SnippetDraft(shortcut: ";adr", phrase: "Autre adresse"),    // repeated in the file
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
        XCTAssertEqual(plan.summary(replacingConflicts: true), "Imported: 2 · Replaced: 1 · Skipped: 1")
        XCTAssertEqual(plan.summary(replacingConflicts: false), "Imported: 2 · Skipped: 2")
    }

    func testNothingToImport() {
        let plan = ImportPlan(importing: [SnippetDraft(shortcut: "omw", phrase: "On my way!")], into: existing)
        XCTAssertTrue(plan.isEmpty)
        XCTAssertEqual(plan.summary(replacingConflicts: false), "Imported: 0 · Skipped: 1")
    }

    func testPlistRoundTripAndInvalidEntries() throws {
        let exported = try PlistExporter.data(for: existing)
        XCTAssertEqual(try PlistImporter.drafts(from: exported), existing.map(SnippetDraft.init))

        let items: [[String: Any]] = [
            ["shortcut": ";ok", "phrase": "ok"],
            ["shortcut": ";vide", "phrase": ""],     // empty text
            ["shortcut": "a b", "phrase": "espace"], // invalid shortcut
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
        // The test database contains ;bj = “Bonjour”.
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
