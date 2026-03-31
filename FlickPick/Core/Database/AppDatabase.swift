import Foundation
import GRDB

/// Central database access. Creates schema, manages migrations, provides the writer.
final class AppDatabase {
    static let shared = AppDatabase()

    let writer: DatabaseWriter

    private init() {
        do {
            let folder = AppDatabase.databaseFolder()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let dbURL = folder.appendingPathComponent("flickpick.sqlite")
            var config = Configuration()
            config.prepareDatabase { db in
                db.trace { print("[SQL] \($0)") }
            }
            #if DEBUG
            // Verbose logging in debug
            #endif
            let pool = try DatabasePool(path: dbURL.path, configuration: config)
            writer = pool
            try migrator.migrate(pool)
        } catch {
            fatalError("[FlickPick] Database setup failed: \(error)")
        }
    }

    // MARK: - Migrations

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("v1") { db in
            try db.create(table: "collections") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("collectionType", .text).notNull()
                t.column("totalItems", .integer).notNull().defaults(to: 0)
                t.column("watchedItems", .integer).notNull().defaults(to: 0)
                t.column("thumbnailPath", .text)
                t.column("createdAt", .datetime).notNull()
            }

            try db.create(table: "media_files") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("path", .text).notNull().unique()
                t.column("filename", .text).notNull()
                t.column("folderPath", .text).notNull()
                t.column("baseName", .text)
                t.column("sequenceNum", .double)
                t.column("mediaType", .text).notNull()
                t.column("collectionId", .integer).references("collections", onDelete: .setNull)
                t.column("durationSeconds", .double)
                t.column("fileSize", .integer)
                t.column("thumbnailPath", .text)
                t.column("fileCreatedAt", .datetime)
                t.column("indexedAt", .datetime).notNull()
            }

            try db.create(table: "watch_history") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("mediaFileId", .integer).notNull()
                    .references("media_files", onDelete: .cascade)
                t.column("positionSeconds", .double).notNull().defaults(to: 0)
                t.column("completed", .boolean).notNull().defaults(to: false)
                t.column("lastWatchedAt", .datetime).notNull()
                t.column("watchCount", .integer).notNull().defaults(to: 0)
                t.uniqueKey(["mediaFileId"])
            }

            try db.create(table: "watched_folders") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("path", .text).notNull().unique()
                t.column("lastScannedAt", .datetime).notNull()
            }

            // Indexes
            try db.create(index: "idx_media_files_folder", on: "media_files", columns: ["folderPath"])
            try db.create(index: "idx_media_files_collection", on: "media_files", columns: ["collectionId"])
            try db.create(index: "idx_media_files_base_name", on: "media_files", columns: ["baseName"])
            try db.create(index: "idx_watch_history_last", on: "watch_history", columns: ["lastWatchedAt"])
        }

        return migrator
    }

    // MARK: - Database location

    private static func databaseFolder() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("FlickPick", isDirectory: true)
    }
}
