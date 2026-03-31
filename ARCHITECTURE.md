# FlickPick — Architecture

## Tech Stack

| Concern | Choice | Why |
|---------|--------|-----|
| Language | Swift | Native macOS, no runtime overhead |
| UI Framework | SwiftUI | Modern, declarative, reactive |
| Playback Engine | libmpv (via MPVKit SPM) | Battle-tested, plays everything, Metal + VideoToolbox |
| Video Rendering | NSViewRepresentable + CAMetalLayer | mpv renders via Metal render API into SwiftUI |
| Database | GRDB.swift + SQLite | Typed queries, migrations, reactive observation for UI |
| File Watching | FSEvents (CoreServices) | Native macOS, event-driven, zero polling |
| Thumbnails | AVAssetImageGenerator + mpv fallback | Native HW-accelerated, mpv for exotic formats |
| Package Manager | Swift Package Manager | Two dependencies only: MPVKit, GRDB |

---

## High-Level Architecture

```
+------------------------------------------------------------------+
|                        FlickPick.app                             |
|                                                                  |
|  +------------------------------------------------------------+ |
|  |                    SwiftUI Layer                            | |
|  |                                                            | |
|  |  HomeView --- CollectionView --- PlayerView                | |
|  |  OnboardingView    CommandPalette    SettingsView           | |
|  +-------------------------+----------------------------------+ |
|                            |                                    |
|  +-------------------------v----------------------------------+ |
|  |                  ViewModel Layer                           | |
|  |                                                            | |
|  |  LibraryViewModel   PlayerViewModel   SettingsViewModel    | |
|  +-------------------------+----------------------------------+ |
|                            |                                    |
|  +-------------------------v----------------------------------+ |
|  |                   Core Services                            | |
|  |                                                            | |
|  |  +--------------+ +--------------+ +------------------+   | |
|  |  | SmartEngine  | | MPVPlayer    | | LibraryManager   |   | |
|  |  |              | |              | |                  |   | |
|  |  | PatternMatch | | Playback     | | FSEvents Watch   |   | |
|  |  | FuzzyGroup   | | Events       | | Thumbnail Gen    |   | |
|  |  | NaturalSort  | | Render       | | Collection Build |   | |
|  |  | CollectionID | | Controls     | | File Indexing    |   | |
|  |  +--------------+ +------+-------+ +------------------+   | |
|  |                          |                                 | |
|  |  +------------------+   |   +--------------------------+  | |
|  |  | WatchHistory     |   |   | Database (GRDB/SQLite)   |  | |
|  |  |                  |   |   |                          |  | |
|  |  | Resume positions |   |   | media_files              |  | |
|  |  | Watched state    |   |   | watch_history            |  | |
|  |  | On Deck logic    |   |   | collections              |  | |
|  |  +------------------+   |   | watched_folders           |  | |
|  |                         |   +--------------------------+  | |
|  +-------------------------+----------------------------------+ |
|                            |                                    |
|  +-------------------------v----------------------------------+ |
|  |              libmpv (xcframework via MPVKit)               | |
|  |              Metal rendering via CAMetalLayer              | |
|  |              VideoToolbox hardware decoding                | |
|  +------------------------------------------------------------+ |
|                                                                  |
|  +------------------------------------------------------------+ |
|  |              macOS / System Frameworks                     | |
|  |  CoreServices (FSEvents)  AVFoundation (thumbnails)       | |
|  |  Metal  AppKit  UniformTypeIdentifiers                    | |
|  +------------------------------------------------------------+ |
+------------------------------------------------------------------+
```

---

## Module Breakdown

### 1. MPVPlayer — Playback Engine

```
Core/MPVPlayer/
├── MPVPlayer.swift          — NSViewController: owns mpv_handle, Metal layer, event loop, controls
├── MPVPlayerDelegate.swift  — Protocol for ViewModel event callbacks
├── MPVVideoView.swift       — NSViewControllerRepresentable bridge for SwiftUI
└── MetalLayer.swift         — CAMetalLayer subclass with MoltenVK workarounds
```

#### How it works

