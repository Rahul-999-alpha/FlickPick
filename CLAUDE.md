# FlickPick — CLAUDE.md

## What is FlickPick?

FlickPick is a macOS-native media player built on **Swift + SwiftUI + libmpv**. Its core differentiators:

1. **Smart pattern-matching engine** — auto-builds playlists from filenames (like PotPlayer on Windows). Open Harry Potter 2 → it finds HP 1-8, queues them in order.
2. **Netflix-style home screen** — Continue Watching, Up Next, Collections, Recently Added — all for local files.
3. **No server required** — unlike Plex/Jellyfin, it's a lightweight desktop app.

**Target:** macOS only, Apple Silicon native (M-series chips).

---

## Tech Stack

| Concern | Choice |
|---------|--------|
| Language | Swift 6 |
| UI | SwiftUI |
| Playback | libmpv via MPVKit (SPM) |
| Video Rendering | NSViewRepresentable + CAMetalLayer + mpv Metal render API |
| Database | GRDB.swift + SQLite |
| File Watching | FSEvents (CoreServices) |
| Thumbnails | AVAssetImageGenerator + mpv fallback |
| Package Manager | Swift Package Manager |

### SPM Dependencies

| Package | URL | Purpose |
|---------|-----|---------|
| MPVKit | `https://github.com/mpvkit/MPVKit` | Pre-built libmpv xcframework |
| GRDB.swift | `https://github.com/groue/GRDB.swift` | SQLite with reactive observation |

---

## Architecture Overview

```
SwiftUI Views (Home, Player, Collection, CommandPalette, Settings)
       |
ViewModels (LibraryViewModel, PlayerViewModel, SettingsViewModel)
       |
Core Services:
  - MPVPlayer     — libmpv wrapper, Metal rendering, event loop
  - SmartEngine   — filename pattern matching, fuzzy grouping, natural sort
  - LibraryManager — FSEvents file watching, thumbnail gen, indexing
  - WatchHistory  — resume positions, On Deck logic, watched state
  - Database      — GRDB/SQLite, schema, repositories
       |
libmpv (xcframework) + macOS frameworks (Metal, AVFoundation, CoreServices)
```

See `ARCHITECTURE.md` for the full module breakdown, data flow diagrams, and schema.
See `DESIGN.md` for UI/UX specs, screen wireframes, color system, and feature scope.

---

## Project Structure to Create

