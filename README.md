# twall

View SMS messages from all your Twilio numbers in one place, with per-number labels.

Designed for people who manage multiple accounts that each need their own phone number — so when a verification code comes in, you instantly know which account it's for.

```
2025-01-19 14:30:00  primary@gmail.com   +12025551234  Your Google verification code is 123456  [Google]
2025-01-19 13:15:00  work@gmail.com      +14155550101  2FA code: 789012                        [Google]
```

## Usage

```
twall list          # show all inbound SMS (default command)
twall latest        # newest message per number
twall numbers       # list your Twilio numbers + labels
twall label         # manage number-to-account aliases
```

### Options

| Flag | Description |
|------|-------------|
| `-j, --json` | Output as JSON |
| `-n, --number` | Filter by label or E.164 |
| `-s, --since` | Recent only: `1h`, `30m`, `24h` |
| `-l, --limit` | Max messages |

### Label commands

```
twall label set +14155550101 primary@gmail.com
twall label remove +14155550101
twall label list
```

## Setup

1. Copy `.env.example` to `.env` and add your Twilio credentials:

```
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

2. Build and run:

```
swift build -c release
cp .build/release/twall /usr/local/bin/twall
twall list
```

Credentials are read from `.env` (local or `~/.config/twall/.env`) and environment variables.

Labels are stored in `labels.json` (local or `~/.config/twall/labels.json`) — managed via `twall label` commands or edited directly.

## Architecture

A Swift CLI with a shared `TwallCore` library target. The library has no UI dependencies and can be reused by a future SwiftUI macOS app.

```
Sources/
  TwallCore/       # Twilio REST client, message store, config
    Config.swift       # .env + labels.json loading/saving
    Models.swift       # TwilioMessage, LabeledMessage, etc.
    TwilioClient.swift # async actor wrapping Twilio API
    MessageStore.swift # fetch, label, filter, sort
  twall/           # CLI executable (ArgumentParser)
    main.swift
Tests/
  TwallCoreTests/  # unit tests with mock HTTP
```