1. `MPVPlayer` is an `NSViewController` subclass (not a plain class)
2. `loadView()` creates an `NSView`, `viewDidLoad()` sets up the `MetalLayer` and calls `setupMPV()`
3. `setupMPV()`: `mpv_create()` → set options → `mpv_set_option(mpv, "wid", MPV_FORMAT_INT64, &metalLayer)` → `mpv_initialize()`
4. mpv renders directly into the `CAMetalLayer` via Vulkan/MoltenVK — we do NOT use `mpv_render_context`
5. `mpv_set_wakeup_callback` → dispatches to serial `DispatchQueue` → `drainEvents()` loop
6. Property changes dispatched to `@MainActor` via `delegate?.mpvPropertyChanged()`
7. `MPVVideoView` wraps `MPVPlayer` as `NSViewControllerRepresentable` for SwiftUI

#### Key mpv options (actual)

```
wid=<metalLayer pointer>     # Render into our Metal layer (not vo=libmpv)
vo=gpu-next                  # Modern GPU rendering pipeline
gpu-api=vulkan               # Vulkan via MoltenVK
gpu-context=moltenvk         # MoltenVK context for macOS
hwdec=videotoolbox           # Apple Silicon hardware decoding
keep-open=yes                # Don't close at EOF (we control playlist)
```

#### Rendering flow (per frame)

```
mpv decodes frame (VideoToolbox HW acceleration)
  -> mpv internal Vulkan/MoltenVK pipeline
  -> Renders into CAMetalLayer (passed via wid option)
  -> Core Animation composites with SwiftUI overlay
```

Note: We use the `wid` approach where mpv owns the full render pipeline, NOT the
`mpv_render_context` approach where we'd manage Metal drawables ourselves.

#### Event handling pattern

```
mpv_set_wakeup_callback(handle, callback, context)
  -> callback fires on mpv's thread
  -> Dispatches to serial eventQueue

eventQueue drains:
  while mpv_wait_event(handle, 0).event_id != MPV_EVENT_NONE {
    switch event {
      .propertyChange  -> update @Published properties on main thread
      .fileLoaded      -> read metadata, update title
      .endFile         -> trigger On Deck / auto-advance
      .shutdown        -> cleanup
    }
  }
```

#### Thread safety rules

- `mpv_wait_event()` must only be called from one thread (our serial eventQueue)
- All other `mpv_*` functions are thread-safe
- UI updates dispatched to `@MainActor` / `DispatchQueue.main`
- Wakeup callback must NOT call `mpv_wait_event` — just signal the queue

---

### 2. SmartEngine — Pattern Matching

```
Core/SmartEngine/
├── PatternMatcher.swift     — Tier 1: regex-based sequence detection
├── FuzzyGrouper.swift       — Tier 2: longest common prefix grouping
├── NaturalSort.swift        — Human-friendly sort (Ep 2 before Ep 10)
├── CollectionBuilder.swift  — Groups files into franchise collections
├── FilenameTokenizer.swift  — Strip extension, normalize separators
└── MediaType.swift          — Classify: series episode vs standalone movie
```

#### Tier 1: Pattern Detection

Tokenize filename (strip extension, replace `.` `_` `-` with spaces), then match:

| Pattern (Regex) | Example Input | Extracted |
|-----------------|---------------|-----------|
| `S(\d{1,2})E(\d{1,3})` | Breaking.Bad.S01E03.mkv | base: "Breaking Bad", season: 1, episode: 3 |
| `Season\s*(\d+).*Episode\s*(\d+)` | Season 1 Episode 3.mp4 | season: 1, episode: 3 |
| `[Ee]p(?:isode)?\s*(\d+)` | Naruto Episode 45.mkv | base: "Naruto", episode: 45 |
| `Part\s*(\d+)` | Dune Part 2.mkv | base: "Dune", sequence: 2 |
| `Vol(?:ume)?\s*(\d+)` | Kill Bill Vol 1.mkv | base: "Kill Bill", sequence: 1 |
| `^(.+?)\s*(\d+)\s` | Harry Potter 2 Chamber...mkv | base: "Harry Potter", sequence: 2 |

Sequence number for TV: `season * 1000 + episode` (S02E05 = 2005) for unified sorting.

#### Tier 2: Fuzzy Grouping

For files without obvious sequence markers:

