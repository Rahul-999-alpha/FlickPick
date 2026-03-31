# FlickPick — CLAUDE.md

## What is FlickPick?

FlickPick is a macOS-native media player built on **Swift + SwiftUI + libmpv**. Its core differentiators:

1. **Smart pattern-matching engine** — auto-builds playlists from filenames (like PotPlayer on Windows). Open Harry Potter 2 → it finds HP 1-8, queues them in order.
2. **Netflix-style home screen** — Continue Watching, Up Next, Collections, Recently Added — all for local files.
3. **No server required** — unlike Plex/Jellyfin, it's a lightweight desktop app.

**Target:** macOS only, Apple Silicon native (M-series chips).
**Version:** 0.1.0 (initial build — core functionality working)

---

## Tech Stack

| Concern | Choice |
|---------|--------|
| Language | Swift 5 |
| UI | SwiftUI |
| Playback | libmpv via MPVKit-GPL (SPM) |
| Video Rendering | NSViewControllerRepresentable + CAMetalLayer (MoltenVK/Vulkan) |
| Database | GRDB.swift + SQLite |
| File Watching | FSEvents (CoreServices) |
| Thumbnails | AVAssetImageGenerator |
| Package Manager | Swift Package Manager |

### SPM Dependencies

| Package | URL | Product Used | Purpose |
|---------|-----|-------------|---------|
| MPVKit | `https://github.com/mpvkit/MPVKit` | **MPVKit-GPL** | Pre-built libmpv xcframework |
| GRDB.swift | `https://github.com/groue/GRDB.swift` | **GRDB** | SQLite with reactive observation |

**Important:** Only `MPVKit-GPL` and `GRDB` should be linked. Do NOT also link `MPVKit` or `GRDB-dynamic` — causes duplicate framework build errors.

---

## Architecture Overview

```
SwiftUI Views (Home, Player, Collection, CommandPalette, Settings, Onboarding)
       |
ViewModels (LibraryViewModel, PlayerViewModel, SettingsViewModel)
       |
Core Services:
  - MPVPlayer     — libmpv wrapper, Metal rendering via CAMetalLayer, event loop
  - SmartEngine   — filename pattern matching, fuzzy grouping, natural sort
  - LibraryManager — FSEvents file watching, thumbnail gen, indexing
  - WatchHistory  — resume positions, On Deck logic, watched state
  - Database      — GRDB/SQLite, schema, repositories
       |
libmpv (xcframework via MoltenVK/Vulkan) + macOS frameworks (Metal, AVFoundation, CoreServices)
```

See `ARCHITECTURE.md` for the full module breakdown, data flow diagrams, and schema.
See `DESIGN.md` for UI/UX specs, screen wireframes, color system, and feature scope.

---

## Project Structure (actual, v0.1.0)

