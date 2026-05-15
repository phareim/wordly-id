import Foundation
import CSQLite

/// One page of items from a kind's `/titles` endpoint.
public struct TitlesPage<Item: ReferenceItem>: Sendable {
    public let cursor: Int64
    public let items: [Item]

    public init(cursor: Int64, items: [Item]) {
        self.cursor = cursor
        self.items = items
    }
}

/// Pluggable transport so tests can stub network calls.
public protocol TitleMirrorTransport: Sendable {
    func fetchPage<K: ReferenceKind>(kind: K.Type, since: Int64, limit: Int) async throws -> TitlesPage<K.Item>
}

/// SQLITE_TRANSIENT — tells sqlite3 to copy the bound bytes immediately.
/// The C macro isn't surfaced via the module import, so we reconstruct it from the
/// well-known `-1` sentinel.
private let SQLITE_TRANSIENT = unsafeBitCast(OpaquePointer(bitPattern: -1)!, to: sqlite3_destructor_type.self)

/// Local SQLite-backed mirror of one or more kinds' title indexes.
public actor TitleMirror {
    private let kinds: [AnyReferenceKind]
    private let transport: TitleMirrorTransport
    // `nonisolated(unsafe)` so the synchronous, nonisolated deinit may call sqlite3_close
    // on it. All other access goes through the actor, so no real race window exists.
    private nonisolated(unsafe) var db: OpaquePointer?
    private static let pageLimit: Int = 200

    public init(kinds: [AnyReferenceKind], storage: URL, transport: TitleMirrorTransport) async throws {
        self.kinds = kinds
        self.transport = transport
        try openDB(at: storage)
        try createSchema()
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    private func openDB(at url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        var handle: OpaquePointer?
        guard sqlite3_open(url.path, &handle) == SQLITE_OK else {
            let reason = String(cString: sqlite3_errmsg(handle))
            sqlite3_close(handle)
            throw TitleMirrorError.openFailed(reason: reason)
        }
        self.db = handle
    }

    private func createSchema() throws {
        for kind in kinds {
            let table = Self.tableName(for: kind)
            let createSQL = """
            CREATE TABLE IF NOT EXISTS \(table) (
              wordly_id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              mtime INTEGER NOT NULL,
              deleted INTEGER NOT NULL DEFAULT 0,
              status_glyph TEXT,
              raw_json BLOB NOT NULL
            );
            """
            try exec(createSQL)
            try exec("CREATE INDEX IF NOT EXISTS idx_\(table)_title ON \(table)(title);")
            try exec("CREATE INDEX IF NOT EXISTS idx_\(table)_mtime ON \(table)(mtime DESC);")
        }
        try exec("""
        CREATE TABLE IF NOT EXISTS cursors (
          kind_prefix TEXT PRIMARY KEY,
          cursor INTEGER NOT NULL DEFAULT 0
        );
        """)
    }

    private func exec(_ sql: String) throws {
        var err: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
            let message = err.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(err)
            throw TitleMirrorError.sqlite(message: message, sql: sql)
        }
    }

    private static func tableName(for kind: AnyReferenceKind) -> String {
        "titles_" + kind.prefix.lowercased()
    }

    public func cursor(for kind: AnyReferenceKind) -> Int64 {
        guard let db else { return 0 }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, "SELECT cursor FROM cursors WHERE kind_prefix = ?", -1, &stmt, nil) == SQLITE_OK else { return 0 }
        sqlite3_bind_text(stmt, 1, kind.prefix, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return sqlite3_column_int64(stmt, 0)
    }

    public func count(kind: AnyReferenceKind) -> Int {
        guard let db else { return 0 }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        let table = Self.tableName(for: kind)
        guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM \(table) WHERE deleted = 0", -1, &stmt, nil) == SQLITE_OK else { return 0 }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    public func refresh<K: ReferenceKind>(kind kindType: K.Type) async throws {
        let anyKind = AnyReferenceKind(kindType)
        var cursor = self.cursor(for: anyKind)
        while true {
            let page = try await transport.fetchPage(kind: kindType, since: cursor, limit: Self.pageLimit)
            try apply(page: page, kind: anyKind)
            if page.items.isEmpty { break }
            if page.cursor <= cursor { break }
            cursor = page.cursor
        }
    }

    public struct Hit: Sendable, Hashable {
        public let wordlyID: String
        public let title: String
        public let mtime: Int64
        public let statusGlyph: String?
    }

    public func search(query: String, kind: AnyReferenceKind, limit: Int) -> [Hit] {
        guard let db else { return [] }
        let table = Self.tableName(for: kind)
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        var hits: [Hit] = []
        if q.isEmpty {
            let sql = "SELECT wordly_id, title, mtime, status_glyph FROM \(table) WHERE deleted = 0 ORDER BY mtime DESC LIMIT ?"
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            sqlite3_bind_int(stmt, 1, Int32(limit))
            while sqlite3_step(stmt) == SQLITE_ROW {
                hits.append(rowToHit(stmt!))
            }
            return hits
        }

        let prefixSQL = "SELECT wordly_id, title, mtime, status_glyph FROM \(table) WHERE deleted = 0 AND LOWER(title) LIKE ? ORDER BY mtime DESC LIMIT ?"
        var prefixStmt: OpaquePointer?
        defer { sqlite3_finalize(prefixStmt) }
        guard sqlite3_prepare_v2(db, prefixSQL, -1, &prefixStmt, nil) == SQLITE_OK else { return [] }
        sqlite3_bind_text(prefixStmt, 1, "\(q)%", -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(prefixStmt, 2, Int32(limit))
        while sqlite3_step(prefixStmt) == SQLITE_ROW {
            hits.append(rowToHit(prefixStmt!))
        }
        if !hits.isEmpty { return hits }

        let remaining = limit
        let knownIDs = Set(hits.map(\.wordlyID))
        let substringSQL = "SELECT wordly_id, title, mtime, status_glyph FROM \(table) WHERE deleted = 0 AND LOWER(title) LIKE ? ORDER BY mtime DESC LIMIT ?"
        var subStmt: OpaquePointer?
        defer { sqlite3_finalize(subStmt) }
        guard sqlite3_prepare_v2(db, substringSQL, -1, &subStmt, nil) == SQLITE_OK else { return hits }
        sqlite3_bind_text(subStmt, 1, "%\(q)%", -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(subStmt, 2, Int32(remaining))
        while sqlite3_step(subStmt) == SQLITE_ROW {
            let hit = rowToHit(subStmt!)
            if !knownIDs.contains(hit.wordlyID) {
                hits.append(hit)
                if hits.count >= limit { break }
            }
        }
        return hits
    }

    public func resolve(_ wordlyID: String, kind: AnyReferenceKind) -> Hit? {
        guard let db else { return nil }
        let table = Self.tableName(for: kind)
        let sql = "SELECT wordly_id, title, mtime, status_glyph FROM \(table) WHERE wordly_id = ?"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        sqlite3_bind_text(stmt, 1, wordlyID, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return rowToHit(stmt!)
    }

    private func rowToHit(_ stmt: OpaquePointer) -> Hit {
        let wordlyID = String(cString: sqlite3_column_text(stmt, 0))
        let title = String(cString: sqlite3_column_text(stmt, 1))
        let mtime = sqlite3_column_int64(stmt, 2)
        let glyph: String?
        if let cstr = sqlite3_column_text(stmt, 3) {
            glyph = String(cString: cstr)
        } else {
            glyph = nil
        }
        return Hit(wordlyID: wordlyID, title: title, mtime: mtime, statusGlyph: glyph)
    }

    private func apply<Item: ReferenceItem>(page: TitlesPage<Item>, kind: AnyReferenceKind) throws {
        let table = Self.tableName(for: kind)
        let encoder = JSONEncoder()
        // Encode everything BEFORE opening the transaction so an encoder throw
        // doesn't leave SQLite in a half-open BEGIN state.
        let encodedItems: [(item: Item, raw: Data)] = try page.items.map { item in
            (item, try encoder.encode(item))
        }
        try exec("BEGIN")
        for (item, raw) in encodedItems {
            if item.deleted {
                var stmt: OpaquePointer?
                defer { sqlite3_finalize(stmt) }
                guard sqlite3_prepare_v2(db, "DELETE FROM \(table) WHERE wordly_id = ?", -1, &stmt, nil) == SQLITE_OK else {
                    try exec("ROLLBACK")
                    throw TitleMirrorError.sqlite(message: String(cString: sqlite3_errmsg(db)), sql: "DELETE")
                }
                sqlite3_bind_text(stmt, 1, item.wordlyID, -1, SQLITE_TRANSIENT)
                if sqlite3_step(stmt) != SQLITE_DONE {
                    try exec("ROLLBACK")
                    throw TitleMirrorError.sqlite(message: String(cString: sqlite3_errmsg(db)), sql: "DELETE step")
                }
            } else {
                let sql = """
                INSERT INTO \(table) (wordly_id, title, mtime, deleted, status_glyph, raw_json)
                VALUES (?, ?, ?, 0, ?, ?)
                ON CONFLICT(wordly_id) DO UPDATE SET
                  title = excluded.title,
                  mtime = excluded.mtime,
                  deleted = excluded.deleted,
                  status_glyph = excluded.status_glyph,
                  raw_json = excluded.raw_json;
                """
                var stmt: OpaquePointer?
                defer { sqlite3_finalize(stmt) }
                guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                    try exec("ROLLBACK")
                    throw TitleMirrorError.sqlite(message: String(cString: sqlite3_errmsg(db)), sql: "UPSERT prepare")
                }
                sqlite3_bind_text(stmt, 1, item.wordlyID, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 2, item.title, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int64(stmt, 3, item.mtime)
                if let glyph = item.statusGlyph {
                    sqlite3_bind_text(stmt, 4, glyph, -1, SQLITE_TRANSIENT)
                } else {
                    sqlite3_bind_null(stmt, 4)
                }
                _ = raw.withUnsafeBytes { bytes in
                    sqlite3_bind_blob(stmt, 5, bytes.baseAddress, Int32(bytes.count), SQLITE_TRANSIENT)
                }
                if sqlite3_step(stmt) != SQLITE_DONE {
                    try exec("ROLLBACK")
                    throw TitleMirrorError.sqlite(message: String(cString: sqlite3_errmsg(db)), sql: "UPSERT step")
                }
            }
        }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, "INSERT INTO cursors (kind_prefix, cursor) VALUES (?, ?) ON CONFLICT(kind_prefix) DO UPDATE SET cursor = excluded.cursor", -1, &stmt, nil) == SQLITE_OK else {
            try exec("ROLLBACK")
            throw TitleMirrorError.sqlite(message: String(cString: sqlite3_errmsg(db)), sql: "cursor upsert prepare")
        }
        sqlite3_bind_text(stmt, 1, kind.prefix, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(stmt, 2, page.cursor)
        if sqlite3_step(stmt) != SQLITE_DONE {
            try exec("ROLLBACK")
            throw TitleMirrorError.sqlite(message: String(cString: sqlite3_errmsg(db)), sql: "cursor upsert step")
        }
        try exec("COMMIT")
    }
}

public enum TitleMirrorError: Error {
    case openFailed(reason: String)
    case sqlite(message: String, sql: String)
}