1. Find longest common prefix among sibling files in same folder
2. If files share >50% of filename length, they're a group
3. Sort by year in filename if present, otherwise alphabetical

#### Classification flow

```
File opened
  |
  v
Tier 1: Pattern scan -> found sequence marker?
  -> Yes: build playlist sorted by number. Done.
  -> No: fall through
  |
  v
Tier 2: Fuzzy group -> share >50% prefix with siblings?
  -> Yes: group them, sort by year or alpha. Done.
  -> No: treat as standalone movie. No playlist.
```

#### Edge cases

| Scenario | Handling |
|----------|----------|
| Mixed series in one folder (HP + LOTR) | Groups separately by detected base name |
| HP 2 and HP 2 Extended | Both detected as seq 2, show both |
| Random movie in Movies folder | No match -> solo, no junk playlist |
| New episode added to series folder | FSEvents triggers -> re-index -> update collection |

---

### 3. LibraryManager — Indexing + File Watching

```
Core/Library/
├── LibraryManager.swift     — Orchestrates scanning, watching, indexing
├── FileWatcher.swift        — FSEvents wrapper (CoreServices)
├── ThumbnailGenerator.swift — AVAssetImageGenerator + mpv fallback
├── MediaFile.swift          — Model: path, name, size, duration, thumbnail
└── FolderScanner.swift      — Initial scan: walk folders, classify files
```

#### FSEvents setup

```swift
let stream = FSEventStreamCreate(
    nil, callback, &context,
    watchedPaths as CFArray,
    FSEventsGetCurrentEventId(),
    0.5,  // 500ms latency (batch changes)
    UInt32(kFSEventStreamCreateFlagFileEvents |
           kFSEventStreamCreateFlagUseCFTypes)
)
FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), ...)
FSEventStreamStart(stream)
```

- Event-driven, zero CPU when nothing changes
- `kFSEventStreamCreateFlagFileEvents` for per-file notifications
- 500ms batching to coalesce rapid changes

#### Thumbnail strategy

- **Primary:** `AVAssetImageGenerator` — grab frame at 10% of duration, hardware accelerated
- **Fallback:** mpv screenshot command — for MKV/exotic codecs AVFoundation can't handle
- **Cache:** `~/Library/Caches/FlickPick/thumbs/{hash}.jpg`
- **Async:** Generate on background queue, show placeholder until ready
- **Size:** 320x180 (16:9) — small enough for fast grid rendering

#### Supported extensions

```
.mp4, .mkv, .avi, .mov, .wmv, .flv, .webm, .m4v,
.mpg, .mpeg, .ts, .m2ts, .vob, .3gp, .ogv
```

---

### 4. WatchHistory — State Tracking

```
Core/WatchHistory/
├── WatchHistory.swift       — Record/query watch state
├── OnDeckEngine.swift       — "What should I watch next?" logic
└── ResumeManager.swift      — Per-file position save/restore
```

#### Resume strategy

- Save position to SQLite every 5 seconds during playback
- On file open: check watch_history for existing position -> seek to it
- Mark completed when position > 90% of duration
- No "do you want to resume?" dialog — just resume (one-tap)

#### On Deck logic

```
1. Find all in-progress items (position > 0, not completed)
   -> Sort by last_watched_at DESC
   -> This is "Continue Watching"

2. For each in-progress series:
   -> SmartEngine finds next episode by sequence number
   -> This is "Up Next"

3. Filter out completed series (all episodes watched)

4. Recently Added = files indexed in last 7 days, never played
```

---

### 5. Database — GRDB + SQLite

```
Core/Database/
├── AppDatabase.swift        — GRDB setup, migrations, connection
├── Models/
│   ├── MediaFileRecord.swift
│   ├── WatchRecord.swift
│   ├── CollectionRecord.swift
│   └── WatchedFolderRecord.swift
└── Repositories/
    ├── MediaFileRepository.swift
    ├── WatchRepository.swift
    └── CollectionRepository.swift
```

#### Schema