```
FlickPick/                          ← Git root
├── FlickPick.xcodeproj/
├── FlickPick/                      ← Source code
│   ├── FlickPickApp.swift          — @main, WindowGroup, dark theme
│   ├── ContentView.swift           — Root router: Onboarding → Home → Player → Settings
│   ├── Assets.xcassets/
│   ├── ViewModels/
│   │   ├── PlayerViewModel.swift   — Bridges MPVPlayer → SwiftUI, smart playlist, resume
│   │   ├── LibraryViewModel.swift  — Drives Home screen, reactive GRDB observation
│   │   └── SettingsViewModel.swift — Folder management
│   ├── Views/
│   │   ├── Player/
│   │   │   ├── PlayerView.swift    — Video surface + transport controls + keyboard shortcuts
│   │   │   └── PlaylistPanel.swift — Slide-in playlist panel
│   │   ├── Home/
│   │   │   ├── HomeView.swift      — Netflix-style carousel layout
│   │   │   ├── MediaCard.swift     — Thumbnail + progress bar + title
│   │   │   ├── ContinueWatchingRow.swift
│   │   │   ├── UpNextRow.swift
│   │   │   ├── CollectionsRow.swift
│   │   │   ├── RecentlyAddedRow.swift
│   │   │   └── SurpriseMeButton.swift
│   │   ├── Collection/
│   │   │   └── CollectionDetailView.swift
│   │   ├── Search/
│   │   │   └── CommandPalette.swift — Cmd+K fuzzy search
│   │   ├── Settings/
│   │   │   └── SettingsView.swift
│   │   └── Onboarding/
│   │       └── OnboardingView.swift — First-launch folder picker with drag/drop
│   ├── Core/
│   │   ├── MPVPlayer/
│   │   │   ├── MPVPlayer.swift     — Owns mpv_handle, Metal layer, event loop, controls
│   │   │   ├── MPVPlayerDelegate.swift — Protocol for ViewModel event handling
│   │   │   ├── MPVVideoView.swift  — NSViewControllerRepresentable bridge
│   │   │   └── MetalLayer.swift    — CAMetalLayer with MoltenVK workarounds
│   │   ├── SmartEngine/
│   │   │   ├── PatternMatcher.swift — Tier 1: regex sequence detection (6 patterns)
│   │   │   ├── FuzzyGrouper.swift  — Tier 2: longest common prefix grouping
│   │   │   ├── NaturalSort.swift   — Human sort (Ep 2 < Ep 10)
│   │   │   ├── CollectionBuilder.swift — Build playlists from sibling files
│   │   │   ├── FilenameTokenizer.swift — Normalize separators, strip ext/tags
│   │   │   └── MediaType.swift     — Classify: episode vs movie vs standalone
│   │   ├── Library/
│   │   │   ├── LibraryManager.swift — Orchestrator: scan, watch, index
│   │   │   ├── FileWatcher.swift   — FSEvents wrapper (500ms batching)
│   │   │   ├── ThumbnailGenerator.swift — AVAssetImageGenerator (320x180, cached)
│   │   │   └── FolderScanner.swift — Walk folders, find & index media files
│   │   ├── WatchHistory/
│   │   │   ├── WatchHistory.swift  — Convenience facade for watch state
│   │   │   ├── OnDeckEngine.swift  — Continue Watching + Up Next logic
│   │   │   └── ResumeManager.swift — Save position every 5s, resume on open
│   │   └── Database/
│   │       ├── AppDatabase.swift   — GRDB setup, migrations, WAL mode
│   │       └── Repositories/
│   │           ├── MediaFileRepository.swift
│   │           ├── WatchRepository.swift
│   │           └── CollectionRepository.swift
│   └── Models/
│       ├── MediaFileRecord.swift   — GRDB record: path, base_name, sequence, etc.
│       ├── WatchRecord.swift       — position, completed, last_watched_at
│       ├── CollectionRecord.swift  — name, type, total/watched counts
│       └── WatchedFolderRecord.swift
├── DESIGN.md
├── ARCHITECTURE.md
├── CLAUDE.md
└── .gitignore
```

**43 Swift files total.**

---

## Database Schema

```sql
CREATE TABLE collections (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    collectionType TEXT NOT NULL,  -- 'franchise', 'series'
    totalItems INTEGER NOT NULL DEFAULT 0,
    watchedItems INTEGER NOT NULL DEFAULT 0,
    thumbnailPath TEXT,
    createdAt DATETIME NOT NULL
);

CREATE TABLE media_files (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    path TEXT UNIQUE NOT NULL,
    filename TEXT NOT NULL,
    folderPath TEXT NOT NULL,
    baseName TEXT,
    sequenceNum REAL,
    mediaType TEXT NOT NULL,        -- 'movie', 'episode', 'standalone'
    collectionId INTEGER REFERENCES collections(id) ON DELETE SET NULL,
    durationSeconds REAL,
    fileSize INTEGER,
    thumbnailPath TEXT,
    fileCreatedAt DATETIME,
    indexedAt DATETIME NOT NULL
);

CREATE TABLE watch_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    mediaFileId INTEGER NOT NULL REFERENCES media_files(id) ON DELETE CASCADE,
    positionSeconds REAL NOT NULL DEFAULT 0,
    completed BOOLEAN NOT NULL DEFAULT 0,
    lastWatchedAt DATETIME NOT NULL,
    watchCount INTEGER NOT NULL DEFAULT 0,
    UNIQUE(mediaFileId)
);

CREATE TABLE watched_folders (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    path TEXT UNIQUE NOT NULL,
    lastScannedAt DATETIME NOT NULL
);

CREATE INDEX idx_media_files_folder ON media_files(folderPath);
CREATE INDEX idx_media_files_collection ON media_files(collectionId);
CREATE INDEX idx_media_files_base_name ON media_files(baseName);
CREATE INDEX idx_watch_history_last ON watch_history(lastWatchedAt);
```

