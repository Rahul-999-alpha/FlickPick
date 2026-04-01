import AppKit
import SwiftUI
import Combine

/// Manages the player window lifecycle. Library window is SwiftUI-managed;
/// player window is created programmatically as a separate NSWindow.
@MainActor
final class WindowManager: ObservableObject {
    static let shared = WindowManager()

    let playerVM = PlayerViewModel()
    @Published var isPlayerWindowOpen = false

    private var playerWindow: NSWindow?
    private var fullscreenObservers: [Any] = []

    private init() {}

    // MARK: - Open player

    func openPlayer(with url: URL) {
        playerVM.openFile(url)
        showPlayerWindow()
    }

    func openPlayer(with record: MediaFileRecord) {
        playerVM.openRecord(record)
        showPlayerWindow()
    }

    // MARK: - Window management

    private func showPlayerWindow() {
        if let existing = playerWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let playerView = PlayerView(viewModel: playerVM)
            .preferredColorScheme(.dark)

        let hostingView = NSHostingView(rootView: playerView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 540),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.title = playerVM.currentTitle.isEmpty ? "FlickPick" : playerVM.currentTitle
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .black
        window.minSize = NSSize(width: 480, height: 270)
        window.isReleasedWhenClosed = false
        window.center()

        // Observe window close
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window, queue: .main
        ) { [weak self] _ in
            self?.isPlayerWindowOpen = false
        }

        // Observe fullscreen for viewModel sync
        let enterObs = NotificationCenter.default.addObserver(
            forName: NSWindow.didEnterFullScreenNotification,
            object: window, queue: .main
        ) { [weak self] _ in
            self?.playerVM.isFullscreen = true
        }
        let exitObs = NotificationCenter.default.addObserver(
            forName: NSWindow.didExitFullScreenNotification,
            object: window, queue: .main
        ) { [weak self] _ in
            self?.playerVM.isFullscreen = false
        }
        fullscreenObservers = [enterObs, exitObs]

        window.makeKeyAndOrderFront(nil)
        playerWindow = window
        isPlayerWindowOpen = true
    }

    func closePlayer() {
        playerWindow?.close()
        playerWindow = nil
        isPlayerWindowOpen = false
    }

    /// Update the player window title when the track changes.
    func updateTitle(_ title: String) {
        playerWindow?.title = title
    }
}