```sql
CREATE TABLE media_files (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    path TEXT UNIQUE NOT NULL,
    filename TEXT NOT NULL,
    folder_path TEXT NOT NULL,
    base_name TEXT,              -- "Harry Potter" (SmartEngine)
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

-- Indexes
CREATE INDEX idx_media_files_folder ON media_files(folder_path);
CREATE INDEX idx_media_files_collection ON media_files(collection_id);
CREATE INDEX idx_media_files_base_name ON media_files(base_name);
CREATE INDEX idx_watch_history_last ON watch_history(last_watched_at DESC);
```

#### Why GRDB over alternatives

| Option | Verdict |
|--------|---------|
| **GRDB.swift** | Best fit — typed queries, migrations, `ValueObservation` for reactive SwiftUI, WAL mode |
| SQLite.swift | Lighter but no observation, weaker migrations |
| Core Data | Overkill ORM, painful debugging |
| SwiftData | Requires macOS 14+, limited control |
| Raw SQLite3 | Too verbose for app development |

#### Reactive UI with GRDB

```swift
// Home screen observes database changes automatically
ValueObservation
    .tracking { db in
        try MediaFileRecord
            .including(optional: MediaFileRecord.watchHistory)
            .filter(Column("completed") == false)
            .order(Column("last_watched_at").desc)
            .fetchAll(db)
    }
    .publisher(in: database)
    .assign(to: &$continueWatching)
```

---

### 6. SwiftUI Views

```
Views/
├── App/
│   └── FlickPickApp.swift           — @main, WindowGroup, app lifecycle
├── Onboarding/
│   └── OnboardingView.swift         — First-launch folder picker
├── Home/
│   ├── HomeView.swift               — ScrollView with all carousels
│   ├── ContinueWatchingRow.swift    — Horizontal scroll of in-progress
│   ├── UpNextRow.swift              — Smart engine "next episode" row
│   ├── CollectionsRow.swift         — Franchise cards with stacked design
│   ├── RecentlyAddedRow.swift       — New files with "NEW" badge
│   ├── MediaCard.swift              — Thumbnail + progress bar + title
│   └── SurpriseMeButton.swift       — Random unwatched picker
├── Collection/
│   └── CollectionDetailView.swift   — Expanded franchise grid
├── Player/
│   ├── PlayerView.swift             — Video + controls container
│   ├── PlayerControlBar.swift       — Seek + transport controls
│   ├── SeekBar.swift                — Custom: thumb preview, chapter marks
│   ├── PlaylistPanel.swift          — Slide-in episode list
│   └── FullscreenOverlay.swift      — Auto-hide controls for fullscreen
├── Search/
│   └── CommandPalette.swift         — Cmd+K fuzzy search overlay
└── Settings/
    └── SettingsView.swift           — Folder management, preferences
```

---

### 7. ViewModels

```
ViewModels/
├── LibraryViewModel.swift    — Drives HomeView, observes GRDB for live updates
├── PlayerViewModel.swift     — Bridges MPVPlayer events to SwiftUI state
└── SettingsViewModel.swift   — Folder management, preferences
```

#### PlayerViewModel key state

```swift
@MainActor
class PlayerViewModel: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var volume: Double = 100
    @Published var currentTitle = ""
    @Published var playlistItems: [MediaFileRecord] = []
    @Published var currentIndex = 0
    @Published var showControls = true
    @Published var isFullscreen = false

    private let mpvPlayer: MPVPlayer
    private let watchHistory: WatchHistory
    private var controlsHideTimer: Timer?
}
```

---

## Data Flow: "Double-click Harry Potter 2"

```
1. macOS opens FlickPick via file association
   -> FlickPickApp receives URL

2. SmartEngine.analyze("Harry.Potter.2.Chamber.of.Secrets.2002.1080p.mkv")
   -> Tier 1: base = "Harry Potter", sequence = 2

3. SmartEngine.buildPlaylist(folder, base = "Harry Potter")
   -> Scans folder, finds HP 1-8
   -> Natural sort by sequence number
   -> Returns playlist, currentIndex = 1

4. LibraryManager.indexIfNeeded(files)
   -> Upsert media_files
   -> Create/update "Harry Potter" collection
   -> Queue thumbnail generation (async)

5. PlayerViewModel.play(file, playlist, startIndex: 1)
   -> WatchHistory.getPosition(file) -> 1:23:40 (last time)
   -> MPVPlayer.loadFile(path)
   -> MPVPlayer.seek(to: 1:23:40)

6. During playback (every 500ms):
   -> MPVEventLoop publishes time-pos
   -> PlayerViewModel updates SeekBar
   -> Every 5s: WatchHistory.savePosition()

7. EOF reached:
   -> WatchHistory.markCompleted(HP2)
   -> OnDeckEngine: next = HP3 (sequence 3)
   -> Auto-advance to HP3 (or show Up Next card)

8. User returns to Home:
   -> GRDB ValueObservation fires
   -> Continue Watching shows HP3 in progress
   -> Up Next shows HP4
   -> Collection card: "Harry Potter 3/8"
```

