# FlickPick — Design Document

## Overview

FlickPick is a macOS-native media player built on Swift + SwiftUI + libmpv. Its core differentiator is a **smart pattern-matching engine** that auto-builds playlists from filenames (like PotPlayer on Windows) combined with a **Netflix-style home screen** for local files — no server required.

### Positioning

```
                    Smart Features
                    Low                    High
              +------------------------------------+
   No Server  |  VLC, IINA, mpv    FlickPick <----|
   (Light)    |  Movist Pro                        |
              |------------------------------------+
   Server     |                    Plex, Jellyfin  |
   (Heavy)    |                    Kodi, Emby      |
              +------------------------------------+
```

Closest competitor: Infuse (macOS, no server, Netflix UI) — but closed-source, paid, no custom pattern matching.

---

## Tech Stack

- **Language:** Swift
- **UI Framework:** SwiftUI
- **Playback Engine:** libmpv (via mpv-rs or direct C binding)
- **Database:** SQLite (watch history, collections, metadata)
- **File Watching:** macOS FSEvents (event-driven, no polling)
- **Platform:** macOS only (Apple Silicon native)

---

## v1 Scope

### Home Screen
- Continue Watching (progress bars on thumbnails, most recent first)
- Up Next (pattern engine: HP2 -> HP3)
- Recently Added
- Collections (auto-grouped franchises)
- Random picker ("Surprise Me")
- Command palette (Cmd+K)

### Smart Engine (fully offline)
- **Tier 1 — Pattern Detection:** Tokenize filename, detect S01E01, Part #, trailing numbers, Episode ##, Vol #
- **Tier 2 — Fuzzy Grouping:** Longest common prefix among sibling files, >50% match = same group, sort by year or alpha
- Natural sort everywhere (Episode 2 before Episode 10)
- Auto-collection grouping (franchise detection)

### Player
- libmpv backend
- Persistent controls in windowed mode, auto-hide in fullscreen
- Seek bar with thumbnail preview on hover
- Chapter marks on seek bar
- One-tap resume (click card -> back at exact position)
- Volume normalization
- Keyboard-first controls
- Right-click context menu (audio tracks, subtitle tracks, speed, A-B loop)
- Scroll wheel = volume (not seek)

### Library
- First-launch folder picker (drag or browse)
- FSEvents file watching (event-driven, no periodic scans)
- On Deck logic (hides finished series, surfaces relevant next)
- Thumbnail extraction (frame grab ~10% into file)

### Cherry-picked Features (v1)
| Source | Feature |
|--------|---------|
| Plex | Collections (auto-group franchises) |
| Plex | On Deck logic (smart "what's next") |
| Plex | Pre-play background art on selection |
| Kodi | Random picker ("Surprise Me") |
| Kodi | Smart playlists with filter rules |
| Infuse | Progress bars on thumbnails |
| Infuse | One-tap resume |

---

## v2 Scope (Later)

- Hover preview (3-5s clip on thumbnail hover)
- "Still watching?" auto-pause
- Skip intro detection (audio fingerprinting)
- Scene bookmarks (mark multiple scenes per file)
- Viewing stats (hours watched, genres, streaks)
- Background artwork (blurred poster behind info panel)

## v3+ Scope (Maybe)

- Trakt.tv sync (cross-device watch history)
- TMDb metadata enrichment (opt-in, online)
- Watchlist

---

## Smart Engine — Pattern Matching Detail

### Tier 1: Pattern Detection

Tokenize filename: strip extension, replace `.`, `_`, `-` with spaces.

| Pattern | Example | Extracted |
|---------|---------|-----------|
| S##E## | Breaking.Bad.S01E03.mkv | base: "Breaking Bad", season: 1, episode: 3 |
| Episode ## | Naruto Episode 45.mkv | base: "Naruto", episode: 45 |
| Part # / Pt # | Dune Part 2.mkv | base: "Dune", sequence: 2 |
| Trailing number | Harry Potter 2 Chamber...mkv | base: "Harry Potter", sequence: 2 |
| Vol # | Kill Bill Vol 1.mkv | base: "Kill Bill", sequence: 1 |

### Tier 2: Fuzzy Grouping

For files without obvious sequence markers:

