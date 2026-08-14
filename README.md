# Local Observer

A macOS app that quietly watches how you actually work, then tells you which parts of it could be handed to an AI.

It runs a background daemon that samples your screen every 30 seconds, OCRs it on-device, and stores the result in a local SQLite database. When you ask for it, a dashboard clusters those samples into work sessions, sends *text digests only* to the Claude API, and surfaces suggestions like "you LinkedIn-search every prospect before a sales call — here's a workflow that does it for you."

Nothing is analyzed until you press the button. No screenshots ever leave your machine.

## How it works

```
ObserverDaemon  ──►  ~/Library/Application Support/LocalObserver/
  every 30s            observer.sqlite      (captures, suggestions, workflows)
  screenshot           screenshots/*.jpg    (local only, purged after 14 days)
  + OCR + redact
                              │
                              ▼
ObserverDashboard  ──►  cluster into sessions  ──►  Claude API  ──►  suggestions
  (SwiftUI, manual)       (local, no network)      (text digests only)
```

**Capture loop** (`ObserverDaemon`) — every 30 seconds, if you're not idle, it grabs the frontmost app name, window title, browser URL (via AppleScript), and a screenshot. Vision framework OCRs the image locally, a regex pass redacts secrets, and the row lands in SQLite.

**Analysis** (`ObserverAnalyzer`) — runs only when you click *Analyze* in the dashboard. Captures from the last 7 days are clustered locally into sessions (same app/host, gaps under 5 minutes, sessions shorter than 60s dropped). Session digests go to Claude in two passes: Haiku labels each session in batches of 12, then Opus reads the labeled timeline and proposes workflows.

**Dashboard** (`ObserverDashboard`) — three tabs. *Overview* shows where your time went, *Suggestions* lists what Claude proposed (accept or dismiss), *Workflows* holds the ones you accepted.

## Privacy

This tool sees everything on your screen, so the defaults are deliberately conservative:

- **Screenshots never leave the machine.** Only text digests — app name, URL host and paths, window titles, and a ~200 character redacted OCR snippet per session — are sent to the Claude API.
- **Analysis is manual.** The daemon never calls out to the network. Nothing is sent until you click *Analyze*.
- **Apps are excluded by bundle ID** — 1Password, Keychain Access, and the login window are skipped entirely (`Sources/ObserverCore/Config.swift`).
- **URLs are excluded by host fragment** — anything containing `bank`, `chase.com`, `wellsfargo.com`, or `1password.com` is dropped before capture.
- **OCR text is redacted** before it's written to disk: emails, card numbers, SSNs, `password:`/`api_key:` lines, `sk-` keys, and long hex tokens.
- **Captures and screenshots are purged after 14 days**, checked once per day by the daemon.

Redaction is regex-based and best-effort — it is not a guarantee. If an app shows something you'd rather never be captured, add its bundle ID to `excludedBundleIDs`.

To wipe everything:

```sh
rm -rf ~/Library/Application\ Support/LocalObserver
```

## Requirements

- macOS 14 or later
- Swift 5.9+ toolchain (Xcode 15+ or Command Line Tools)
- An Anthropic API key, for analysis only — capture works without one

## Build

```sh
swift build -c release
```

Binaries land in `.build/release/ObserverDaemon` and `.build/release/ObserverDashboard`.

## Permissions

The daemon needs two macOS permissions, granted in **System Settings → Privacy & Security**:

| Permission | Used for |
|---|---|
| Screen Recording | screenshots |
| Accessibility | frontmost window title |
| Automation | browser URL via AppleScript — prompted on first use |

Run the daemon once and it prints a diagnostic showing which are granted:

```
[observer] permissions:
  Screen Recording: ✅
  Accessibility:    ❌
```

Grant whatever is missing, then restart it. Note that the permission is attached to the binary that asks for it, so grants may need redoing after a rebuild that moves the binary.

## Run

Start the capture daemon (Ctrl+C to stop):

```sh
.build/release/ObserverDaemon
```

It logs one line per capture. To run it in the background with a log file:

```sh
.build/release/ObserverDaemon >> ~/Library/Logs/local-observer.log 2>&1 &
```

Let it collect for a day or two, then open the dashboard. The API key is read from the environment at launch, so export it in the same shell:

```sh
export ANTHROPIC_API_KEY=sk-ant-...
.build/release/ObserverDashboard
```

If you launch the dashboard from Finder instead, it won't see the key and *Analyze* will tell you so — capture data still displays fine.

## Layout

| Target | What's in it |
|---|---|
| `ObserverCore` | `Config` (intervals, paths, exclusions), GRDB `Storage` + migrations, `Capture` / `Workflow` models |
| `ObserverDaemon` | capture loop, screenshot, Vision OCR, redaction, idle detection, browser URL, permission check |
| `ObserverAnalyzer` | session clustering, Anthropic Messages API client, Haiku labeling, Opus pattern detection |
| `ObserverDashboard` | SwiftUI app — overview, suggestions, workflows |

## Configuration

There is no config file yet. Tunables live in `Sources/ObserverCore/Config.swift`:

| Setting | Default |
|---|---|
| `captureIntervalSeconds` | 30 |
| `idleThresholdSeconds` | 120 |
| `retentionDays` | 30 |
| `screenshotMaxDimension` | 1920 |
| `jpegQuality` | 0.5 |
| `excludedBundleIDs` | 1Password, Keychain Access, login window |
| `excludedURLHostFragments` | `bank`, `chase.com`, `wellsfargo.com`, `1password.com` |

Analysis lookback (7 days), session gap (5 min), and labeling batch size (12) are currently constructor defaults in `AnalysisRunner`, `SessionClusterer`, and `LabelingService`.