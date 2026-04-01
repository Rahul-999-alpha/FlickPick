import Foundation
import GRDB

/// Central database access. Creates schema, manages migrations, provides the writer.
final class AppDatabase {
    static let shared = AppDatabase()

    let writer: DatabaseWriter

    private init() {
        writer = AppDatabase.createWriter()
    }

    private static func createWriter() -> DatabaseWriter {
        let folder = databaseFolder()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let dbURL = folder.appendingPathComponent("flickpick.sqlite")

        // First attempt
        if let pool = try? openPool(at: dbURL) {
            return pool
        }

        // Recovery: delete corrupted DB and retry
        print("[FlickPick] Database corrupted, recreating...")
        try? FileManager.default.removeItem(at: dbURL)
        if let pool = try? openPool(at: dbURL) {
            return pool
        }

        fatalError("[FlickPick] Database setup failed even after recovery")
    }

    private static func openPool(at url: URL) throws -> DatabasePool {
        var config = Configuration()
        #if DEBUG
        config.prepareDatabase { db in
            db.trace { print("[SQL] \($0)") }
        }
        #endif
        let pool = try DatabasePool(path: url.path, configuration: config)
        try AppDatabase.shared_migrator.migrate(pool)
        return pool
    }

    // Migrator as a static to allow use before init completes
    private static let shared_migrator = makeMigrator()

    // MARK: - Migrations

    private static func makeMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        // IMPORTANT: Never modify this block after shipping. Add new migrations below.
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
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            // Fallback to temp directory
            return FileManager.default.temporaryDirectory.appendingPathComponent("FlickPick", isDirectory: true)
        }
        return appSupport.appendingPathComponent("FlickPick", isDirectory: true)
    }
}
