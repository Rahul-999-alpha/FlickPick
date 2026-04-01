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
    /// Uses aliased columns to avoid id collision between joined tables.
    func fetchContinueWatching(limit: Int = 20) throws -> [(MediaFileRecord, WatchRecord)] {
        try db.read { db in
            // Fetch separately to avoid column name collision from JOIN
            let watchRecords = try WatchRecord
                .filter(WatchRecord.Columns.completed == false)
                .filter(WatchRecord.Columns.positionSeconds > 0)
                .order(WatchRecord.Columns.lastWatchedAt.desc)
                .limit(limit)
                .fetchAll(db)

            return try watchRecords.compactMap { wh in
                guard let mf = try MediaFileRecord.fetchOne(db, id: wh.mediaFileId) else {
                    return nil
                }
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
