# Get iPlayer Automator 2

Rewrite of [Get iPlayer Automator](https://github.com/Ascoware/get-iplayer-automator) for macOS, written in SwiftUI. Downloads BBC iPlayer and STV programmes by wrapping [`get_iplayer`](https://github.com/get-iplayer/get_iplayer) and `yt-dlp`.

**Version** 2.0.0 — macOS 14.0+ required.

## Features

- **BBC iPlayer** — browse, search, and download TV and radio programmes via `get_iplayer`
- **STV (player.stv.tv)** — download non-DRM programmes using `yt-dlp` with AtomicParsley metadata tagging
- **Safari Extension** — toolbar button sends the current browser page (BBC/STV) to the app via Darwin notifications
- **Browser Integration** — "Use Current Webpage" extracts PIDs from Safari, Chrome, Edge, Vivaldi, and Brave
- **PVR (Series Recording)** — auto-download new episodes of tracked series on startup
- **Download Queue** — sequential download manager with persistence, status tracking, and retry
- **Activity Window** — shows ongoing cache updates, downloads, and PVR activity
- **Download History** — pipe-delimited flat file, deduplicated via `OrderedSet`
- **Sparkle Updates** — automatic update checking with DSA signature verification

## Windows

| Window | Description |
|---|---|
| **Search** | Browse/filter cached programmes by channel, type, or search text |
| **Download Queue** | View, reorder, and manage queued downloads |
| **PVR** | Manage series recording links |
| **Settings** | General, format, channels, advanced, and STV token configuration |
| **Log** | Real-time log viewer with color-coded levels |
| **Download History** | Previously downloaded programmes |
| **Activity** | Background operation status (cache updates, downloads, PVR) |

## Architecture

### Tech Stack
- **SwiftUI** with `@Observable` view models and `@Bindable` property wrappers
- Dependency injection via protocols (`ProgramCacheProviding`, `DownloadQueueProviding`, `DownloadHistoryProviding`)
- Mock implementations for each protocol for previews and testing
- `@Default` property wrapper backed by `@AppStorage` for preferences

### Key Components

| Component | Role |
|---|---|
| `CachedProgramsViewModel` | Reads `.cache` files from Application Support; exposes BBC TV, non-BBC TV, and radio shows |
| `CacheUpdateService` | Runs `get_iplayer --refresh` / `--cache-rebuild` asynchronously |
| `DownloadQueueViewModel` | Manages a sequential download queue (one at a time), persisted as JSON |
| `BBCDownload` | Parses `get_iplayer` output line-by-line via the Sweep library |
| `STVDownload` | Uses `yt-dlp` + AtomicParsley for non-BBC programmes |
| `GetCurrentWebpage` | ScriptingBridge to extract URLs from supported browsers |
| `PVRModel` | Stores series names; runs `get_iplayer` searches to find new episodes |
| `LogController` | CocoaLumberjack-based logging with real-time streaming to the Log window |

### Bundled Tools

| Tool | Location |
|---|---|
| **get_iplayer** (Perl) | `Binaries/get_iplayer/perl/bin/` |
| **yt-dlp** | `Binaries/yt-dlp_macos/` |
| **AtomicParsley** | `Binaries/get_iplayer/utils/bin/` |
| **ffmpeg** | `Binaries/get_iplayer/utils/bin/` |
| **Root CA certificates** | `Binaries/cacert.pem` |

### Dependencies (SPM)

CocoaLumberjackSwift, SwiftyJSON, Kanna, Sparkle, OrderedCollections, Sweep, DefaultsWrapper, RichTextKit, STTextView

## Building

```bash
open "Get iPlayer Automator 2.xcodeproj"
# Cmd+R to build and run, or use:
xcodebuild -project "Get iPlayer Automator 2.xcodeproj" -scheme "Get iPlayer Automator 2" build
```

The app requires bundled binaries. Run `make all` to fetch and build them (requires the sibling repo `../get_iplayer_macos` for Perl and utils).

## Project Structure

The main app target (`Get iPlayer Automator 2`) and Safari extension (`Get iPlayer Programme`) share a version defined in `Version.xcconfig` (`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`). A separate `iPlayerIndexer/` SPM package provides BBC download and programme indexing command-line tools.

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE).

## Author

Scott Kovatch
