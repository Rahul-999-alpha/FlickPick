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

                // Scroll wheel captures for volume
                ScrollWheelView { delta in
                    viewModel.setVolume(viewModel.volume + delta * 3)
                }

                // Controls overlay
                if viewModel.showControls || !viewModel.isPlaying {
                    VStack(spacing: 0) {
                        // Top title bar (fullscreen only)
                        if viewModel.isFullscreen {
                            HStack {
                                Text(viewModel.currentTitle)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(FP.textPrimary)
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
                            .foregroundStyle(FP.textSecondary.opacity(0.3))
                        Text("Open a file or drag & drop to play")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(FP.textSecondary)
                    }
                }
            }
            .contextMenu { playerContextMenu }
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
        .onKeyPress("j") {
            viewModel.decreaseSpeed()
            return .handled
        }
        .onKeyPress("l") {
            viewModel.increaseSpeed()
            return .handled
        }
        .onKeyPress("v") {
            viewModel.cycleSubtitleTrack()
            return .handled
        }
    }

    // MARK: - Context menu

    @ViewBuilder
    private var playerContextMenu: some View {
        // Subtitle tracks
        if !viewModel.subtitleTracks.isEmpty {
            Menu("Subtitles") {
                Button("None") { viewModel.setSubtitleTrack(0) }
                Divider()
                ForEach(viewModel.subtitleTracks) { track in
                    Button {
                        viewModel.setSubtitleTrack(track.id)
                    } label: {
                        let check = track.id == viewModel.currentSubtitleTrackId ? "  ✓" : ""
                        Text("\(track.displayName)\(check)")
                    }
                }
            }
        }

        // Audio tracks
        if !viewModel.audioTracks.isEmpty {
            Menu("Audio") {
                ForEach(viewModel.audioTracks) { track in
                    Button {
                        viewModel.setAudioTrack(track.id)
                    } label: {
                        let check = track.id == viewModel.currentAudioTrackId ? "  ✓" : ""
                        Text("\(track.displayName)\(check)")
                    }
                }
            }
        }

        // Speed
        Menu("Speed") {
            ForEach(PlayerViewModel.availableSpeeds, id: \.self) { speed in
                Button {
                    viewModel.setSpeed(speed)
                } label: {
                    let check = abs(viewModel.playbackSpeed - speed) < 0.01 ? "  ✓" : ""
                    Text("\(speed, specifier: "%.2g")x\(check)")
                }
            }
        }

        Divider()

        Button(viewModel.isFullscreen ? "Exit Fullscreen" : "Fullscreen") {
            toggleFullscreen()
        }
    }

    // MARK: - Controls bar

    private var controlsBar: some View {
        VStack(spacing: 4) {
            // Seek bar (full width)
            seekBar

            // Transport controls
            HStack(spacing: 0) {
                // Time elapsed
                Text(viewModel.currentTimeFormatted)
                    .font(FP.monoFont)
                    .foregroundStyle(FP.textSecondary)
                    .frame(width: 60, alignment: .leading)

                // Speed indicator (if not 1x)
                if abs(viewModel.playbackSpeed - 1.0) > 0.01 {
                    Text("\(viewModel.playbackSpeed, specifier: "%.2g")x")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(FP.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(FP.accentGlow, in: RoundedRectangle(cornerRadius: 4))
                }

                Spacer()

                // Transport buttons
                HStack(spacing: 20) {
                    Button(action: viewModel.playPrevious) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 14))
                    }
                    .disabled(!viewModel.hasPrevious)
                    .buttonStyle(.plain)
                    .foregroundStyle(viewModel.hasPrevious ? FP.textPrimary : FP.textSecondary.opacity(0.3))

                    Button(action: viewModel.togglePlayPause) {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(FP.textPrimary)

                    Button(action: viewModel.playNext) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 14))
                    }
                    .disabled(!viewModel.hasNext)
                    .buttonStyle(.plain)
                    .foregroundStyle(viewModel.hasNext ? FP.textPrimary : FP.textSecondary.opacity(0.3))
                }

                Spacer()

                // Right side controls
                HStack(spacing: 14) {
                    // Volume
                    volumeControl

                    // Subtitles indicator
                    if !viewModel.subtitleTracks.isEmpty {
                        Image(systemName: "captions.bubble")
                            .font(.system(size: 13))
                            .foregroundStyle(viewModel.currentSubtitleTrackId > 0 ? FP.accent : FP.textSecondary)
                    }

                    // Playlist toggle
                    if viewModel.playlist.count > 1 {
                        Button {
                            withAnimation { showPlaylist.toggle() }
                        } label: {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 13))
                                .foregroundColor(showPlaylist ? FP.accent : FP.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }

                    // Fullscreen
                    Button(action: toggleFullscreen) {
                        Image(systemName: viewModel.isFullscreen
                              ? "arrow.down.right.and.arrow.up.left"
                              : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 13))
                            .foregroundStyle(FP.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                // Remaining time
                Text("-\(viewModel.remainingTimeFormatted)")
                    .font(FP.monoFont)
                    .foregroundStyle(FP.textSecondary)
                    .frame(width: 60, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
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
                // Track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.15))
                    .frame(height: isDraggingSeek ? 6 : 4)

                // Fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(FP.accent)
                    .frame(width: max(0, width * min(progress, 1)), height: isDraggingSeek ? 6 : 4)
            }
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
            .animation(.easeOut(duration: 0.1), value: isDraggingSeek)
        }
        .frame(height: 14)
    }

    // MARK: - Volume

    private var volumeControl: some View {
        HStack(spacing: 4) {
            Button(action: viewModel.toggleMute) {
                Image(systemName: volumeIcon)
                    .font(.system(size: 13))
                    .foregroundStyle(FP.textSecondary)
            }
            .buttonStyle(.plain)

            Slider(value: Binding(
                get: { viewModel.volume },
                set: { viewModel.setVolume($0) }
            ), in: 0...100)
            .frame(width: 70)
            .tint(FP.accent)
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
        // State sync handled by WindowManager's NSWindow notification observers
        viewModel.resetControlsTimer()
    }
}
