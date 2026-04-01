import Foundation
import Combine
import AppKit
import Libmpv

/// Bridges MPVPlayer events into SwiftUI-friendly @Published state.
@MainActor
final class PlayerViewModel: ObservableObject {
    // MARK: - Published state

    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var volume: Double = 100
    @Published var isMuted = false
    @Published var isBuffering = false
    @Published var currentTitle = ""
    @Published var showControls = true
    @Published var isFullscreen = false
    @Published var eofReached = false
    @Published var isFileLoaded = false

    // Playlist
    @Published var playlist: [URL] = []
    @Published var currentIndex = 0
    @Published var playlistName = ""

    // MARK: - Player reference

    weak var player: MPVPlayer?
    var pendingFile: URL?

    // MARK: - Private

    private var controlsHideTask: Task<Void, Never>?
    private var previousVolume: Double = 100
    private let resumeManager = ResumeManager()
    private let watchHistory = WatchHistory()
    private var terminationObserver: Any?

    init() {
        // Save position on app quit
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.resumeManager.finalSaveAndStop()
        }
    }

    deinit {
        if let observer = terminationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        controlsHideTask?.cancel()
    }

    // MARK: - Smart open (with playlist building)

    func smartOpen(_ url: URL) {
        // Build smart playlist from sibling files
        if let playlistResult = CollectionBuilder.buildPlaylist(for: url) {
            playlist = playlistResult.files
            currentIndex = playlistResult.currentIndex
            playlistName = playlistResult.baseName
        } else {
            playlist = [url]
            currentIndex = 0
            playlistName = ""
        }

        loadCurrentFile()
    }

    /// Open from a MediaFileRecord (from Home screen)
    func openRecord(_ record: MediaFileRecord) {
        smartOpen(URL(fileURLWithPath: record.path))
    }

    func openFile(_ url: URL) {
        smartOpen(url)
    }

    // MARK: - Playback controls

    func togglePlayPause() {
        player?.togglePause()
    }

    func play() {
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    func seek(to seconds: Double) {
        player?.seek(to: seconds)
    }

    func seekRelative(_ seconds: Double) {
        player?.seekRelative(seconds)
    }

    func setVolume(_ vol: Double) {
        let clamped = min(max(vol, 0), 100)
        volume = clamped
        player?.setVolume(clamped)
    }

    func toggleMute() {
        if isMuted {
            volume = previousVolume
            player?.setVolume(previousVolume)
            isMuted = false
        } else {
            previousVolume = volume
            volume = 0
            player?.setVolume(0)
            isMuted = true
        }
    }

    func stop() {
        resumeManager.finalSaveAndStop()
        player?.stop()
        isPlaying = false
        isFileLoaded = false
        currentTime = 0
        duration = 0
    }

    // MARK: - Playlist navigation

    func playNext() {
        guard currentIndex + 1 < playlist.count else { return }
        currentIndex += 1
        loadCurrentFile()
    }

    func playPrevious() {
        guard currentIndex - 1 >= 0 else { return }
        currentIndex -= 1
        loadCurrentFile()
    }

    func playAtIndex(_ index: Int) {
        guard index >= 0, index < playlist.count else { return }
        currentIndex = index
        loadCurrentFile()
    }

    var hasNext: Bool { currentIndex + 1 < playlist.count }
    var hasPrevious: Bool { currentIndex > 0 }

    // MARK: - Controls auto-hide

    func resetControlsTimer() {
        showControls = true
        controlsHideTask?.cancel()
        guard isFullscreen else { return }
        controlsHideTask = Task {
            try? await Task.sleep(for: .seconds(2.5))
            if !Task.isCancelled { showControls = false }
        }
    }

    // MARK: - Formatted time helpers

    var currentTimeFormatted: String { formatTime(currentTime) }
    var durationFormatted: String { formatTime(duration) }
    var remainingTimeFormatted: String { formatTime(max(duration - currentTime, 0)) }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    // MARK: - Private

    private func loadCurrentFile() {
        guard currentIndex < playlist.count else { return }
        let url = playlist[currentIndex]
        pendingFile = url
        currentTitle = url.deletingPathExtension().lastPathComponent
        eofReached = false
        isFileLoaded = false

        player?.loadFile(url)
    }

    private func onFileLoaded() {
        guard let url = playlist[safe: currentIndex] else { return }

        isPlaying = true
        isFileLoaded = true
        eofReached = false

        // Resume from saved position
        let savedPos = resumeManager.getResumePosition(path: url.path)
        if let savedPos, savedPos > 5 {
            seek(to: savedPos)
        }

        // Start position tracking
        resumeManager.startTracking(path: url.path) { [weak self] in
            self?.currentTime ?? 0
        }

        // Index the file if not already
        let analysis = PatternMatcher.analyze(url.lastPathComponent)
        let record = MediaFileRecord.from(url: url, analysis: analysis)
        do { try MediaFileRepository().upsert(record) }
        catch { print("[FlickPick] Index failed: \(error)") }
    }

    private func onEndFile(reason: Int32) {
        resumeManager.finalSaveAndStop()

        guard let url = playlist[safe: currentIndex] else { return }

        // Only mark completed and auto-advance on natural EOF
        guard reason == MPV_END_FILE_REASON_EOF.rawValue else { return }

        watchHistory.markCompleted(path: url.path)

        if hasNext {
            playNext()
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - MPVPlayerDelegate

extension PlayerViewModel: MPVPlayerDelegate {
    func mpvPropertyChanged(_ name: String, value: Any) {
        switch name {
        case "time-pos":
            if let v = value as? Double {
                currentTime = v
                if duration > 0, let url = playlist[safe: currentIndex] {
                    resumeManager.checkAndMarkCompleted(path: url.path, position: v, duration: duration)
                }
            }
        case "duration":
            if let v = value as? Double {
                duration = v
                if let url = playlist[safe: currentIndex],
                   let file = try? MediaFileRepository().fetchByPath(url.path),
                   let fileId = file.id {
                    try? MediaFileRepository().updateDuration(id: fileId, duration: v)
                }
            }
        case "pause":
            if let v = value as? Bool { isPlaying = !v }
        case "eof-reached":
            if let v = value as? Bool { eofReached = v }
        case "volume":
            if let v = value as? Double { volume = v }
        case "paused-for-cache":
            if let v = value as? Bool { isBuffering = v }
        default:
            break
        }
    }

    func mpvFileLoaded() {
        onFileLoaded()
    }

    func mpvEndFile(reason: Int32) {
        onEndFile(reason: reason)
    }
}

// MARK: - Array safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
