
# Pomodoro Menu Bar App — Build Spec for Claude Code

## Goal
Build a native macOS Pomodoro timer app in SwiftUI with a `MenuBarExtra` front-end, Slack status + DND sync, and local CSV stats. Target macOS 26+ (Tahoe) so `MenuBarExtra` with `.window` style is available. No App Store distribution — ship as a signed (ad-hoc is fine) `.dmg` and optionally a Homebrew cask.

I have Xcode installed. Scaffold the whole project, build it, and leave me with a runnable `.app` and a `Makefile`/script that produces a `.dmg`.

## Tech constraints
- **Language/UI:** Swift 5.9+, SwiftUI only. No AppKit except where unavoidable (e.g., `NSWorkspace` for opening URLs, `LSUIElement` for hiding the Dock icon).
- **Architecture:** MVVM. One `TimerEngine` (ObservableObject) as the single source of truth, injected into the menu bar view and the settings window.
- **Persistence:** 
  - Settings → `UserDefaults` via `@AppStorage`.
  - Stats → CSV at `~/Library/Application Support/Pomo/stats.csv` (create dir if missing).
  - Slack token → **Keychain** (never UserDefaults, never CSV, never logs).
- **Concurrency:** Timer driven by a single `Task` loop using `ContinuousClock` / `Date` deltas — **not** `Timer.scheduledTimer`, so it stays accurate if the app is backgrounded or the Mac sleeps. On resume, recompute remaining time from the phase's absolute end date.
- **App shell:** `LSUIElement = true` in Info.plist (menu bar only, no Dock icon). Settings window opens via `Settings { ... }` scene.

## Session model

```swift
enum SessionType {
    case regularFocus     // 25 min, 🍅
    case deepFocus        // 50 min, 🧠
    case shortBreak       // 5 min,  ☕️
    case longBreak        // configurable, 🌿
}
```

- **Default cycle:** 4× (regular focus → short break) → long break → repeat.
- **Deep focus** is a one-off the user triggers manually; it's followed by a 15-min break (configurable) and does **not** count toward the 4-pomo cycle by default (expose a toggle: "Count deep focus toward cycle").
- **Skip:** every phase has a Skip action. Skipping ends the phase immediately, logs it as `skipped`, and advances to the next phase.
- **Pause/Resume** and **Reset cycle** also required.

## Settings (all live-editable, persisted via `@AppStorage`)
- Regular focus duration (default 25 min)
- Short break duration (default 5 min)
- Deep focus duration (default 50 min)
- Deep focus break duration (default 15 min)
- Long break duration (default 15 min, user-configurable — you asked for this)
- Pomos per cycle before long break (default 4)
- Count deep focus toward cycle (default off)
- Auto-start next phase (default on)
- Play sound on phase end (default on) — use `NSSound(named: "Glass")`
- Slack: token field (stored in Keychain), enabled toggle, "Sync status on every phase" toggle, "Enable DND for deep focus only" toggle
- Emoji per session type (pre-filled, editable)

## Menu bar UI (`MenuBarExtra`)
- **Label:** `{emoji} {MM:SS}` during a session, `🍅 Pomo` when idle. Use `.systemImage` fallback if emoji rendering is an issue; prefer the emoji-in-Text approach via a custom label view.
- **Popover content:**
  - Current session type + time remaining (large).
  - Progress ring (use `Circle().trim(...)`).
  - Buttons: Start Regular 🍅, Start Deep Focus 🧠, Pause/Resume, Skip, Reset.
  - Today's stats summary: pomos completed, deep focus completed, total focused minutes.
  - "Open Settings…" and "Quit".
- Keep the popover under ~320pt wide.

## Slack integration (user token approach)

Use a Slack **user token** (xoxp-…) created via a personal Slack app with these user scopes: `users.profile:write`, `dnd:write`. Store in Keychain. Provide a settings field + a "Test connection" button that calls `auth.test`.

Endpoints to call (all `POST`, `Authorization: Bearer <token>`, JSON body):

| Event | Call |
|---|---|
| Regular focus start | `users.profile.set` → status_text="Focusing", status_emoji=":tomato:", status_expiration=end_epoch |
| Deep focus start | `users.profile.set` (🧠 / "Deep focus — do not disturb") **and** `dnd.setSnooze?num_minutes=<duration>` |
| Short break start | `users.profile.set` (☕️ / "On a break") |
| Long break start | `users.profile.set` (🌿 / "On a long break") |
| Any session end / app quit | `users.profile.set` with empty status; if DND was set, `dnd.endSnooze` |

