import Foundation
import GRDB

/// A video file tracked by the library.
struct MediaFileRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var path: String
    var filename: String
    var folderPath: String
    var baseName: String?
    var sequenceNum: Double?
    var mediaType: String  // "movie", "episode", "standalone"
    var collectionId: Int64?
    var durationSeconds: Double?
    var fileSize: Int64?
    var thumbnailPath: String?
    var fileCreatedAt: Date?
    var indexedAt: Date

    static let databaseTableName = "media_files"

    // MARK: - Associations

    static let watchHistory = hasOne(WatchRecord.self, using: WatchRecord.mediaFileForeignKey)
    static let collection = belongsTo(CollectionRecord.self, using: ForeignKey(["collectionId"]))

    var watchHistory: QueryInterfaceRequest<WatchRecord> {
        request(for: MediaFileRecord.watchHistory)
    }
}

extension MediaFileRecord {
    /// Create from a URL and SmartEngine analysis.
    static func from(url: URL, analysis: AnalysisResult?) -> MediaFileRecord {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return MediaFileRecord(
            path: url.path,
            filename: url.lastPathComponent,
            folderPath: url.deletingLastPathComponent().path,
            baseName: analysis?.baseName,
            sequenceNum: analysis?.sequenceNumber,
            mediaType: analysis?.mediaType.rawValue ?? MediaType.standalone.rawValue,
            fileSize: attrs?[.size] as? Int64,
            fileCreatedAt: attrs?[.creationDate] as? Date,
            indexedAt: Date()
        )
    }
}

extension MediaFileRecord: TableRecord {
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let path = Column(CodingKeys.path)
        static let filename = Column(CodingKeys.filename)
        static let folderPath = Column(CodingKeys.folderPath)
        static let baseName = Column(CodingKeys.baseName)
        static let sequenceNum = Column(CodingKeys.sequenceNum)
        static let mediaType = Column(CodingKeys.mediaType)
        static let collectionId = Column(CodingKeys.collectionId)
        static let durationSeconds = Column(CodingKeys.durationSeconds)
        static let fileSize = Column(CodingKeys.fileSize)
        static let thumbnailPath = Column(CodingKeys.thumbnailPath)
        static let indexedAt = Column(CodingKeys.indexedAt)
    }
}
