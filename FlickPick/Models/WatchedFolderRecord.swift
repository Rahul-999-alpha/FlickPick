import Foundation
import GRDB

/// A folder the user has added to the library.
struct WatchedFolderRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var path: String
    var lastScannedAt: Date

    static let databaseTableName = "watched_folders"
}

extension WatchedFolderRecord: TableRecord {
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let path = Column(CodingKeys.path)
        static let lastScannedAt = Column(CodingKeys.lastScannedAt)
    }
}