```
FlickPick/
├── FlickPick/
│   ├── App/
│   │   └── FlickPickApp.swift           — @main, WindowGroup, app lifecycle
│   ├── Views/
│   │   ├── Onboarding/
│   │   │   └── OnboardingView.swift     — First-launch folder picker (drag/drop)
│   │   ├── Home/
│   │   │   ├── HomeView.swift           — Main screen with carousels
│   │   │   ├── ContinueWatchingRow.swift
│   │   │   ├── UpNextRow.swift
│   │   │   ├── CollectionsRow.swift
│   │   │   ├── RecentlyAddedRow.swift
│   │   │   ├── MediaCard.swift          — Thumbnail + progress bar + title
│   │   │   └── SurpriseMeButton.swift
│   │   ├── Collection/
│   │   │   └── CollectionDetailView.swift
│   │   ├── Player/
│   │   │   ├── PlayerView.swift         — Video + controls container
│   │   │   ├── PlayerControlBar.swift   — Seek bar + transport controls
│   │   │   ├── SeekBar.swift            — Custom: thumb preview, chapter marks
│   │   │   ├── PlaylistPanel.swift      — Slide-in episode list
│   │   │   └── FullscreenOverlay.swift  — Auto-hide fullscreen controls
│   │   ├── Search/
│   │   │   └── CommandPalette.swift     — Cmd+K fuzzy search
│   │   └── Settings/
│   │       └── SettingsView.swift
│   ├── ViewModels/
│   │   ├── LibraryViewModel.swift       — Drives Home, observes GRDB
│   │   ├── PlayerViewModel.swift        — Bridges MPVPlayer → SwiftUI
│   │   └── SettingsViewModel.swift
│   ├── Core/
│   │   ├── MPVPlayer/
│   │   │   ├── MPVPlayer.swift          — Owns mpv_handle, lifecycle
│   │   │   ├── MPVRenderer.swift        — Metal render context + CAMetalLayer
│   │   │   ├── MPVEventLoop.swift       — Wakeup callback → serial queue → drain
│   │   │   ├── MPVProperties.swift      — Typed property observation
│   │   │   ├── MPVCommand.swift         — Typed command wrappers
│   │   │   └── MPVVideoView.swift       — NSView → NSViewRepresentable
│   │   ├── SmartEngine/
│   │   │   ├── PatternMatcher.swift     — Tier 1: regex sequence detection
│   │   │   ├── FuzzyGrouper.swift       — Tier 2: longest common prefix
│   │   │   ├── NaturalSort.swift        — Human sort (Ep 2 < Ep 10)
│   │   │   ├── CollectionBuilder.swift  — Group files into franchises
│   │   │   ├── FilenameTokenizer.swift  — Normalize separators, strip ext
│   │   │   └── MediaType.swift          — Classify: episode vs movie vs standalone
│   │   ├── Library/
│   │   │   ├── LibraryManager.swift     — Orchestrator: scan, watch, index
│   │   │   ├── FileWatcher.swift        — FSEvents wrapper
│   │   │   ├── ThumbnailGenerator.swift — AVAssetImageGenerator + mpv fallback
│   │   │   └── FolderScanner.swift      — Walk folders, find media files
│   │   ├── WatchHistory/
│   │   │   ├── WatchHistory.swift       — Record/query watch state
│   │   │   ├── OnDeckEngine.swift       — "What's next?" logic
│   │   │   └── ResumeManager.swift      — Per-file position save/restore
│   │   └── Database/
│   │       ├── AppDatabase.swift        — GRDB setup, migrations, WAL mode
│   │       └── Repositories/
│   │           ├── MediaFileRepository.swift
│   │           ├── WatchRepository.swift
│   │           └── CollectionRepository.swift
│   ├── Models/
│   │   ├── MediaFileRecord.swift        — GRDB record: path, base_name, seq, etc.
│   │   ├── WatchRecord.swift            — position, completed, last_watched_at
│   │   ├── CollectionRecord.swift       — name, type, total/watched counts
│   │   └── WatchedFolderRecord.swift    — path, last_scanned_at
│   ├── Resources/
│   │   └── Assets.xcassets              — App icon, colors, images
│   └── Supporting/
│       ├── FlickPick-Bridging-Header.h  — #include <mpv/client.h> etc.
│       ├── Info.plist                   — File associations, UTI declarations
│       └── FlickPick.entitlements       — Hardened runtime, library validation
├── DESIGN.md
├── ARCHITECTURE.md
└── CLAUDE.md
```

---

## Database Schema

```sql
CREATE TABLE media_files (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    path TEXT UNIQUE NOT NULL,
    filename TEXT NOT NULL,
    folder_path TEXT NOT NULL,
    base_name TEXT,              -- "Harry Potter" (from SmartEngine)
    sequence_num REAL,           -- 2.0 or 2005.0 (season*1000+ep)
    media_type TEXT NOT NULL,    -- 'movie', 'episode', 'standalone'
    collection_id INTEGER REFERENCES collections(id),
    duration_seconds REAL,
    file_size INTEGER,
    thumbnail_path TEXT,
    file_created_at TEXT,
    indexed_at TEXT NOT NULL
);

CREATE TABLE watch_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    media_file_id INTEGER NOT NULL REFERENCES media_files(id) ON DELETE CASCADE,
    position_seconds REAL NOT NULL DEFAULT 0,
    completed INTEGER NOT NULL DEFAULT 0,
    last_watched_at TEXT NOT NULL,
    watch_count INTEGER NOT NULL DEFAULT 0,
    UNIQUE(media_file_id)
);

CREATE TABLE collections (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    collection_type TEXT NOT NULL,  -- 'franchise', 'series'
    total_items INTEGER NOT NULL DEFAULT 0,
    watched_items INTEGER NOT NULL DEFAULT 0,
    thumbnail_path TEXT,
    created_at TEXT NOT NULL
);

CREATE TABLE watched_folders (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    path TEXT UNIQUE NOT NULL,
    last_scanned_at TEXT NOT NULL
);

CREATE INDEX idx_media_files_folder ON media_files(folder_path);
CREATE INDEX idx_media_files_collection ON media_files(collection_id);
CREATE INDEX idx_media_files_base_name ON media_files(base_name);
CREATE INDEX idx_watch_history_last ON watch_history(last_watched_at DESC);
```

---

## Key Implementation Details

### MPVPlayer — libmpv Integration