Note: Column names use camelCase in GRDB (Swift `Codable` convention), not snake_case.

---

## Key Implementation Details

### MPVPlayer — libmpv Integration

**Actual initialization (MPVPlayer.swift):**
```swift
mpv = mpv_create()
mpv_set_option(mpv, "wid", MPV_FORMAT_INT64, &metalLayer)  // Render into our Metal layer
mpv_set_option_string(mpv, "vo", "gpu-next")
mpv_set_option_string(mpv, "gpu-api", "vulkan")
mpv_set_option_string(mpv, "gpu-context", "moltenvk")
mpv_set_option_string(mpv, "hwdec", "videotoolbox")
mpv_set_option_string(mpv, "keep-open", "yes")
mpv_initialize(mpv)
```

**Import:** `import Libmpv` (NOT `import mpv` — the MPVKit SPM module is named `Libmpv`)

**Rendering approach:** mpv manages its own Vulkan/MoltenVK rendering pipeline. We pass it a `CAMetalLayer` via the `wid` option. mpv renders directly into this layer. We do NOT use `mpv_render_context` — that's an alternative approach. The `wid` approach is simpler and what MPVKit's demo uses.

**MetalLayer workarounds:**
- Override `drawableSize` setter to reject 1x1 sizes (MoltenVK bug causes flicker)
- Override `wantsExtendedDynamicRangeContent` to dispatch to main thread (thread safety)

**Event loop:**
- `mpv_set_wakeup_callback` → serial `DispatchQueue` → `drainEvents()` loop
- Property observations: `time-pos`, `duration`, `pause`, `eof-reached`, `volume`, `paused-for-cache`
- Events: `FILE_LOADED`, `END_FILE`, `PROPERTY_CHANGE`, `SHUTDOWN`, `LOG_MESSAGE`
- UI updates dispatched to `@MainActor` via `DispatchQueue.main.async`

**Thread safety:**
- `mpv_wait_event` called ONLY from the serial event queue
- All other `mpv_*` functions are thread-safe
- Wakeup callback must NOT call `mpv_wait_event` — just signals the queue

### SmartEngine — Pattern Matching

**Tier 1 — Regex patterns (6 patterns, covers ~70%):**
```
S(\d{1,2})E(\d{1,3})           → S01E03       → episode, seq = season*1000+ep
Season\s*(\d+).*Episode\s*(\d+) → Season 1 Ep 3 → episode
[Ee]p(?:isode)?\s*(\d+)        → Episode 45    → episode
Part\s*(\d+)                    → Part 2        → movie
Vol(?:ume)?\s*(\d+)             → Vol 1         → movie
^(.+?)\s*(\d{1,2})\s+(.+)$     → HP 2 Chamber... → movie (trailing number)
```

**Tier 2 — Fuzzy grouping (covers ~20% more):**
1. Tokenize all sibling filenames (strip ext, replace separators)
2. Find longest common prefix between pairs
3. If overlap > 50% of shorter name length AND prefix >= 3 chars → same group
4. Natural sort within group

**Flow:** Open file → Tier 1 → Tier 2 → standalone (no playlist)

### LibraryManager — File Watching

**FSEvents (CoreServices):**
- `kFSEventStreamCreateFlagFileEvents` for per-file notifications
- 500ms batching latency
- Zero CPU when nothing changes
- On change: re-index only changed video files

**Thumbnails:**
- `AVAssetImageGenerator` at 10% of duration (HW accelerated on Apple Silicon)
- Cache: `~/Library/Caches/FlickPick/thumbs/{base64hash}.jpg`
- Size: 320x180, async generation with placeholder
- Actor-isolated (`ThumbnailGenerator` is an `actor`)

**Supported extensions:**
```
.mp4, .mkv, .avi, .mov, .wmv, .flv, .webm, .m4v,
.mpg, .mpeg, .ts, .m2ts, .vob, .3gp, .ogv
```