---

## Project Structure (v0.1.0)

```
FlickPick/                          ← Git root
├── FlickPick.xcodeproj/
├── FlickPick/                      ← Source code (43 Swift files)
│   ├── FlickPickApp.swift
│   ├── ContentView.swift           — Root router
│   ├── Assets.xcassets/
│   ├── ViewModels/
│   │   ├── PlayerViewModel.swift
│   │   ├── LibraryViewModel.swift
│   │   └── SettingsViewModel.swift
│   ├── Views/
│   │   ├── Player/   (PlayerView, PlaylistPanel)
│   │   ├── Home/     (HomeView, MediaCard, 5 row components, SurpriseMeButton)
│   │   ├── Collection/ (CollectionDetailView)
│   │   ├── Search/   (CommandPalette)
│   │   ├── Settings/ (SettingsView)
│   │   └── Onboarding/ (OnboardingView)
│   ├── Core/
│   │   ├── MPVPlayer/ (MPVPlayer, MPVPlayerDelegate, MPVVideoView, MetalLayer)
│   │   ├── SmartEngine/ (PatternMatcher, FuzzyGrouper, NaturalSort, CollectionBuilder, FilenameTokenizer, MediaType)
│   │   ├── Library/  (LibraryManager, FileWatcher, ThumbnailGenerator, FolderScanner)
│   │   ├── WatchHistory/ (WatchHistory, OnDeckEngine, ResumeManager)
│   │   └── Database/
│   │       ├── AppDatabase.swift
│   │       └── Repositories/ (MediaFileRepository, WatchRepository, CollectionRepository)
│   └── Models/ (MediaFileRecord, WatchRecord, CollectionRecord, WatchedFolderRecord)
├── DESIGN.md
├── ARCHITECTURE.md
├── CLAUDE.md
└── .gitignore
```

---

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| MPVKit (`github.com/mpvkit/MPVKit`) | Latest | Pre-built libmpv xcframework (arm64 + x86_64) |
| GRDB.swift (`github.com/groue/GRDB.swift`) | 7.x | SQLite database with reactive observation |

Two external dependencies. Everything else is native Apple frameworks:
- `CoreServices` (FSEvents)
- `AVFoundation` (thumbnails)
- `Metal` (rendering)
- `AppKit` (NSView bridge)
- `UniformTypeIdentifiers` (file type detection)

---

## Build & Distribution

### Development

```bash
# Prerequisites
brew install mpv         # For local libmpv during dev
xcode-select --install   # Xcode CLI tools

# Open in Xcode
open FlickPick.xcodeproj
# Cmd+R to run
```

### Production

- MPVKit provides a signed xcframework embedded in the .app bundle
- Code-sign everything (app + embedded frameworks) for notarization
- Distribute as DMG or via direct download (no App Store for v1)
- Hardened runtime enabled
- Entitlement: `com.apple.security.cs.disable-library-validation` (for loading libmpv dylib)

### File Association

Register for video UTIs in `Info.plist`:
- `public.movie`, `public.mpeg-4`, `com.microsoft.windows-media-wmv`
- Custom UTIs for `.mkv`, `.avi`, etc.
- User sets FlickPick as default video player in macOS Settings

---

## Apple Silicon Considerations

- **Metal only** — OpenGL is deprecated on macOS, translation layer on ARM is suboptimal
- **VideoToolbox** — Apple Silicon media engine handles H.264, H.265, VP9, ProRes in hardware
- **Universal binary** — MPVKit provides arm64 + x86_64 xcframework
- **Hardened runtime** — All dylibs must be signed for notarization
