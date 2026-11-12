import XCTest
import SnippetsBarCore

final class DomainTests: XCTestCase {
    private let snippets = [
        Snippet(id: 1, shortcut: ";sig", phrase: "Cordialement, Philippe"),
        Snippet(id: 2, shortcut: ";adr", phrase: "1 rue de la Paix"),
    ]

    func testDraftNormalizesShortcut() {
        XCTAssertEqual(SnippetDraft(shortcut: "  ;sig\n", phrase: "x").normalizedShortcut, ";sig")
    }

    func testDraftValidity() {
        XCTAssertTrue(SnippetDraft(shortcut: ";sig", phrase: "x").isValid)
        XCTAssertFalse(SnippetDraft(shortcut: "   ", phrase: "x").isValid)
        XCTAssertFalse(SnippetDraft(shortcut: ";sig", phrase: "").isValid)
        XCTAssertFalse(SnippetDraft(shortcut: "; sig", phrase: "x").isValid)
        XCTAssertTrue(SnippetDraft(shortcut: "; sig", phrase: "x").shortcutHasWhitespace)
    }

    func testDuplicateIsDetectedButExcludesEditedSnippet() {
        let draft = SnippetDraft(shortcut: " ;sig ", phrase: "x")
        XCTAssertTrue(draft.isDuplicate(in: snippets, excluding: nil))
        XCTAssertFalse(draft.isDuplicate(in: snippets, excluding: 1))
        // Un doublon reste enregistrable.
        XCTAssertTrue(draft.isValid)
    }

    func testFilter() {
        XCTAssertEqual(snippets.filtered(by: "").count, 2)
        XCTAssertEqual(snippets.filtered(by: " SIG ").map(\.id), [1])
        XCTAssertEqual(snippets.filtered(by: "paix").map(\.id), [2])
        XCTAssertTrue(snippets.filtered(by: "zzz").isEmpty)
    }

    func testPlistExport() throws {
        let data = try PlistExporter.data(for: snippets)
        let items = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: String]])
        XCTAssertEqual(items, [
            ["shortcut": ";sig", "phrase": "Cordialement, Philippe"],
            ["shortcut": ";adr", "phrase": "1 rue de la Paix"],
        ])
    }
}