### WatchHistory — Resume & On Deck

- Save position to SQLite every 5 seconds during playback
- Resume on file open: seek to saved position if > 5s
- Mark completed when position > 90% of duration
- One-tap resume: click card → loads and seeks automatically
- On Deck: in-progress items → sort by `lastWatchedAt` → SmartEngine finds "Up Next"
- Auto-advance: when EOF reached, plays next file in playlist

---

## Known Issues (v0.1.0)

- **Video doesn't resize with window** — mpv's Metal layer frame needs to update on `viewDidLayout`. The `viewDidLayout` override exists but may not be triggering correctly through the SwiftUI bridge.
- **No subtitle track selection UI** — mpv loads subtitles automatically (embedded + sidecar via `subs-match-os-language` and `subs-fallback`), but there's no UI to switch tracks yet.
- **No volume normalization toggle** — `loudnorm` audio filter not yet wired up.
- **No seek thumbnail preview** — seek bar works but doesn't show frame previews on hover.
- **No right-click context menu** — audio/subtitle track selection, speed control not yet accessible.
- **No file associations** — UTIs not registered in Info.plist yet.
- **No app icon** — using default Xcode icon.

---

## v0.1.0 Feature Status

### Working
- [x] libmpv playback with Metal rendering (Vulkan/MoltenVK)
- [x] VideoToolbox hardware decoding
- [x] Smart pattern matching (Tier 1 regex + Tier 2 fuzzy)
- [x] Auto-collection grouping (franchise detection)
- [x] Natural sort everywhere
- [x] Smart playlist auto-building (open HP2 → queues HP1-8)
- [x] Auto-advance to next episode at EOF
- [x] Home screen with Continue Watching, Up Next, Recently Added, Collections
- [x] Netflix-style carousel layout
- [x] Onboarding view (first-launch folder picker with drag/drop)
- [x] Seek bar with drag-to-seek
- [x] One-tap resume (saves position every 5s, restores on open)
- [x] Progress bars on thumbnail cards
- [x] On Deck logic (hides finished, surfaces next)
- [x] Random picker ("Surprise Me")
- [x] Command palette (Cmd+K search)
- [x] Settings view (add/remove watched folders, rescan)
- [x] FSEvents file watching (live index updates)
- [x] Thumbnail generation (AVAssetImageGenerator, cached)
- [x] Collection detail view (grid of episodes with watch state)
- [x] Playlist panel (slide-in, press P)
- [x] Fullscreen toggle (F key or double-click)
- [x] Auto-hide controls in fullscreen (2.5s timeout)
- [x] Keyboard controls (space, arrows, m, f, p, [ ])
- [x] Drag & drop video files to play
- [x] Dark theme forced
- [x] GRDB reactive database (UI updates automatically on data changes)
- [x] SQLite database with proper migrations
- [x] App Sandbox disabled (required for file access + mpv dylib)

### Not Yet Implemented (v1 scope)
- [ ] Video resize with window (known bug)
- [ ] Subtitle track selection UI
- [ ] Audio track selection UI
- [ ] Playback speed control
- [ ] Volume normalization (loudnorm filter)
- [ ] Seek bar thumbnail preview on hover
- [ ] Pre-play background art
- [ ] Smart filter playlists (genre, year, unwatched)
- [ ] Right-click context menu
- [ ] File association (register UTIs in Info.plist)
- [ ] App icon
- [ ] Scroll wheel = volume control

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

# Clean build
xcodebuild clean -scheme FlickPick

# Open in Xcode
open FlickPick.xcodeproj
# Then Cmd+R to build and run
```

**Xcode setup notes:**
- App Sandbox must be **disabled** (`ENABLE_APP_SANDBOX = NO` in build settings)
- Only link `MPVKit-GPL` and `GRDB` frameworks (not `MPVKit` or `GRDB-dynamic`)
- Metal API Validation may need to be disabled for HDR video playback (Edit Scheme → Run → Diagnostics)

---

## Git

- **Remote:** `git@github.com-rahul:Rahul-999-alpha/FlickPick.git`
- **Branch:** `master`
- Uses SSH alias `github.com-rahul` (see root CLAUDE.md for SSH config)
