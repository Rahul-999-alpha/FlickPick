# FlickPick

A macOS-native media player with smart pattern-matching playlists and a Netflix-style home screen for local files.

**The gap it fills:** VLC/IINA are great players but have no library intelligence. Plex/Jellyfin require a server. FlickPick is a lightweight desktop app that auto-organizes your local media — open Harry Potter 2 and it finds HP 1-8, queues them in order, and remembers where you left off.

## Features (v0.1.0)

### Smart Engine
- **Auto-playlist building** — regex pattern matching detects series (S01E03, Episode 5, Part 2, Vol 1) and franchises (Harry Potter 2, Dune Part 1)
- **Fuzzy grouping** — files sharing >50% of their name are grouped together
- **Natural sort** — Episode 2 comes before Episode 10
- **Auto-advance** — finishes one episode, plays the next

### Netflix-Style Home Screen
- **Continue Watching** — resume from exact position (saved every 5s)
- **Up Next** — SmartEngine finds the next unwatched episode
- **Collections** — auto-detected franchises and series
- **Recently Added** — new files with badge
- **Surprise Me** — random unwatched picker

### Player
- **libmpv playback** — plays everything (MKV, MP4, AVI, etc.)
- **Metal/Vulkan rendering** — hardware-accelerated via MoltenVK
- **VideoToolbox decoding** — Apple Silicon native
- **Keyboard controls** — Space (play/pause), arrows (seek/volume), F (fullscreen), M (mute), P (playlist), [ ] (prev/next)
- **Fullscreen** — auto-hiding controls with gradient overlay
- **Playlist panel** — slide-in panel showing the smart playlist

### Library
- **Folder scanning** — recursive scan with 15 supported video formats
- **FSEvents watching** — live updates when files are added/removed (zero polling)
- **Thumbnail generation** — AVFoundation at 10% of duration, cached
- **SQLite database** — GRDB with reactive observation for live UI updates

### Other
- **Command Palette** — Cmd+K fuzzy search across your library
- **Onboarding** — first-launch folder picker with drag & drop
- **Settings** — manage watched folders, trigger rescans
- **Dark theme** — forced dark mode, near-black background

## Tech Stack

| Concern | Choice |
|---------|--------|
| Language | Swift 5 |
| UI | SwiftUI |
| Playback | libmpv via [MPVKit](https://github.com/mpvkit/MPVKit) |
| Rendering | Metal / Vulkan / MoltenVK |
| HW Decoding | VideoToolbox (Apple Silicon) |
| Database | [GRDB.swift](https://github.com/groue/GRDB.swift) + SQLite |
| File Watching | FSEvents (CoreServices) |
| Thumbnails | AVAssetImageGenerator |

**2 external dependencies.** Everything else is native Apple frameworks.

## Requirements

- macOS (Apple Silicon recommended)
- Xcode 16+

## Getting Started

```bash
git clone git@github.com:Rahul-999-alpha/FlickPick.git
cd FlickPick
open FlickPick.xcodeproj
```

In Xcode:
1. Wait for SPM to resolve packages (MPVKit-GPL + GRDB)
2. Ensure App Sandbox is **disabled** in Signing & Capabilities
3. Cmd+R to build and run

## Usage

- **Open a file:** Cmd+O or drag & drop a video onto the window
- **Smart playlist:** Just open any file — if it's part of a series, the playlist builds automatically
- **Add library folders:** Settings (gear icon) → Add Folder
- **Search:** Cmd+K to fuzzy search your library
- **Fullscreen:** Double-click the video or press F

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| Space | Play / Pause |
| ← → | Seek ±5s |
| ↑ ↓ | Volume ±5 |
| F | Toggle fullscreen |
| M | Toggle mute |
| P | Toggle playlist panel |
| [ ] | Previous / Next in playlist |
| Cmd+O | Open file |
| Cmd+K | Command palette |
| Cmd+, | Settings |

## Architecture

```
SwiftUI Views → ViewModels → Core Services → libmpv + macOS frameworks
```

- **MPVPlayer** — libmpv wrapper, Metal layer, event loop
- **SmartEngine** — 6 regex patterns + fuzzy grouping + natural sort
- **LibraryManager** — FSEvents, folder scanning, thumbnails
- **WatchHistory** — resume positions, On Deck, auto-complete
- **Database** — GRDB/SQLite with migrations and reactive observation

43 Swift files. See [CLAUDE.md](CLAUDE.md) for full implementation details.

## Known Issues

- Video doesn't resize with window (Metal layer frame update issue)
- No subtitle/audio track selection UI (mpv loads them, but no switcher yet)
- No file type associations registered

## Roadmap

**v0.x (current):** Fix known issues, add subtitle UI, file associations, app icon

**v1.0:** Volume normalization, seek thumbnail preview, smart filters, right-click context menu, scroll wheel volume

**v2.0:** Hover preview clips, skip intro detection, scene bookmarks, viewing stats

**v3.0:** Trakt.tv sync, TMDb metadata enrichment

## License

This project is not yet licensed. All rights reserved.
