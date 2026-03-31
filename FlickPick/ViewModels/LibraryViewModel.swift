import Foundation
import Combine
import GRDB

/// Drives the Home screen with reactive data from GRDB.
@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var continueWatching: [(MediaFileRecord, WatchRecord)] = []
    @Published var upNext: [MediaFileRecord] = []
    @Published var recentlyAdded: [MediaFileRecord] = []
    @Published var collections: [CollectionRecord] = []
    @Published var hasWatchedFolders = false

    private let onDeck = OnDeckEngine()
    private let mediaRepo = MediaFileRepository()
    private let collectionRepo = CollectionRepository()
    private let watchRepo = WatchRepository()
    private var cancellables = Set<AnyCancellable>()

    init() {
        startObserving()
    }

    func refresh() {
        loadData()
    }

    func surpriseMe() -> MediaFileRecord? {
        try? onDeck.surpriseMe()
    }

    // MARK: - Private

    private func startObserving() {
        // Observe media_files table changes
        ValueObservation.tracking { db in
            try MediaFileRecord
                .order(MediaFileRecord.Columns.indexedAt.desc)
                .limit(20)
                .fetchAll(db)
        }
        .publisher(in: AppDatabase.shared.writer, scheduling: .immediate)
        .sink(
            receiveCompletion: { _ in },
            receiveValue: { [weak self] files in
                self?.recentlyAdded = files
            }
        )
        .store(in: &cancellables)

        // Observe collections
        ValueObservation.tracking { db in
            try CollectionRecord
                .order(CollectionRecord.Columns.name)
                .fetchAll(db)
        }
        .publisher(in: AppDatabase.shared.writer, scheduling: .immediate)
        .sink(
            receiveCompletion: { _ in },
            receiveValue: { [weak self] cols in
                self?.collections = cols
            }
        )
        .store(in: &cancellables)

        // Observe watched folders
        ValueObservation.tracking { db in
            try WatchedFolderRecord.fetchCount(db)
        }
        .publisher(in: AppDatabase.shared.writer, scheduling: .immediate)
        .sink(
            receiveCompletion: { _ in },
            receiveValue: { [weak self] count in
                self?.hasWatchedFolders = count > 0
            }
        )
        .store(in: &cancellables)

        // Observe watch history for continue watching / up next
        ValueObservation.tracking { db in
            try WatchRecord.fetchCount(db)
        }
        .publisher(in: AppDatabase.shared.writer, scheduling: .immediate)
        .sink(
            receiveCompletion: { _ in },
            receiveValue: { [weak self] _ in
                self?.loadWatchData()
            }
        )
        .store(in: &cancellables)
    }

    private func loadData() {
        loadWatchData()
    }

    private func loadWatchData() {
        do {
            continueWatching = try onDeck.continueWatching()
            upNext = try onDeck.upNext()
        } catch {
            print("[FlickPick] Failed to load watch data: \(error)")
        }
    }
}
