# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

Build and run using Xcode:
```bash
open "Get iPlayer Automator 2.xcodeproj"
# Then use Cmd+R to build and run, or Cmd+B to build only
```

Or from command line:
```bash
xcodebuild -project "Get iPlayer Automator 2.xcodeproj" -scheme "Get iPlayer Automator 2" build
```

There are no automated tests — the codebase uses mock implementations (`MockCachedProgramsViewModel.swift`, `MockDownloadQueueViewModel.swift`, `MockDownloadHistoryModel.swift`) for manual/UI testing.

## Architecture Overview

Get iPlayer Automator 2 is a macOS SwiftUI application for downloading BBC iPlayer and STV content. It wraps the Perl-based `get_iplayer` command-line tool and `yt-dlp` for video downloads.

### App Structure

**Entry Point**: `GetiPlayerAutomatorApp.swift` — SwiftUI App with 6 windows: Search (main), Download Queue, PVR, Settings, Log Viewer, Download History. Initializes singletons and triggers a cache update on startup.

**AppDelegate**: Application lifecycle, Sparkle updates, `UNUserNotificationCenter` local notifications, and exit confirmation if downloads or cache updates are active.

### Core Data Flow

**Cache System** (`CachedProgramsViewModel.swift` + `CacheUpdateService.swift`):
- `CacheUpdateService` runs `get_iplayer --refresh` (or `--cache-rebuild`) and notifies `CachedProgramsViewModel` via callback when done.
- `CachedProgramsViewModel.shared` reads `.cache` files from Application Support and exposes `bbcTVShows`, `nonBbcTVShows`, `radioShows`.
- Implements `ProgramCacheProviding` protocol.

**Download System** (sequential — one download at a time):
- `Programme.swift` — core model with `@Published var status: ProgramState`. `ProgramState` is a 14-state enum (`.new` → `.successful`/`.failed`/`.cancelled`). Conforms to `ObservableObject`, `Codable`, `Identifiable`, `Comparable`, `Hashable`.
- `Download.swift` — base class holding a `CommandRunner` reference and preference access via `@Default`.
- `BBCDownload.swift` — parses `get_iplayer` output line-by-line using the `Sweep` library for regex matching. Classifies failures via `failureKeyword` pattern (FileExists, ShowNotFound, proxy errors, etc.).
- `ITVDownload.swift` — uses `yt-dlp` for non-BBC downloads, then calls AtomicParsley for metadata tagging.
- `DownloadQueueViewModel.shared` — drives the queue via `startOneDownload()` → `await download.start()` → recursive call for next item. Persists queue as JSON in Application Support. Implements `DownloadQueueProviding` protocol. Optionally adds completed downloads to Music/TV app via ScriptingBridge.

**Command Execution** (`Utilities/CommandRunner.swift`):
- Async wrapper around `Process`. Streams output line-by-line via `AsyncThrowingStream`.
- Uses `TerminationState` actor for thread-safe cancellation tracking.
- Call `cancel()` to interrupt a running process.

**Paths to Binaries** (`GetiPlayerArguments.swift`):
- Singleton providing absolute paths to bundled Perl, `yt-dlp`, AtomicParsley, ffmpeg.
- Sets required environment variables: `PERL_UNICODE=AS`, `PATH`, `SSL_CERT_FILE`.

### Key Patterns

**Preferences** — custom `@Default` property wrapper backed by `@AppStorage` via `Defaults.shared` singleton (`Preference.swift`). Extend `Defaults` class to add new preferences:
```swift
@Default(\.downloadPath) var downloadPath
```
Key enums in `Preference.swift`: `TVFormat` (fhd/hd/sd/web/mobile) and `RadioFormat` (high/standard/medium/low), each with BBC and STV keyword mappings for the download arguments.

**Dependency Injection via Protocols**:
- `ProgramCacheProviding` — cache read operations
- `DownloadQueueProviding` — queue state and control
- `DownloadHistoryProviding` — history read/write
- View models accept these protocols in their initializers; mock implementations exist for each.

**Metadata Fetching**:
- `ProgrammeMetadataFetch.swift` — runs `get_iplayer --info` for a single PID, parses output into a `Programme` object.
- `STVMetadataExtractor.swift` / `ITVMetadataExtractor.swift` — scrape HTML with Kanna + SwiftyJSON.

**PVR (Series Recording)** (`PVRModel.swift`):
- Stores a list of series names. `addSeriesLinkToQueue()` runs `get_iplayer` search for each, parses matching shows, and adds them to `DownloadQueueViewModel`.

**Browser Integration** (`Scripting/GetCurrentWebpage.swift`):
- ScriptingBridge to extract the current URL from Safari/Chrome/Edge.
- Parses BBC PIDs from iplayer/radio/sounds/programmes URLs.

**Download History** (`DownloadHistoryModel.swift`):
- Pipe-delimited flat file in Application Support.
- Uses `OrderedSet` from swift-collections.

**Logging**: Use `DDLogInfo(...)`, `DDLogError(...)`, etc. (CocoaLumberjack). `LogController.swift` streams log entries to the Log Viewer window. File logger rolls daily, keeping 1 file.

### External Tools (bundled in `Binaries/`)

- `get_iplayer/` — Perl installation with `get_iplayer` script
- `yt-dlp_macos/` — for non-BBC downloads
- `utils/bin/` — AtomicParsley and ffmpeg for metadata tagging

### Dependencies (Swift Package Manager via Xcode)

- **CocoaLumberjackSwift** — logging
- **SwiftyJSON** — JSON parsing
- **Kanna** — HTML/XML parsing
- **Sparkle** — auto-updates
- **OrderedCollections** — `OrderedSet` for download history
- **Sweep** — string/regex pattern matching (used to parse command output)
- **DefaultsWrapper** — utilities supporting the `@Default` pattern
- **RichTextKit** / **STTextView** — log viewer text display