**Initialization:**
```swift
let handle = mpv_create()
mpv_set_option_string(handle, "vo", "libmpv")        // We provide render surface
mpv_set_option_string(handle, "hwdec", "auto-safe")   // VideoToolbox
mpv_set_option_string(handle, "keep-open", "yes")      // Don't close at EOF
mpv_set_option_string(handle, "save-position-on-quit", "no") // We handle resume
mpv_set_option_string(handle, "af", "loudnorm")        // Volume normalization
mpv_initialize(handle)
```

**Metal Rendering:**
- Create `NSView` subclass backed by `CAMetalLayer`
- Create `mpv_render_context` with `MPV_RENDER_API_TYPE_METAL`
- `mpv_render_context_set_update_callback` → dispatch to render queue → `mpv_render_context_render()` into Metal drawable
- Wrap in `NSViewRepresentable` for SwiftUI

**Event Loop:**
- `mpv_set_wakeup_callback` → dispatches to serial `DispatchQueue`
- Drain loop: `while mpv_wait_event(handle, 0).event_id != MPV_EVENT_NONE { handle event }`
- Property changes → update `@Published` on `@MainActor`
- Key events: `FILE_LOADED`, `END_FILE`, `PROPERTY_CHANGE`, `SHUTDOWN`

**Thread Safety:**
- `mpv_wait_event` called from single serial queue only
- All other `mpv_*` functions are thread-safe
- UI updates dispatched to `@MainActor`

### SmartEngine — Pattern Matching

**Tier 1 — Regex patterns (covers ~70% of files):**
```
S(\d{1,2})E(\d{1,3})           → S01E03
Season\s*(\d+).*Episode\s*(\d+) → Season 1 Episode 3
[Ee]p(?:isode)?\s*(\d+)        → Episode 45
Part\s*(\d+)                    → Part 2
Vol(?:ume)?\s*(\d+)             → Vol 1
^(.+?)\s*(\d+)\s               → Harry Potter 2 Chamber...
```

Sequence number for TV: `season * 1000 + episode` (S02E05 = 2005.0)

**Tier 2 — Fuzzy grouping (covers ~20% more):**
1. Find longest common prefix among sibling files
2. If >50% name overlap → same group
3. Sort by year in filename or alphabetical

**Flow:** Tier 1 → Tier 2 → standalone (no playlist)

### LibraryManager — File Watching

**FSEvents (CoreServices):**
- Watch registered folders for changes (add/delete/rename)
- `kFSEventStreamCreateFlagFileEvents` for per-file notifications
- 500ms batching latency
- Zero CPU when nothing changes

**Thumbnails:**
- Primary: `AVAssetImageGenerator` at 10% of duration (HW accelerated)
- Fallback: mpv screenshot for exotic formats
- Cache: `~/Library/Caches/FlickPick/thumbs/{hash}.jpg`
- Size: 320x180, async generation with placeholder

**Supported extensions:**
```
.mp4, .mkv, .avi, .mov, .wmv, .flv, .webm, .m4v,
.mpg, .mpeg, .ts, .m2ts, .vob, .3gp, .ogv
```

### WatchHistory — Resume & On Deck

- Save position to SQLite every 5 seconds during playback
- Mark completed when position > 90% of duration
- One-tap resume: click card → seek to saved position (no dialog)
- On Deck: find in-progress items → sort by last_watched_at → pair with SmartEngine for "Up Next"

---

## UI Design Summary

### Color System

| Token | Value | Usage |
|-------|-------|-------|
| Background | #0A0A0C | App background (near black) |
| Surface | #161619 | Cards, panels |
| Surface hover | #1E1E22 | Card hover |
| Border | #2A2A30 | Subtle card borders |
| Text primary | #E8E8ED | Titles |
| Text secondary | #8B8B96 | Metadata |
| Accent | #6366F1 | Progress bars, active states (indigo) |
| Watched | #22C55E | Checkmarks (green) |
| New badge | #F59E0B | Recently added (amber) |

### Typography
- SF Pro (system font) — Display for titles, Regular for body, Mono for timestamps
- Card radius: 12px

### Key Screens
1. **Onboarding** — "Where do your movies live?" + drag/drop folder picker
2. **Home** — Continue Watching, Up Next, Collections, Recently Added, Surprise Me
3. **Collection Detail** — Grid of episodes with watched/unwatched state
4. **Player (windowed)** — Persistent bottom control bar, seek thumbnails, chapter marks
5. **Player (fullscreen)** — Auto-hide controls after 2s, semi-transparent gradient
6. **Playlist Panel** — Slides from right, current episode highlighted
7. **Command Palette** — Cmd+K, fuzzy search library + actions

