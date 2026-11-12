import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum DBError: LocalizedError {
    case open(String)
    case query(String)
    case schema(String)

    var errorDescription: String? {
        switch self {
        case .open(let m):   return "Impossible d'ouvrir la base : \(m)"
        case .query(let m):  return "Erreur SQLite : \(m)"
        case .schema(let m): return "Format de base inattendu : \(m)"
        }
    }
}

private enum SQLValue {
    case text(String), int(Int64), double(Double), null
}

/// Accès direct à ~/Library/KeyboardServices/TextReplacements.db,
/// la base Core Data utilisée par macOS pour les remplacements de texte.
final class TextReplacementsDB {
    static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/KeyboardServices/TextReplacements.db")
    }

    private let table = "ZTEXTREPLACEMENTENTRY"
    let url: URL
    private var didBackup = false

    init(url: URL = TextReplacementsDB.defaultURL) {
        self.url = url
    }

    // MARK: - Lecture

    func fetchAll() throws -> [Snippet] {
        try withDB(readOnly: true) { db in
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
            try query(db, sql) { stmt in
                let date: Date? = sqlite3_column_type(stmt, 3) == SQLITE_NULL
                    ? nil
                    : Date(timeIntervalSinceReferenceDate: sqlite3_column_double(stmt, 3))
                result.append(Snippet(
                    id: sqlite3_column_int64(stmt, 0),
                    shortcut: Self.string(stmt, 1),
                    phrase: Self.string(stmt, 2),
                    modified: date
                ))
            }
            return result
        }
    }

    // MARK: - Écriture

    func insert(shortcut: String, phrase: String) throws {
        try write { db in
            let cols = try columns(db)
            var ent: Int64 = 0, maxPK: Int64 = 0
            var found = false
            try query(db, "SELECT Z_ENT, Z_MAX FROM Z_PRIMARYKEY WHERE Z_NAME = 'TextReplacementEntry'") { stmt in
                ent = sqlite3_column_int64(stmt, 0)
                maxPK = sqlite3_column_int64(stmt, 1)
                found = true
            }
            guard found else { throw DBError.schema("entité TextReplacementEntry absente de Z_PRIMARYKEY") }
            // Sécurité : ne jamais réutiliser un Z_PK existant.
            try query(db, "SELECT IFNULL(MAX(Z_PK), 0) FROM \(table)") { stmt in
                maxPK = max(maxPK, sqlite3_column_int64(stmt, 0))
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
            try exec(db, "INSERT INTO \(table) (\(names)) VALUES (\(marks))", values.map(\.1))
            try exec(db, "UPDATE Z_PRIMARYKEY SET Z_MAX = ? WHERE Z_ENT = ?", [.int(pk), .int(ent)])
        }
    }

    func update(id: Int64, shortcut: String, phrase: String) throws {
        try write { db in
            let cols = try columns(db)
            var sets: [(String, SQLValue)] = [("ZSHORTCUT", .text(shortcut)), ("ZPHRASE", .text(phrase))]
            if cols.contains("ZTIMESTAMP") { sets.append(("ZTIMESTAMP", .double(Date().timeIntervalSinceReferenceDate))) }
            if cols.contains("ZNEEDSSAVETOCLOUD") { sets.append(("ZNEEDSSAVETOCLOUD", .int(1))) }
            let clause = sets.map { "\($0.0) = ?" }.joined(separator: ", ")
            let opt = cols.contains("Z_OPT") ? ", Z_OPT = IFNULL(Z_OPT, 0) + 1" : ""
            try exec(db, "UPDATE \(table) SET \(clause)\(opt) WHERE Z_PK = ?", sets.map(\.1) + [.int(id)])
        }
    }

    /// Suppression « douce », comme le fait macOS, pour que la synchro iCloud
    /// propage la suppression aux autres appareils.
    func delete(id: Int64) throws {
        try write { db in
            let cols = try columns(db)
            guard cols.contains("ZWASDELETED") else {
                try exec(db, "DELETE FROM \(table) WHERE Z_PK = ?", [.int(id)])
                return
            }
            var sets: [(String, SQLValue)] = [("ZWASDELETED", .int(1))]
            if cols.contains("ZTIMESTAMP") { sets.append(("ZTIMESTAMP", .double(Date().timeIntervalSinceReferenceDate))) }
            if cols.contains("ZNEEDSSAVETOCLOUD") { sets.append(("ZNEEDSSAVETOCLOUD", .int(1))) }
            let clause = sets.map { "\($0.0) = ?" }.joined(separator: ", ")
            let opt = cols.contains("Z_OPT") ? ", Z_OPT = IFNULL(Z_OPT, 0) + 1" : ""
            try exec(db, "UPDATE \(table) SET \(clause)\(opt) WHERE Z_PK = ?", sets.map(\.1) + [.int(id)])
        }
    }

    /// Sauvegarde cohérente (VACUUM INTO) dans ~/Library/Application Support/SnippetsBar/Backups.
    @discardableResult
    func backup() throws -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SnippetsBar/Backups", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dest = dir.appendingPathComponent("TextReplacements_\(fmt.string(from: Date())).db")
        try withDB(readOnly: true) { db in
            try exec(db, "VACUUM INTO ?", [.text(dest.path)])
        }
        return dest
    }

    // MARK: - Plomberie SQLite

    private func write(_ body: (OpaquePointer) throws -> Void) throws {
        if !didBackup {
            try backup()
            didBackup = true
        }
        try withDB(readOnly: false) { db in
            try exec(db, "BEGIN IMMEDIATE")
            do {
                try body(db)
                try exec(db, "COMMIT")
            } catch {
                try? exec(db, "ROLLBACK")
                throw error
            }
        }
    }

    private func withDB<T>(readOnly: Bool, _ body: (OpaquePointer) throws -> T) throws -> T {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw DBError.open("fichier introuvable (\(url.path))")
        }
        var handle: OpaquePointer?
        let flags = readOnly ? SQLITE_OPEN_READONLY : SQLITE_OPEN_READWRITE
        let rc = sqlite3_open_v2(url.path, &handle, flags, nil)
        guard rc == SQLITE_OK, let db = handle else {
            let msg = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "code \(rc)"
            sqlite3_close(handle)
            throw DBError.open(msg)
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 3000)
        return try body(db)
    }

    private func columns(_ db: OpaquePointer) throws -> Set<String> {
        var cols = Set<String>()
        try query(db, "PRAGMA table_info(\(table))") { stmt in
            cols.insert(Self.string(stmt, 1))
        }
        guard cols.contains("ZSHORTCUT"), cols.contains("ZPHRASE") else {
            throw DBError.schema("colonnes ZSHORTCUT/ZPHRASE absentes")
        }
        return cols
    }

    private func prepare(_ db: OpaquePointer, _ sql: String, _ args: [SQLValue]) throws -> OpaquePointer {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw DBError.query(String(cString: sqlite3_errmsg(db)))
        }
        for (i, arg) in args.enumerated() {
            let idx = Int32(i + 1)
            switch arg {
            case .text(let s):   sqlite3_bind_text(stmt, idx, s, -1, SQLITE_TRANSIENT)
            case .int(let n):    sqlite3_bind_int64(stmt, idx, n)
            case .double(let d): sqlite3_bind_double(stmt, idx, d)
            case .null:          sqlite3_bind_null(stmt, idx)
            }
        }
        return stmt
    }

    private func exec(_ db: OpaquePointer, _ sql: String, _ args: [SQLValue] = []) throws {
        let stmt = try prepare(db, sql, args)
        defer { sqlite3_finalize(stmt) }
        let rc = sqlite3_step(stmt)
        guard rc == SQLITE_DONE || rc == SQLITE_ROW else {
            throw DBError.query(String(cString: sqlite3_errmsg(db)))
        }
    }

    private func query(_ db: OpaquePointer, _ sql: String, _ args: [SQLValue] = [],
                       row: (OpaquePointer) throws -> Void) throws {
        let stmt = try prepare(db, sql, args)
        defer { sqlite3_finalize(stmt) }
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_ROW { try row(stmt) }
            else if rc == SQLITE_DONE { break }
            else { throw DBError.query(String(cString: sqlite3_errmsg(db))) }
        }
    }

    private static func string(_ stmt: OpaquePointer, _ col: Int32) -> String {
        guard let c = sqlite3_column_text(stmt, col) else { return "" }
        return String(cString: c)
    }
}
