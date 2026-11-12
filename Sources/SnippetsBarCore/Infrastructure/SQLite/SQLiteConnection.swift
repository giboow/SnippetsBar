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

enum SQLValue {
    case text(String), int(Int64), double(Double), null
}

/// Ligne courante d'un résultat de requête.
struct SQLiteRow {
    fileprivate let stmt: OpaquePointer

    func isNull(_ col: Int32) -> Bool { sqlite3_column_type(stmt, col) == SQLITE_NULL }
    func int64(_ col: Int32) -> Int64 { sqlite3_column_int64(stmt, col) }
    func double(_ col: Int32) -> Double { sqlite3_column_double(stmt, col) }

    func string(_ col: Int32) -> String {
        guard let c = sqlite3_column_text(stmt, col) else { return "" }
        return String(cString: c)
    }
}

/// Connexion SQLite minimale, ouverte pour la durée d'un bloc.
final class SQLiteConnection {
    private let db: OpaquePointer

    private init(_ db: OpaquePointer) { self.db = db }

    static func open<T>(_ url: URL, readOnly: Bool, _ body: (SQLiteConnection) throws -> T) throws -> T {
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
        return try body(SQLiteConnection(db))
    }

    func transaction(_ body: () throws -> Void) throws {
        try exec("BEGIN IMMEDIATE")
        do {
            try body()
            try exec("COMMIT")
        } catch {
            try? exec("ROLLBACK")
            throw error
        }
    }

    func exec(_ sql: String, _ args: [SQLValue] = []) throws {
        let stmt = try prepare(sql, args)
        defer { sqlite3_finalize(stmt) }
        let rc = sqlite3_step(stmt)
        guard rc == SQLITE_DONE || rc == SQLITE_ROW else {
            throw DBError.query(String(cString: sqlite3_errmsg(db)))
        }
    }

    func query(_ sql: String, _ args: [SQLValue] = [], row: (SQLiteRow) throws -> Void) throws {
        let stmt = try prepare(sql, args)
        defer { sqlite3_finalize(stmt) }
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_ROW { try row(SQLiteRow(stmt: stmt)) }
            else if rc == SQLITE_DONE { break }
            else { throw DBError.query(String(cString: sqlite3_errmsg(db))) }
        }
    }

    private func prepare(_ sql: String, _ args: [SQLValue]) throws -> OpaquePointer {
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
}
