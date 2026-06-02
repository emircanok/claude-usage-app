# Claude Usage

A small, native macOS app that shows your **Claude Code usage percentage** live in the menu bar. The percentage of your 5-hour limit appears color-coded in the menu bar; click it to reveal your 5-hour / weekly limits, per-model usage, and reset countdowns.

> Swift + SwiftUI (`MenuBarExtra`), no App Sandbox, no Dock icon — a lean menu bar agent.

## Features

- 🎯 5-hour usage percentage in the menu bar (color-coded: green → orange → red)
- 📊 Popover with 5-hour + weekly + Sonnet/Opus usage and reset countdowns
- 🔔 One-shot macOS notifications at the 75% and 90% thresholds
- 🚀 Launch at login (Login Items / `SMAppService`)
- 🔄 Refreshes every 5 minutes + on popover open + manual refresh

## How it works

It reads the OAuth token from the macOS Keychain (`Claude Code-credentials`) and calls the same official endpoint (`api.anthropic.com/api/oauth/usage`) that Claude Code's `/usage` command uses.

When the token is about to expire, it refreshes it **exactly the same way Claude Code does** (`claude.ai/v1/oauth/token`) and writes the new token back in place into the same Keychain item — so Claude Code keeps working and both stay in sync. The token is never sent to any third party; only Anthropic's official endpoints are used.

## Requirements

- macOS 14+
- A signed-in Claude Code (so the token exists in the Keychain)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) + Xcode 15+

## Build & run

```bash
xcodegen generate
xcodebuild -project ClaudeUsage.xcodeproj -scheme ClaudeUsage \
  -configuration Release -derivedDataPath build clean build
open build/Build/Products/Release/ClaudeUsage.app
```

On first launch macOS will ask for Keychain access → choose **"Always Allow"**.

For launch-at-login to work reliably, move the app to `/Applications`:

```bash
cp -R build/Build/Products/Release/ClaudeUsage.app /Applications/
```

> Whenever you change `project.yml` or add/remove a source file, re-run `xcodegen generate` — the `.xcodeproj` is generated from that file and is not hand-edited.

## Project structure

```
ClaudeUsage/
├── ClaudeUsageApp.swift      # @main, AppDelegate, MenuBarExtra
├── UsageViewModel.swift      # @Observable @MainActor — single source of truth, 5-min polling
├── KeychainReader.swift      # Keychain read + in-place token update (SecItemUpdate)
├── TokenRefresher.swift      # OAuth token refresh
├── UsageClient.swift         # Usage endpoint request
├── Models.swift              # Decodable models + date parsing
├── PopoverView.swift         # Popover UI
├── LabelRenderer.swift       # Color menu bar label (NSImage)
├── NotificationManager.swift # Threshold notifications
└── LaunchAtLogin.swift       # SMAppService integration
```

## Architecture notes

- **No App Sandbox.** A sandboxed app cannot read another app's (Claude Code's) Keychain item, which would break the app's entire purpose. `project.yml` deliberately ships no entitlements.
- **Color menu bar label.** `MenuBarExtra` renders `Text`/SF Symbols as monochrome template images. `LabelRenderer` works around this by rendering a SwiftUI view to an `NSImage` with `isTemplate = false` to preserve color.
- **`User-Agent` is mandatory.** Without a `claude-code/<version>` user-agent, the usage endpoint serves an aggressively rate-limited (429) bucket.

## Notes

- **If the token expires** ("Token expired" message): run any Claude Code command and the token gets refreshed in the Keychain.
- With ad-hoc signing, macOS may re-prompt for Keychain access after every rebuild. Signing with a stable developer certificate stops the re-prompts.

## Disclaimer

Not an official Anthropic product. It uses the undocumented usage endpoint that Claude Code relies on; that endpoint may change.
