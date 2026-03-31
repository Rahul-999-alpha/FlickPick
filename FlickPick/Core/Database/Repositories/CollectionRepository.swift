import Foundation
import GRDB

/// CRUD operations for collections (franchises/series).
struct CollectionRepository {
    let db: DatabaseWriter

    init(db: DatabaseWriter = AppDatabase.shared.writer) {
        self.db = db
    }

    // MARK: - Write

    @discardableResult
    func findOrCreate(name: String, type: String) throws -> CollectionRecord {
        try db.write { db in
            if let existing = try CollectionRecord
                .filter(CollectionRecord.Columns.name == name)
                .fetchOne(db)
            {
                return existing
            }

            var record = CollectionRecord(
                name: name,
                collectionType: type,
                totalItems: 0,
                watchedItems: 0,
                createdAt: Date()
            )
            try record.insert(db)
            return record
        }
    }

    func updateCounts(id: Int64) throws {
        try db.write { db in
            let totalSQL = "SELECT COUNT(*) FROM media_files WHERE collectionId = ?"
            let watchedSQL = """
                SELECT COUNT(*) FROM media_files mf
                INNER JOIN watch_history wh ON wh.mediaFileId = mf.id
                WHERE mf.collectionId = ? AND wh.completed = 1
            """
            let total = try Int.fetchOne(db, sql: totalSQL, arguments: [id]) ?? 0
            let watched = try Int.fetchOne(db, sql: watchedSQL, arguments: [id]) ?? 0

            try db.execute(
                sql: "UPDATE collections SET totalItems = ?, watchedItems = ? WHERE id = ?",
                arguments: [total, watched, id]
            )
        }
    }

    func delete(id: Int64) throws {
        try db.write { db in
            _ = try CollectionRecord.deleteOne(db, id: id)
        }
    }

    // MARK: - Read

    func fetchAll() throws -> [CollectionRecord] {
        try db.read { db in
            try CollectionRecord
                .order(CollectionRecord.Columns.name)
                .fetchAll(db)
        }
    }

    func fetchByName(_ name: String) throws -> CollectionRecord? {
        try db.read { db in
            try CollectionRecord
                .filter(CollectionRecord.Columns.name == name)
                .fetchOne(db)
        }
    }

    func fetchWithFiles() throws -> [(CollectionRecord, [MediaFileRecord])] {
        try db.read { db in
            let collections = try CollectionRecord.fetchAll(db)
            return try collections.map { collection in
                let files = try MediaFileRecord
                    .filter(MediaFileRecord.Columns.collectionId == collection.id)
                    .order(MediaFileRecord.Columns.sequenceNum)
                    .fetchAll(db)
                return (collection, files)
            }
        }
    }
}
