import Foundation
import GRDB

/// Tracks watch progress for a media file.
struct WatchRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var mediaFileId: Int64
    var positionSeconds: Double
    var completed: Bool
    var lastWatchedAt: Date
    var watchCount: Int

    static let databaseTableName = "watch_history"

    static let mediaFileForeignKey = ForeignKey(["mediaFileId"])
    static let mediaFile = belongsTo(MediaFileRecord.self, using: mediaFileForeignKey)
}

extension WatchRecord: TableRecord {
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let mediaFileId = Column(CodingKeys.mediaFileId)
        static let positionSeconds = Column(CodingKeys.positionSeconds)
        static let completed = Column(CodingKeys.completed)
        static let lastWatchedAt = Column(CodingKeys.lastWatchedAt)
        static let watchCount = Column(CodingKeys.watchCount)
    }
}
