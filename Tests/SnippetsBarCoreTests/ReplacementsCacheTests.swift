import XCTest
@testable import SnippetsBarCore

/// Records updates instead of touching the real global preferences.
private final class SpyCache: ReplacementsCache {
    var updates: [[Snippet]] = []
    func update(with snippets: [Snippet]) { updates.append(snippets) }
}

final class ReplacementsCacheTests: XCTestCase {
    func testItemsUseTheMacOSFormat() {
        let items = GlobalPreferencesReplacementsCache.items(for: [Snippet(id: 1, shortcut: ";tel", phrase: "0123")])
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0]["replace"] as? String, ";tel")
        XCTAssertEqual(items[0]["with"] as? String, "0123")
        XCTAssertEqual(items[0]["on"] as? Int, 1)
    }
}

extension TextReplacementsRepositoryTests {
    private func repositoryWithSpy() -> (TextReplacementsRepository, SpyCache) {
        let spy = SpyCache()
        return (TextReplacementsRepository(url: repository.url, backupDirectory: repository.backupDirectory, cache: spy), spy)
    }

    func testEveryWriteRefreshesTheCache() throws {
        let (repo, spy) = repositoryWithSpy()
        try repo.insert(shortcut: ";a", phrase: "a")
        XCTAssertEqual(spy.updates.last?.map(\.shortcut), [";a", ";bj"])
        try repo.update(id: 1, shortcut: ";bjr", phrase: "Bonjour")
        XCTAssertEqual(spy.updates.last?.map(\.shortcut), [";a", ";bjr"])
        try repo.delete(id: 1)
        XCTAssertEqual(spy.updates.last?.map(\.shortcut), [";a"])
        try repo.apply(ImportPlan(importing: [SnippetDraft(shortcut: ";b", phrase: "b")], into: try repo.fetchAll()),
                       replacingConflicts: false)
        XCTAssertEqual(spy.updates.last?.map(\.shortcut), [";a", ";b"])
        XCTAssertEqual(spy.updates.count, 4)
    }

    func testRefreshCacheCopiesTheDatabase() {
        let (repo, spy) = repositoryWithSpy()
        repo.refreshCache()
        XCTAssertEqual(spy.updates.map { $0.map(\.shortcut) }, [[";bj"]])
    }

    func testFailedWriteDoesNotTouchTheCache() throws {
        let (repo, spy) = repositoryWithSpy()
        try FileManager.default.removeItem(at: repo.url)
        XCTAssertThrowsError(try repo.insert(shortcut: ";a", phrase: "a"))
        repo.refreshCache()
        XCTAssertTrue(spy.updates.isEmpty)
    }
}
