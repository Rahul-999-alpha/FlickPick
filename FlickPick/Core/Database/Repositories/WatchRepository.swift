import Foundation
import GRDB

/// CRUD operations for watch history.
struct WatchRepository {
    let db: DatabaseWriter

    init(db: DatabaseWriter = AppDatabase.shared.writer) {
        self.db = db
    }

    // MARK: - Write

    func savePosition(mediaFileId: Int64, position: Double) throws {
        try db.write { db in
            if var existing = try WatchRecord
                .filter(WatchRecord.Columns.mediaFileId == mediaFileId)
                .fetchOne(db)
            {
                existing.positionSeconds = position
                existing.lastWatchedAt = Date()
                try existing.update(db)
            } else {
                var record = WatchRecord(
                    mediaFileId: mediaFileId,
                    positionSeconds: position,
                    completed: false,
                    lastWatchedAt: Date(),
                    watchCount: 1
                )
                try record.insert(db)
            }
        }
    }

    func markCompleted(mediaFileId: Int64) throws {
        try db.write { db in
            if var existing = try WatchRecord
                .filter(WatchRecord.Columns.mediaFileId == mediaFileId)
                .fetchOne(db)
            {
                existing.completed = true
                existing.watchCount += 1
                existing.lastWatchedAt = Date()
                try existing.update(db)
            } else {
                var record = WatchRecord(
                    mediaFileId: mediaFileId,
                    positionSeconds: 0,
                    completed: true,
                    lastWatchedAt: Date(),
                    watchCount: 1
                )
                try record.insert(db)
            }
        }
    }

    func markUncompleted(mediaFileId: Int64) throws {
        try db.write { db in
            if var existing = try WatchRecord
                .filter(WatchRecord.Columns.mediaFileId == mediaFileId)
                .fetchOne(db)
            {
                existing.completed = false
                try existing.update(db)
            }
        }
    }

    // MARK: - Read

    func getPosition(mediaFileId: Int64) throws -> Double? {
        try db.read { db in
            try WatchRecord
                .filter(WatchRecord.Columns.mediaFileId == mediaFileId)
                .fetchOne(db)?
                .positionSeconds
        }
    }

    func isCompleted(mediaFileId: Int64) throws -> Bool {
        try db.read { db in
            try WatchRecord
                .filter(WatchRecord.Columns.mediaFileId == mediaFileId)
                .fetchOne(db)?
                .completed ?? false
        }
    }

    /// Items currently in progress (position > 0, not completed), ordered by most recent.
    func fetchContinueWatching(limit: Int = 20) throws -> [(MediaFileRecord, WatchRecord)] {
        try db.read { db in
            let sql = """
                SELECT mf.*, wh.*
                FROM media_files mf
                INNER JOIN watch_history wh ON wh.mediaFileId = mf.id
                WHERE wh.completed = 0 AND wh.positionSeconds > 0
                ORDER BY wh.lastWatchedAt DESC
                LIMIT ?
            """
            let rows = try Row.fetchAll(db, sql: sql, arguments: [limit])
            return try rows.map { row in
                let mf = try MediaFileRecord(row: row)
                let wh = try WatchRecord(row: row)
                return (mf, wh)
            }
        }
    }

    func fetchAll() throws -> [WatchRecord] {
        try db.read { db in
            try WatchRecord.fetchAll(db)
        }
    }
}
