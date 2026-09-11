# Repository Guidelines

## Project Structure & Module Organization

The main macOS SwiftUI application is in `Get iPlayer Automator 2/`, organized by feature: `Search/`, `Downloads/`, `PVR/`, `Settings/`, `LogViewer/`, `Scripting/`, `Models/`, and `Utilities/`. The Safari extension is in `Get iPlayer Programme/`. Open `Get iPlayer Automator 2.xcodeproj` for both targets. `Binaries/` holds release-time bundled tools; most contents are generated and ignored. `Scripts/release.sh` packages and signs releases, while `get_iplayer_custom.patch` patches the bundled Perl tool. Read `CLAUDE.md` for deeper architecture and subprocess conventions.

## Build, Test, and Development Commands

Use Xcode for normal development:

```bash
open "Get iPlayer Automator 2.xcodeproj"
xcodebuild -project "Get iPlayer Automator 2.xcodeproj" -scheme "Get iPlayer Automator 2" build
```

Run `make all` (or `make binaries`) to populate bundled tools. This requires the sibling `../get_iplayer_macos` repository and network access; it can take significant time. Use `make gip` or `make yt-dlp` for focused tool updates. Release builds are driven by `Scripts/release.sh` and require signing/notarization credentials—do not run it casually.

## Coding Style & Naming Conventions

Follow the surrounding Swift style: four-space indentation, `UpperCamelCase` for types, `lowerCamelCase` for properties/functions, and feature-oriented file names such as `DownloadQueueViewModel.swift`. Prefer SwiftUI’s existing observation and dependency-injection protocols, and keep subprocess environment/path handling centralized in `Utilities/GetiPlayerArguments.swift`. No repository formatter or linter is configured; keep diffs focused and let Xcode format changes consistently with nearby code.

## Testing Guidelines

There is no committed automated test target. Use the mock view models (for example, `MockCachedProgramsViewModel.swift`) for previews and manual/UI testing. At minimum, build the affected Xcode target and manually exercise relevant windows, downloads, cache refreshes, or browser-extension flows. If adding tests, keep them near the feature and name them after the behavior under test.

## Commit & Pull Request Guidelines

Commits use short, imperative, sentence-style subjects, often naming the affected behavior (for example, `Fix BBC series download`). Keep each commit focused. Pull requests should explain user-visible behavior, identify affected targets or release tooling, link related issues when applicable, and include screenshots or a short reproduction/verification note for UI changes. Mention any required binary rebuild or manual test limitations.

## Security & Configuration Tips

Do not commit credentials, provisioning profiles, generated archives, or locally rebuilt binaries. Review changes to entitlements, browser scripting, subprocess arguments, and bundled tools carefully. Preserve the pipe-delimited output contract introduced by `get_iplayer_custom.patch`; episode titles may contain commas.
