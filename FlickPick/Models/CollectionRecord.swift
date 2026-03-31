import Foundation
import GRDB

/// A group of related media (franchise or series).
struct CollectionRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var name: String
    var collectionType: String  // "franchise", "series"
    var totalItems: Int
    var watchedItems: Int
    var thumbnailPath: String?
    var createdAt: Date

    static let databaseTableName = "collections"

    static let mediaFiles = hasMany(MediaFileRecord.self, using: ForeignKey(["collectionId"]))
}

extension CollectionRecord: TableRecord {
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let collectionType = Column(CodingKeys.collectionType)
        static let totalItems = Column(CodingKeys.totalItems)
        static let watchedItems = Column(CodingKeys.watchedItems)
        static let thumbnailPath = Column(CodingKeys.thumbnailPath)
        static let createdAt = Column(CodingKeys.createdAt)
    }
}