1. Find longest common prefix among sibling files in same folder
2. If files share >50% of filename, they're a group
3. Sort by year in filename if present, otherwise alphabetical

### Flow

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
  -> No: treat as standalone. No playlist.
```

### Edge Cases

| Scenario | Handling |
|----------|----------|
| Mixed series in one folder (HP + LOTR) | Groups separately by detected base name |
| Harry Potter 2 + Harry Potter 2 Extended | Both detected as sequence 2, show both (user picks) |
| Random movie in Movies folder | No match -> opens solo, no junk playlist |
| New episode added | FSEvents triggers -> auto-updates series card on home screen |

---

## UI Design

### Color System

| Token | Value | Usage |
|-------|-------|-------|
| Background | #0A0A0C | App background (near black) |
| Surface | #161619 | Cards, panels |
| Surface hover | #1E1E22 | Card hover state |
| Border | #2A2A30 | Subtle card borders |
| Text primary | #E8E8ED | Titles, main text |
| Text secondary | #8B8B96 | Subtitles, metadata |
| Accent | #6366F1 | Progress bars, active states (indigo) |
| Accent glow | #6366F1 @ 20% | Hover glow on active items |
| Watched | #22C55E | Checkmarks, completed (green) |
| New badge | #F59E0B | Recently added badge (amber) |

### Typography

- **Font:** SF Pro (system) — Display weight for titles, Regular for body, Mono for timestamps
- **Card radius:** 12px (matches macOS window radius)

### Screens

#### 1. First Launch
- Single screen: "Where do your movies live?"
- Drag-and-drop zone + browse button
- Added folders listed with remove (x) buttons
- "Let's go" button to start scanning

#### 2. Home Screen
- **Continue Watching** — horizontal carousel, progress bars, click = instant resume
- **Up Next** — mirrors Continue Watching, shows next item per pattern engine
- **Collections** — stacked card design, franchise name, progress (5/8), mini progress bar
- **Recently Added** — NEW badge, sorted by file creation date
- **Surprise Me** — button at bottom, picks random unwatched item
- **Cmd+K** — command palette, fuzzy search entire library

#### 3. Collection Expanded View
- Back button + collection title
- Grid of items with watched/unwatched/in-progress state
- Click any card to play

#### 4. Player (Windowed)
- Title bar: series name + episode + title, thin progress line at top edge
- Video area
- Control bar (always visible):
  - Row 1: Full-width seek bar with thumbnail preview + chapter marks
  - Row 2: Speed | Prev | Play/Pause | Next | Time | Volume | Subtitles | Playlist | Fullscreen

#### 5. Player (Fullscreen)
- Same controls but overlaid with semi-transparent gradient
- Auto-hide after 2s idle
- Reappear on mouse move
- Seek bar taller for easier targeting

#### 6. Playlist Panel
- Slides in from right over video
- Current episode highlighted with play marker + progress
- Watched episodes dimmed/checked
- Keyboard: up/down to navigate, Enter to play
- Shuffle toggle

#### 7. Command Palette (Cmd+K)
- Centered overlay with search input
- Fuzzy search: collections, files, actions (Surprise Me, Settings, Add folder)
- Keyboard navigable

---

## Competitive Landscape

### Server-required (not competing with)
- Plex, Jellyfin, Emby, Dim, Kyoo — all require running a server process

### No server, limited smart features
- Infuse — closest competitor, but closed-source, paid, no pattern matching
- Kodi — smart playlists but TV-oriented UI, complex setup
- Stremio — streaming-first, local files are afterthought
- VLC, IINA, mpv, Movist Pro — pure players, no library/smart features

### FlickPick's niche
Open-source, serverless, macOS-native media player with:
- Automatic filename-based series detection and pattern matching
- Netflix-style home screen with Continue Watching, Up Next, Collections
- No server overhead — lightweight desktop app

---

## File Scanning Strategy

- **First launch:** One-time index of selected folders (read filenames + extract one thumbnail per file)
- **Ongoing:** macOS FSEvents watches folders — event-driven, zero CPU when nothing changes
- **On app launch:** Quick diff check ("anything new since last close?") — milliseconds
- **No periodic scanning, no background daemon**
