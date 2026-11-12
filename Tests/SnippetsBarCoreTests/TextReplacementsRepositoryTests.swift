import XCTest
@testable import SnippetsBarCore

/// Tests sur une copie jetable reproduisant le schéma Core Data de macOS.
final class TextReplacementsRepositoryTests: XCTestCase {
    private var dir: URL!
    private var repo: TextReplacementsRepository!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("TextReplacements.db")
        FileManager.default.createFile(atPath: dbURL.path, contents: nil)
        try SQLiteConnection.open(dbURL, readOnly: false) { db in
            try db.exec("CREATE TABLE Z_PRIMARYKEY (Z_ENT INTEGER PRIMARY KEY, Z_NAME VARCHAR, Z_SUPER INTEGER, Z_MAX INTEGER)")
            try db.exec("INSERT INTO Z_PRIMARYKEY VALUES (1, 'TextReplacementEntry', 0, 1)")
            try db.exec("""
                CREATE TABLE ZTEXTREPLACEMENTENTRY (Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER,
                    ZNEEDSSAVETOCLOUD INTEGER, ZWASDELETED INTEGER, ZTIMESTAMP TIMESTAMP,
                    ZPHRASE VARCHAR, ZSHORTCUT VARCHAR, ZUNIQUENAME VARCHAR)
                """)
            try db.exec("INSERT INTO ZTEXTREPLACEMENTENTRY VALUES (1, 1, 1, 0, 0, 0, 'Bonjour', ';bj', 'u1')")
        }
        repo = TextReplacementsRepository(url: dbURL, backupDirectory: dir.appendingPathComponent("Backups"))
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: dir)
    }

    func testFetchAll() throws {
        let all = try repo.fetchAll()
        XCTAssertEqual(all.map(\.shortcut), [";bj"])
        XCTAssertEqual(all.first?.phrase, "Bonjour")
    }

    func testInsertUsesNextPrimaryKeyAndSortsByShortcut() throws {
        try repo.insert(shortcut: ";adr", phrase: "1 rue de la Paix")
        let all = try repo.fetchAll()
        XCTAssertEqual(all.map(\.shortcut), [";adr", ";bj"])
        XCTAssertEqual(all.first?.id, 2)
        try SQLiteConnection.open(repo.url, readOnly: true) { db in
            try db.query("SELECT Z_MAX FROM Z_PRIMARYKEY WHERE Z_ENT = 1") { XCTAssertEqual($0.int64(0), 2) }
        }
    }

    func testUpdateBumpsOptimisticLock() throws {
        try repo.update(id: 1, shortcut: ";bjr", phrase: "Bonjour !")
        XCTAssertEqual(try repo.fetchAll().first?.shortcut, ";bjr")
        try SQLiteConnection.open(repo.url, readOnly: true) { db in
            try db.query("SELECT Z_OPT, ZNEEDSSAVETOCLOUD FROM ZTEXTREPLACEMENTENTRY WHERE Z_PK = 1") {
                XCTAssertEqual($0.int64(0), 2)
                XCTAssertEqual($0.int64(1), 1)
            }
        }
    }

    func testDeleteIsSoft() throws {
        try repo.delete(id: 1)
        XCTAssertTrue(try repo.fetchAll().isEmpty)
        try SQLiteConnection.open(repo.url, readOnly: true) { db in
            try db.query("SELECT ZWASDELETED FROM ZTEXTREPLACEMENTENTRY WHERE Z_PK = 1") { XCTAssertEqual($0.int64(0), 1) }
        }
    }

    func testFirstWriteCreatesBackup() throws {
        try repo.insert(shortcut: ";a", phrase: "a")
        try repo.insert(shortcut: ";b", phrase: "b")
        let backups = try FileManager.default.contentsOfDirectory(atPath: repo.backupDirectory.path)
        XCTAssertEqual(backups.count, 1)
    }
}