Make Slack calls **fire-and-forget** on a background task; never block the timer. Log failures locally (don't surface scary errors in the menu bar — a small ⚠︎ badge in the popover is enough). Emojis are user-editable in settings; the defaults above are sensible starting points.

Put all Slack code behind a `SlackClient` protocol so it's trivial to stub in tests.

## Stats CSV

Path: `~/Library/Application Support/Pomo/stats.csv`. Append-only. Header row on first write:

```
date,start_time,end_time,type,planned_minutes,actual_minutes,status,task
```

- `date` → `YYYY-MM-DD` in local tz
- `start_time`, `end_time` → ISO-8601 local
- `type` → `regular|deep|short_break|long_break`
- `status` → `completed|skipped`
- `task` → optional free text; prompt for it (optional, dismissable) when starting a focus session — **not** on breaks. Escape commas/quotes properly (wrap in quotes, double internal quotes).

Expose a "Reveal stats in Finder" button in settings.

## Project layout

```
Pomo/
├── Pomo.xcodeproj
├── Pomo/
│   ├── PomoApp.swift              // @main, MenuBarExtra + Settings scenes
│   ├── Models/
│   │   ├── SessionType.swift
│   │   ├── Session.swift          // start/end/type/task/status
│   │   └── AppSettings.swift      // @AppStorage wrapper
│   ├── Core/
│   │   ├── TimerEngine.swift      // ObservableObject, the brain
│   │   ├── CycleController.swift  // regular→short×N→long logic
│   │   └── SoundPlayer.swift
│   ├── Integrations/
│   │   ├── SlackClient.swift      // protocol
│   │   ├── LiveSlackClient.swift  // URLSession impl
│   │   └── KeychainStore.swift
│   ├── Persistence/
│   │   └── StatsCSVStore.swift
│   ├── Views/
│   │   ├── MenuBarLabel.swift
│   │   ├── MenuBarContent.swift
│   │   ├── SettingsView.swift
│   │   └── ProgressRing.swift
│   └── Resources/
│       ├── Info.plist             // LSUIElement=YES
│       └── Assets.xcassets
├── PomoTests/
│   ├── TimerEngineTests.swift     // pause/resume/skip/long-break rollover
│   ├── CycleControllerTests.swift
│   ├── StatsCSVStoreTests.swift   // escaping, append, header
│   └── SlackClientTests.swift     // stub client, verify payloads
├── scripts/
│   ├── build-release.sh           // xcodebuild -configuration Release
│   └── make-dmg.sh                // create-dmg or hdiutil
├── Makefile                       // `make run`, `make test`, `make dmg`
└── README.md
```

## Testing (do this, don't skip)
- `TimerEngine` must be tested with an injected clock — no real time in tests.
- Verify: pause preserves remaining, skip logs `skipped` and advances, completing 4 regular pomos triggers long break, deep focus does not advance the cycle by default.
- `StatsCSVStore`: header written once, tasks with commas/quotes/newlines survive a round-trip.
- `SlackClient`: capture the `URLRequest`s against a fake and assert body JSON + headers.
- Run `xcodebuild test -scheme Pomo -destination 'platform=macOS'` as the last step of scaffolding and make it pass.

## Distribution

- `scripts/build-release.sh` → Release build, ad-hoc sign (`codesign --sign -`), export `.app` to `build/`.
- `scripts/make-dmg.sh` → prefer [`create-dmg`](https://github.com/create-dmg/create-dmg) if installed, else fall back to `hdiutil create` with a simple layout. Output: `build/Pomo-<version>.dmg`.
- Generate a Homebrew cask stub at `homebrew/Casks/pomo.rb` that points at a local path (user replaces with a release URL later). Don't try to publish it.
- README should explain: how to run from Xcode, how to build the DMG, how to install via `brew install --cask ./homebrew/Casks/pomo.rb`, and how to create the Slack user token (with the two scopes above).

## Acceptance checklist (verify before handing back)
1. `make run` launches the app, no Dock icon appears, menu bar shows 🍅 Pomo.
2. Click menu bar → popover opens → "Start Regular" begins a 25:00 countdown visible in the menu bar label.
3. Skip advances phase; a row appears in `stats.csv` with `status=skipped`.
4. Completing a regular focus writes `status=completed` and auto-advances to short break.
5. After 4 regular focuses, long break is scheduled with the configured duration.
6. Starting deep focus with a valid Slack token sets status to 🧠 and enables DND for the session duration; ending clears both.
7. Quitting the app clears Slack status and ends DND if active.
8. `make test` passes. `make dmg` produces a working `Pomo-<version>.dmg`.


---

Scaffold the project, implement everything above, run the tests, build the DMG, and then show me the tree + the last 30 lines of the test output.

---

A couple of notes on why I drafted it this way, in case you want to tweak before pasting:

- I pinned the **timer to wall-clock deltas** rather than tick counting — this is the single most common way these apps go wrong when the Mac sleeps mid-pomo.
- I made the Slack token **Keychain-only** and ring-fenced behind a protocol; it's a nice boundary and makes the tests clean.
- I left the **long-break default at 15 min** but fully configurable, per your answer.
- The **task label** is prompted but dismissable so you can start a pomo in one click when you don't care. If you'd rather never be prompted, say the word and I'll strip that.
