# twall

View SMS messages from all your Twilio numbers in one place, with per-number labels.

Designed for people who manage multiple accounts that each need their own phone number — so when a verification code comes in, you instantly know which account it's for.

```
2025-01-19 14:30:00  primary@gmail.com   +12025551234  Your Google verification code is 123456  [Google]
2025-01-19 13:15:00  work@gmail.com      +14155550101  2FA code: 789012                        [Google]
```

## Prerequisites

- macOS 14+ (Sonoma or later)
- [Xcode](https://apps.apple.com/us/app/xcode/id497799835) (latest stable)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — install via `brew install xcodegen`
- A [Twilio](https://www.twilio.com) account with at least one phone number provisioned

## Setup

### Credentials

Copy the example file and add your Twilio Account SID and Auth Token:

```bash
cp .env.example ~/.config/twall/.env
```

Edit `~/.config/twall/.env`:

```
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

You can find these in the [Twilio Console](https://console.twilio.com) under **Account** → **API keys & tokens**.

Credentials are read from `~/.config/twall/.env` (or `./.env` in the working directory) and from environment variables. The macOS GUI saves credentials to the same file via its Settings window.

### Labels (optional)

Map each Twilio number to the account it belongs to:

```json
{
  "+14155550101": "primary@gmail.com",
  "+14155550102": "backup@gmail.com",
  "+14155550103": "work@gmail.com"
}
```

Place this in `~/.config/twall/labels.json` or `./labels.json`. Both the CLI and GUI share this file.

## Build & Run — CLI

```bash
# Build the release binary
swift build -c release

# Copy it somewhere on your PATH
cp .build/release/twall /usr/local/bin/twall

# Run it
twall list
```

Or run directly without installing:

```bash
swift run twall list
```

## Build & Run — macOS GUI

The macOS app target is managed by an XcodeGen spec. Regenerate the Xcode project whenever source files are added or removed:

```bash
# Regenerate the Xcode project
xcodegen generate

# Build via command line
xcodebuild -project Twall.xcodeproj -target twall-app -configuration Debug build

# Open in Xcode (for development / running)
open Twall.xcodeproj
```

Then **Product → Run** in Xcode, or open the built app:

```bash
open build/Debug/twall-app.app
```

**First launch:** you'll be prompted to enter your Twilio credentials. Save them and the app will start fetching your messages.

## Usage — CLI

```
twall list          show all inbound SMS (default command)
twall latest        newest message per number
twall numbers       list your Twilio numbers + labels
twall label         manage number-to-account aliases
```

### Options

| Flag | Description |
|------|-------------|
| `-j, --json` | Output as JSON |
| `-n, --number` | Filter by label or E.164 |
| `-s, --since` | Recent only: `1h`, `30m`, `24h` |
| `-l, --limit` | Max messages |

### Label commands (CLI)

```
twall label set +14155550101 primary@gmail.com
twall label remove +14155550101
twall label list
twall label list --json
```

## Usage — macOS GUI

The macOS app provides a three-column NavigationSplitView:

| Column | Content |
|--------|---------|
| **Sidebar** | List of phone numbers with labels (select a number to filter, or "All Numbers") |
| **Message List** | Messages for the selected number, sorted newest-first. Unread messages have a blue dot. Pull to refresh. |
| **Detail** | Full message body, sender, timestamp, status. Google-tagged messages show a blue badge. |

### Toolbar

- **Refresh** (⌘R) — re-fetches messages from Twilio
- **Mark All Read** — clears all unread indicators and dock badge
- **Settings** (gear icon) — opens the Preferences window

### Preferences (⌘,)

Two tabs:

| Tab | Purpose |
|-----|---------|
| **Account** | View / edit Twilio credentials (saves to `~/.config/twall/.env`) |
| **Labels** | Add, edit, or delete number-to-account mappings (saves to `~/.config/twall/labels.json`) |

### Notifications

When a message matching the Google heuristic arrives, the app fires a system notification showing the verification code body. Requires notification permission (granted on first launch).

### Unread state

Unread SIDs persist in UserDefaults across app launches. The dock badge shows the unread count.

## Project structure

```
twall/
├── Package.swift          # Swift Package Manager (TwallCore + CLI)
├── project.yml            # XcodeGen spec (macOS GUI app)
├── Twall.xcodeproj/        # Generated Xcode project
│
├── Sources/
│   ├── TwallCore/          # Shared library (CLI + GUI)
│   │   ├── Config.swift        # .env + labels.json loading/saving
│   │   ├── Models.swift        # TwilioMessage, LabeledMessage, etc.
│   │   ├── TwilioClient.swift  # async actor wrapping Twilio REST API
│   │   └── MessageStore.swift  # fetch, label, filter, sort logic
│   └── twall/              # CLI executable (ArgumentParser)
│       └── main.swift
│
├── App/                   # macOS SwiftUI app sources
│   ├── App.swift              # @main entry point
│   ├── AppState.swift         # @Observable view model
│   ├── ContentView.swift      # NavigationSplitView (sidebar + list + detail)
│   ├── MessageDetailView.swift
│   ├── OnboardingView.swift   # First-launch credential sheet
│   ├── SettingsView.swift     # Tabbed preferences window
│   ├── LabelEditorView.swift  # Inline label editing
│   ├── UnreadStore.swift      # UserDefaults persistence
│   └── Info.plist
│
└── Tests/
    └── TwallCoreTests/     # Unit tests with mock HTTP
```

## Architecture

`TwallCore` is a standalone Swift library with no UI dependencies. It handles all Twilio API communication, message filtering, labeling, and config file management. Both the CLI (`twall`) and the macOS GUI (`twall-app`) import `TwallCore` and provide their own presentation layer.

This means adding other frontends (e.g., iOS, menu bar, widget) is just a matter of importing `TwallCore` and building the UI.
