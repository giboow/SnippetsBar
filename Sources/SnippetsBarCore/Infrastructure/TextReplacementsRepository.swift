import Foundation

/// Direct access to ~/Library/KeyboardServices/TextReplacements.db,
/// the Core Data store macOS uses for text replacements.
public final class TextReplacementsRepository: SnippetRepository {
    public static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/KeyboardServices/TextReplacements.db")
    }

    public static var defaultBackupDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SnippetsBar/Backups", isDirectory: true)
    }

    private let table = "ZTEXTREPLACEMENTENTRY"
    public let url: URL
    public let backupDirectory: URL
    private let cache: ReplacementsCache?
    private var didBackup = false

    /// `cache` is the copy apps read (see GlobalPreferencesReplacementsCache); nil leaves it untouched.
    public init(url: URL = TextReplacementsRepository.defaultURL,
                backupDirectory: URL = TextReplacementsRepository.defaultBackupDirectory,
                cache: ReplacementsCache? = nil) {
        self.url = url
        self.backupDirectory = backupDirectory
        self.cache = cache
    }

    /// Rewrites the cache from the database, e.g. at launch to pick up entries
    /// written by earlier versions.
    public func refreshCache() {
        guard let cache, let snippets = try? fetchAll() else { return }
        cache.update(with: snippets)
    }

    // MARK: - Reading

    public func fetchAll() throws -> [Snippet] {
        try SQLiteConnection.open(url, readOnly: true) { db in
            let cols = try columns(db)
            let deletedFilter = cols.contains("ZWASDELETED")
                ? "WHERE ZWASDELETED IS NULL OR ZWASDELETED = 0" : ""
            let ts = cols.contains("ZTIMESTAMP") ? "ZTIMESTAMP" : "NULL"
            let sql = """
                SELECT Z_PK, ZSHORTCUT, ZPHRASE, \(ts) FROM \(table)
                \(deletedFilter)
                ORDER BY ZSHORTCUT COLLATE NOCASE
                """
            var result: [Snippet] = []
            try db.query(sql) { row in
                result.append(Snippet(
                    id: row.int64(0),
                    shortcut: row.string(1),
                    phrase: row.string(2),
                    modified: row.isNull(3) ? nil : Date(timeIntervalSinceReferenceDate: row.double(3))
                ))
            }
            return result
        }
    }

    // MARK: - Writing

    public func insert(shortcut: String, phrase: String) throws {
        try write { db in
            try insertRow(db, cols: try columns(db), shortcut: shortcut, phrase: phrase)
        }
    }

    public func update(id: Int64, shortcut: String, phrase: String) throws {
        try write { db in
            try touch(db, id: id, cols: try columns(db), setting: [("ZSHORTCUT", .text(shortcut)), ("ZPHRASE", .text(phrase))])
        }
    }

    public func apply(_ plan: ImportPlan, replacingConflicts: Bool) throws {
        try write { db in
            let cols = try columns(db)
            for draft in plan.additions {
                try insertRow(db, cols: cols, shortcut: draft.normalizedShortcut, phrase: draft.phrase)
            }
            guard replacingConflicts else { return }
            for conflict in plan.conflicts {
                try touch(db, id: conflict.snippet.id, cols: cols, setting: [("ZPHRASE", .text(conflict.phrase))])
            }
        }
    }

    private func insertRow(_ db: SQLiteConnection, cols: Set<String>, shortcut: String, phrase: String) throws {
        var ent: Int64 = 0, maxPK: Int64 = 0
        var found = false
        try db.query("SELECT Z_ENT, Z_MAX FROM Z_PRIMARYKEY WHERE Z_NAME = 'TextReplacementEntry'") { row in
            ent = row.int64(0)
            maxPK = row.int64(1)
            found = true
        }
        guard found else { throw DBError.schema("TextReplacementEntry entity missing from Z_PRIMARYKEY") }
        // Safety: never reuse an existing Z_PK.
        try db.query("SELECT IFNULL(MAX(Z_PK), 0) FROM \(table)") { row in
            maxPK = max(maxPK, row.int64(0))
        }
        let pk = maxPK + 1

        let candidates: [(String, SQLValue)] = [
            ("Z_PK", .int(pk)),
            ("Z_ENT", .int(ent)),
            ("Z_OPT", .int(1)),
            ("ZSHORTCUT", .text(shortcut)),
            ("ZPHRASE", .text(phrase)),
            ("ZTIMESTAMP", .double(Date().timeIntervalSinceReferenceDate)),
            ("ZUNIQUENAME", .text(UUID().uuidString)),
            ("ZNEEDSSAVETOCLOUD", .int(1)),
            ("ZWASDELETED", .int(0)),
        ]
        let values = candidates.filter { cols.contains($0.0) }
        let names = values.map(\.0).joined(separator: ", ")
        let marks = Array(repeating: "?", count: values.count).joined(separator: ", ")
        try db.exec("INSERT INTO \(table) (\(names)) VALUES (\(marks))", values.map(\.1))
        try db.exec("UPDATE Z_PRIMARYKEY SET Z_MAX = ? WHERE Z_ENT = ?", [.int(pk), .int(ent)])
    }

    /// “Soft” delete, as macOS does, so that iCloud sync
    /// propagates the deletion to other devices.
    public func delete(id: Int64) throws {
        try write { db in
            let cols = try columns(db)
            guard cols.contains("ZWASDELETED") else {
                try db.exec("DELETE FROM \(table) WHERE Z_PK = ?", [.int(id)])
                return
            }
            try touch(db, id: id, cols: cols, setting: [("ZWASDELETED", .int(1))])
        }
    }

    /// Consistent backup (VACUUM INTO) into `backupDirectory`.
    @discardableResult
    public func backup() throws -> URL {
        try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dest = backupDirectory.appendingPathComponent("TextReplacements_\(fmt.string(from: Date())).db")
        try SQLiteConnection.open(url, readOnly: true) { db in
            try db.exec("VACUUM INTO ?", [.text(dest.path)])
        }
        return dest
    }

    // MARK: - Core Data schema

    /// Automatic backup before the session's first write, then a transaction,
    /// then a refresh of the cache apps read.
    private func write(_ body: (SQLiteConnection) throws -> Void) throws {
        if !didBackup {
            try backup()
            didBackup = true
        }
        try SQLiteConnection.open(url, readOnly: false) { db in
            try db.transaction { try body(db) }
        }
        refreshCache()
    }

    /// UPDATE of one row, keeping the Core Data / iCloud metadata up to date.
    private func touch(_ db: SQLiteConnection, id: Int64, cols: Set<String>, setting sets: [(String, SQLValue)]) throws {
        var sets = sets
        if cols.contains("ZTIMESTAMP") { sets.append(("ZTIMESTAMP", .double(Date().timeIntervalSinceReferenceDate))) }
        if cols.contains("ZNEEDSSAVETOCLOUD") { sets.append(("ZNEEDSSAVETOCLOUD", .int(1))) }
        let clause = sets.map { "\($0.0) = ?" }.joined(separator: ", ")
        let opt = cols.contains("Z_OPT") ? ", Z_OPT = IFNULL(Z_OPT, 0) + 1" : ""
        try db.exec("UPDATE \(table) SET \(clause)\(opt) WHERE Z_PK = ?", sets.map(\.1) + [.int(id)])
    }

    private func columns(_ db: SQLiteConnection) throws -> Set<String> {
        var cols = Set<String>()
        try db.query("PRAGMA table_info(\(table))") { row in
            cols.insert(row.string(1))
        }
        guard cols.contains("ZSHORTCUT"), cols.contains("ZPHRASE") else {
            throw DBError.schema("missing ZSHORTCUT/ZPHRASE columns")
        }
        return cols
    }
}
