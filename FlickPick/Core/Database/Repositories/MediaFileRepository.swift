import Foundation
import GRDB

/// CRUD operations for media files.
struct MediaFileRepository {
    let db: DatabaseWriter

    init(db: DatabaseWriter = AppDatabase.shared.writer) {
        self.db = db
    }

    // MARK: - Write

    @discardableResult
    func upsert(_ record: MediaFileRecord) throws -> MediaFileRecord {
        try db.write { db in
            var record = record
            try record.save(db)
            return record
        }
    }

    func upsertBatch(_ records: [MediaFileRecord]) throws {
        try db.write { db in
            for var record in records {
                try record.save(db)
            }
        }
    }

    func updateDuration(id: Int64, duration: Double) throws {
        try db.write { db in
            try db.execute(
                sql: "UPDATE media_files SET durationSeconds = ? WHERE id = ?",
                arguments: [duration, id]
            )
        }
    }

    func updateThumbnail(id: Int64, path: String) throws {
        try db.write { db in
            try db.execute(
                sql: "UPDATE media_files SET thumbnailPath = ? WHERE id = ?",
                arguments: [path, id]
            )
        }
    }

    func setCollection(fileId: Int64, collectionId: Int64) throws {
        try db.write { db in
            try db.execute(
                sql: "UPDATE media_files SET collectionId = ? WHERE id = ?",
                arguments: [collectionId, fileId]
            )
        }
    }

    func delete(path: String) throws {
        try db.write { db in
            _ = try MediaFileRecord.filter(MediaFileRecord.Columns.path == path).deleteAll(db)
        }
    }

    // MARK: - Read

    func fetchByPath(_ path: String) throws -> MediaFileRecord? {
        try db.read { db in
            try MediaFileRecord.filter(MediaFileRecord.Columns.path == path).fetchOne(db)
        }
    }

    func fetchByFolder(_ folderPath: String) throws -> [MediaFileRecord] {
        try db.read { db in
            try MediaFileRecord
                .filter(MediaFileRecord.Columns.folderPath == folderPath)
                .order(MediaFileRecord.Columns.sequenceNum, MediaFileRecord.Columns.filename)
                .fetchAll(db)
        }
    }

    func fetchByCollection(_ collectionId: Int64) throws -> [MediaFileRecord] {
        try db.read { db in
            try MediaFileRecord
                .filter(MediaFileRecord.Columns.collectionId == collectionId)
                .order(MediaFileRecord.Columns.sequenceNum)
                .fetchAll(db)
        }
    }

    func fetchRecentlyAdded(limit: Int = 20) throws -> [MediaFileRecord] {
        try db.read { db in
            try MediaFileRecord
                .order(MediaFileRecord.Columns.indexedAt.desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    func fetchAll() throws -> [MediaFileRecord] {
        try db.read { db in
            try MediaFileRecord.fetchAll(db)
        }
    }

    func randomUnwatched() throws -> MediaFileRecord? {
        try db.read { db in
            let sql = """
                SELECT mf.* FROM media_files mf
                LEFT JOIN watch_history wh ON wh.mediaFileId = mf.id
                WHERE wh.completed IS NULL OR wh.completed = 0
                ORDER BY RANDOM()
                LIMIT 1
            """
            return try MediaFileRecord.fetchOne(db, sql: sql)
        }
    }
}
