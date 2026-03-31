import SwiftUI
import UniformTypeIdentifiers

/// Main player view: video surface + transport controls + playlist panel.
struct PlayerView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @State private var isHovering = false
    @State private var isDraggingSeek = false
    @State private var showPlaylist = false

    var body: some View {
        HStack(spacing: 0) {
            // Video + controls
            ZStack {
                Color.black
                MPVVideoView(viewModel: viewModel)

                // Controls overlay
                if viewModel.showControls || !viewModel.isPlaying {
                    VStack {
                        // Top bar with title
                        if viewModel.isFullscreen {
                            HStack {
                                Text(viewModel.currentTitle)
                                    .font(.headline)
                                    .shadow(radius: 4)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }

                        Spacer()

                        controlsBar
                    }
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.showControls)
                }

                // Buffering
                if viewModel.isBuffering {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(.circular)
                }

                // Empty state
                if !viewModel.isFileLoaded && viewModel.playlist.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "play.rectangle")
                            .font(.system(size: 48))
                            .foregroundStyle(.quaternary)
                        Text("Open a file or drag & drop to play")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onHover { hovering in
                isHovering = hovering
                if hovering { viewModel.resetControlsTimer() }
            }
            .onTapGesture(count: 2) {
                toggleFullscreen()
            }
            .onTapGesture {
                viewModel.resetControlsTimer()
            }

            // Playlist panel
            if showPlaylist && viewModel.playlist.count > 1 {
                PlaylistPanel(viewModel: viewModel, isVisible: $showPlaylist)
                    .transition(.move(edge: .trailing))
            }
        }
        .background(Color.black)
        .focusable()
        .onKeyPress(.space) {
            viewModel.togglePlayPause()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            viewModel.seekRelative(-5)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            viewModel.seekRelative(5)
            return .handled
        }
        .onKeyPress(.upArrow) {
            viewModel.setVolume(viewModel.volume + 5)
            return .handled
        }
        .onKeyPress(.downArrow) {
            viewModel.setVolume(viewModel.volume - 5)
            return .handled
        }
        .onKeyPress("m") {
            viewModel.toggleMute()
            return .handled
        }
        .onKeyPress("f") {
            toggleFullscreen()
            return .handled
        }
        .onKeyPress("p") {
            withAnimation { showPlaylist.toggle() }
            return .handled
        }
        .onKeyPress(KeyEquivalent("[")) {
            viewModel.playPrevious()
            return .handled
        }
        .onKeyPress(KeyEquivalent("]")) {
            viewModel.playNext()
            return .handled
        }
    }

    // MARK: - Controls bar

    private var controlsBar: some View {
        VStack(spacing: 6) {
            seekBar

            HStack(spacing: 16) {
                // Time elapsed
                Text(viewModel.currentTimeFormatted)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                // Previous
                Button(action: viewModel.playPrevious) {
                    Image(systemName: "backward.fill")
                        .font(.title3)
                }
                .disabled(!viewModel.hasPrevious)
                .buttonStyle(.plain)

                // Play/Pause
                Button(action: viewModel.togglePlayPause) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)

                // Next
                Button(action: viewModel.playNext) {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                }
                .disabled(!viewModel.hasNext)
                .buttonStyle(.plain)

                Spacer()

                // Volume
                volumeControl

                // Playlist toggle
                if viewModel.playlist.count > 1 {
                    Button {
                        withAnimation { showPlaylist.toggle() }
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.title3)
                            .foregroundColor(showPlaylist ? .accentColor : .primary)
                    }
                    .buttonStyle(.plain)
                }

                // Fullscreen
                Button(action: toggleFullscreen) {
                    Image(systemName: viewModel.isFullscreen
                          ? "arrow.down.right.and.arrow.up.left"
                          : "arrow.up.left.and.arrow.down.right")
                        .font(.title3)
                }
                .buttonStyle(.plain)

                // Remaining time
                Text("-\(viewModel.remainingTimeFormatted)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Seek bar

    private var seekBar: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let progress = viewModel.duration > 0 ? viewModel.currentTime / viewModel.duration : 0

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: isDraggingSeek ? 6 : 4)

                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: max(0, width * progress), height: isDraggingSeek ? 6 : 4)
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDraggingSeek = true
                        let fraction = max(0, min(1, value.location.x / width))
                        viewModel.seek(to: fraction * viewModel.duration)
                    }
                    .onEnded { _ in
                        isDraggingSeek = false
                    }
            )
        }
        .frame(height: 12)
    }

    // MARK: - Volume

    private var volumeControl: some View {
        HStack(spacing: 4) {
            Button(action: viewModel.toggleMute) {
                Image(systemName: volumeIcon)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            Slider(value: Binding(
                get: { viewModel.volume },
                set: { viewModel.setVolume($0) }
            ), in: 0...100)
            .frame(width: 80)
        }
    }

    private var volumeIcon: String {
        if viewModel.isMuted || viewModel.volume == 0 {
            return "speaker.slash.fill"
        } else if viewModel.volume < 33 {
            return "speaker.wave.1.fill"
        } else if viewModel.volume < 66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }

    // MARK: - Actions

    private func toggleFullscreen() {
        guard let window = NSApplication.shared.keyWindow else { return }
        window.toggleFullScreen(nil)
        viewModel.isFullscreen.toggle()
        viewModel.resetControlsTimer()
    }
}
