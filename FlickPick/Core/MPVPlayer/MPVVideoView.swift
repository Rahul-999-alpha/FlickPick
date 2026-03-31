import SwiftUI

/// Bridges MPVPlayer (NSViewController) into SwiftUI.
struct MPVVideoView: NSViewControllerRepresentable {
    let viewModel: PlayerViewModel

    func makeNSViewController(context: Context) -> MPVPlayer {
        let player = MPVPlayer()
        player.delegate = viewModel
        player.fileToLoad = viewModel.pendingFile
        viewModel.player = player
        return player
    }

    func updateNSViewController(_ nsViewController: MPVPlayer, context: Context) {
        // Updates handled via ViewModel -> player direct calls
    }
}