### Player Controls (windowed)
- Row 1: Full-width seek bar with thumbnail preview on hover + chapter marks
- Row 2: Speed | Prev | Play/Pause | Next | Time elapsed/remaining | Volume | Subtitles | Playlist | Fullscreen
- Scroll wheel on video = volume (not seek)
- Right-click context menu: audio tracks, subtitle tracks, speed, A-B loop

### Player Controls (fullscreen)
- Same layout, overlaid with semi-transparent gradient
- Auto-hide after 2s of no mouse movement
- Reappear on mouse move (bottom region)
- Seek bar taller for easier targeting

---

## v1 Feature Scope

### Must-have
- [ ] Home screen with Continue Watching, Up Next, Recently Added, Collections
- [ ] Smart pattern matching (Tier 1 + Tier 2, offline)
- [ ] Auto-collection grouping (franchise detection)
- [ ] Natural sort everywhere
- [ ] libmpv playback with Metal rendering
- [ ] Persistent controls (windowed), auto-hide (fullscreen)
- [ ] Seek bar with thumbnail preview
- [ ] One-tap resume (click → back at exact position)
- [ ] Volume normalization (loudnorm)
- [ ] Progress bars on thumbnails
- [ ] On Deck logic (hides finished, surfaces next)
- [ ] Pre-play background art on selection
- [ ] Smart filter playlists (genre, year, unwatched)
- [ ] Random picker ("Surprise Me")
- [ ] Command palette (Cmd+K)
- [ ] First-launch folder picker
- [ ] FSEvents file watching
- [ ] Keyboard-first controls

### v2 (later)
- [ ] Hover preview (3-5s clip on thumbnail hover)
- [ ] "Still watching?" auto-pause
- [ ] Skip intro detection
- [ ] Scene bookmarks
- [ ] Viewing stats
- [ ] Background artwork (blurred poster)

### v3+ (maybe)
- [ ] Trakt.tv sync
- [ ] TMDb metadata enrichment (opt-in)

---

## Development Commands

```bash
# Build from command line
xcodebuild -scheme FlickPick -configuration Debug build

# Run
xcodebuild -scheme FlickPick -configuration Debug build
open ./build/Debug/FlickPick.app

# Clean
xcodebuild clean
```

---

## Git

- **Remote:** `git@github.com-rahul:Rahul-999-alpha/FlickPick.git`
- **Branch:** `master`
- Uses SSH alias `github.com-rahul` (see root CLAUDE.md for SSH config)

---

## Implementation Order (suggested)

### Phase 1: Core Playback
1. Set up Xcode project with SPM (MPVKit + GRDB)
2. MPVPlayer module — init, load file, basic playback
3. MPVRenderer — Metal rendering in NSViewRepresentable
4. MPVEventLoop — property observation, time tracking
5. Basic PlayerView — video + play/pause + seek

### Phase 2: Smart Engine
6. FilenameTokenizer + PatternMatcher (Tier 1)
7. FuzzyGrouper (Tier 2)
8. NaturalSort
9. CollectionBuilder
10. Test with real filenames

### Phase 3: Database + Library
11. AppDatabase — GRDB setup, migrations, schema
12. Models (MediaFileRecord, WatchRecord, etc.)
13. Repositories
14. FolderScanner + LibraryManager
15. FileWatcher (FSEvents)
16. ThumbnailGenerator

### Phase 4: Home Screen
17. HomeView with carousel rows
18. MediaCard component
19. ContinueWatchingRow (reactive via GRDB ValueObservation)
20. UpNextRow (SmartEngine integration)
21. CollectionsRow + CollectionDetailView
22. RecentlyAddedRow
23. SurpriseMeButton

### Phase 5: Player Polish
24. Full PlayerControlBar
25. Custom SeekBar with thumbnails + chapters
26. PlaylistPanel (slide-in)
27. FullscreenOverlay with auto-hide
28. WatchHistory — save position, resume, mark completed
29. Volume normalization toggle

### Phase 6: Search + Settings
30. CommandPalette (Cmd+K)
31. SettingsView (manage folders, preferences)
32. OnboardingView (first-launch)

### Phase 7: Polish
33. File association (register UTIs)
34. App icon
35. Keyboard shortcuts
36. Edge cases (missing files, corrupt media, etc.)
