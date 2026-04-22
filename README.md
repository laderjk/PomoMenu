# PomoMenu

A native macOS Pomodoro timer that lives in the menu bar, syncs your Slack
status + DND during sessions, and logs every session to a local CSV.

- **Menu bar title shows a live `🍅 MM:SS` countdown** that ticks every second
  without opening the popover.
- **Inline controls** — segmented Focus / Deep picker, a task field, and a
  Start button all live in the popover; no modal prompts.
- **Wall-clock anchored** — the timer is driven off absolute end dates, so it
  stays accurate if the Mac sleeps mid-pomodoro.
- **Slack integration** — user token stored in Keychain only.
- **Local CSV stats** at `~/Library/Application Support/Pomo/stats.csv`.

Requires **macOS 26 (Tahoe)** or later.

## Run from Xcode

```sh
open PomoMenu.xcodeproj
```

Then ⌘R. The app has no Dock icon — look for `🍅 25:00` in the menu bar.

Or from the command line:

```sh
make run
```

## Using the popover

Click the menu bar title to open the popover:

- **Focus / Deep** — segmented picker; pick one.
- **Task (optional)** — type a label for the session, or leave blank. Press
  `Enter` in this field to start immediately.
- **Start** — begins the selected session. Disabled while one is running.
- **Pause / Resume / Skip / Reset** — appear on the transport row once a
  session is running.
- **Open Settings…** — opens the Settings window (or press ⌘, once the
  popover is focused).
- **Quit** — clears any active Slack status / DND and exits.

## Build a `.dmg`

```sh
make dmg
```

This runs `scripts/build-release.sh` (Release build, ad-hoc signed) and then
`scripts/make-dmg.sh`, which prefers [`create-dmg`](https://github.com/create-dmg/create-dmg)
if installed and falls back to `hdiutil`. Output lands at
`build/PomoMenu-<version>.dmg`.

## Install via Homebrew (local cask)

After running `make dmg`:

```sh
brew install --cask ./homebrew/Casks/pomomenu.rb
```

The cask file points at `build/PomoMenu-<version>.dmg` by default. Replace the
`url` with a real release URL before publishing.

## Run the tests

```sh
make test
```

Scope:
- `TimerEngine` with an injected `MockClock` — pause preserves remaining time,
  skip logs `skipped`, 4 regular pomos triggers long break, deep focus does not
  advance the cycle by default.
- `CycleController` — full state machine.
- `StatsCSVStore` — header written once, commas/quotes/newlines round-trip.
- `SlackClient` — captures `URLRequest`s against a fake transport and asserts
  body JSON + `Authorization: Bearer` headers.

## Slack setup

Create a private Slack app at <https://api.slack.com/apps> and grant these
**user token scopes**:

- `users.profile:write`
- `dnd:write`

Install it to your workspace, copy the **User OAuth Token** (`xoxp-…`), and
paste it into the app's Settings → Slack tab. The token is stored in the macOS
Keychain — never in UserDefaults, never in the CSV, never in logs.

The "Test connection" button calls `auth.test` and reports the result.

### What gets called

| Event                         | Call                                                                                         |
| ----------------------------- | -------------------------------------------------------------------------------------------- |
| Regular focus start           | `users.profile.set` — `:tomato:` / "Focusing" with `status_expiration = end`                 |
| Deep focus start              | `users.profile.set` — `:brain:` / "Deep focus — do not disturb" + `dnd.setSnooze`            |
| Short / long break start      | `users.profile.set` — `:coffee:` / "On a break" or `:herb:` / "On a long break"              |
| Session end / app quit        | `users.profile.set` with empty profile; if DND was set, `dnd.endSnooze`                      |

Calls are fire-and-forget; failures surface as a ⚠︎ in the popover, never block
the timer.

## Stats CSV

`~/Library/Application Support/Pomo/stats.csv`, append-only:

```
date,start_time,end_time,type,planned_minutes,actual_minutes,status,task
```

- `type`: `regular` | `deep` | `short_break` | `long_break`
- `status`: `completed` | `skipped`
- `task`: optional free text, properly CSV-escaped.

## Project layout

```
PomoMenu/
├── PomoMenu.xcodeproj
├── PomoMenu/
│   ├── PomoMenuApp.swift           # @main — @NSApplicationDelegateAdaptor + Settings scene
│   ├── Models/                     # SessionType, Session, AppSettings
│   ├── Core/
│   │   ├── AppDelegate.swift       # NSStatusItem + NSPopover, title refresh
│   │   ├── Clock.swift
│   │   ├── CycleController.swift
│   │   ├── SoundPlayer.swift
│   │   └── TimerEngine.swift
│   ├── Integrations/               # SlackClient + LiveSlackClient, KeychainStore
│   ├── Persistence/                # StatsCSVStore
│   └── Views/                      # MenuBarContent, SettingsView, ProgressRing
├── PomoMenuTests/
│   ├── TimerEngineTests.swift
│   ├── CycleControllerTests.swift
│   ├── StatsCSVStoreTests.swift
│   ├── SlackClientTests.swift
│   └── TestHelpers.swift           # MockClock, CapturingSlackClient, etc.
├── scripts/
│   ├── build-release.sh
│   └── make-dmg.sh
├── homebrew/Casks/pomomenu.rb
├── Makefile
└── README.md
```

## Design notes

- **Menu bar via AppKit.** SwiftUI's `MenuBarExtra` label doesn't reliably
  update live, so `AppDelegate` owns an `NSStatusItem` + `NSPopover`. The
  status item's `attributedTitle` is rendered with
  `NSFont.monospacedDigitSystemFont` so the `MM:SS` countdown ticks in place
  without horizontal jitter. Refreshes are driven by `engine.objectWillChange`
  plus a 1 s fallback `Timer`.
- **TimerEngine** is an `ObservableObject`; `@Published` state (phase, remaining
  seconds, cycle state, today's stats) drives the popover. An internal tick
  task calls `tick()` every 250 ms, which recomputes
  `remainingSeconds = phaseEndDate - clock.now()`. Tests bypass the background
  task entirely (`enableBackgroundTick: false`) and call `tick()` after
  advancing a `MockClock`.
- **SlackClient** is a protocol behind `LiveSlackClient`; HTTP is injected via
  `HTTPTransport` so tests can capture every `URLRequest`.
- **KeychainStore** wraps `SecItem*` with a single service/account pair; the
  token is never held anywhere else.
- **App sandbox is disabled** so the stats path lands exactly where the spec
  says it should and keychain access stays simple. Ad-hoc signing is enough to
  make Gatekeeper happy for local/dev distribution.
