# Note for macOS

The Mac build of Note: it keeps your Mac marked **active** in Slack and sounds an
alarm the moment a message arrives. Menu bar only — no Dock icon, no window, no installer.

## Install

1. Download `Note-<version>-macos-universal.zip` from
   [Releases](https://github.com/JmsLdrn/note-releases/releases) and unzip it.
2. Drag `Note.app` to `/Applications`.
3. The app is signed ad-hoc, not notarised, so the first launch needs
   **right-click → Open → Open**. (Or run `xattr -dr com.apple.quarantine /Applications/Note.app`.)
4. Grant **Accessibility** when prompted — System Settings → Privacy & Security → Accessibility.
   Note asks once at launch; the menu also has a *Grant Accessibility permission…* item.

Requires macOS 13 (Ventura) or newer. Universal binary — Apple silicon and Intel.

## Why it needs Accessibility

Both halves of the app depend on it, and nothing else:

- **Staying active.** Slack decides you're away from the system-wide input idle timer.
  A power assertion stops sleep but never resets that timer, so Note posts a synthetic
  **F15** key press every two minutes — a key no modern keyboard has, that produces no
  text and is bound to nothing — plus an `IOPMAssertionDeclareUserActivity` declaration.
  Posting synthetic events requires Accessibility.
- **Hearing new messages.** Note reads Slack's **Dock badge** through the Accessibility
  API. That means no Slack token, no workspace admin, no Full Disk Access — and the alarm
  follows whatever notification preferences you already set in Slack, since the badge is
  Slack's own decision about what deserves your attention.

Note never reads message contents; it only sees the number on the Dock icon.

## Menu

| Item | What it does |
| --- | --- |
| Keep me active in Slack | The activity nudge. On by default. |
| Alarm on new message | Rings when Slack's badge appears or its count climbs. |
| Also keep the display awake | Optional — holds off display sleep too. Off by default. |
| Alarm sound | Submarine, Glass, Ping, Sosumi, Funk, Hero, Blow. |
| Stop alarm / Test alarm | Silence the current ring; hear the chosen sound. |
| Launch at login | Registers the app with `SMAppService`. |

The alarm loops until you stop it, or for 60 seconds, whichever comes first — so a Mac
left alone doesn't ring all afternoon. Reading Slack clears the badge; a falling count is
treated as you catching up, not as new traffic.

## Build from source

```sh
cd macos
bash scripts/build-app.sh 1.0.0
```

Produces `dist/Note.app`, a matching zip, and the SHA-256 for the release notes.
Needs the Xcode command line tools (`xcode-select --install`, Swift 5.9+).

A **universal** binary needs full Xcode, because SwiftPM builds two architectures
through `xcbuild`, which the Command Line Tools do not include. With CLT only, the
script says so and builds for your Mac's own architecture instead — which is all you
need to run Note locally. Release downloads are universal because CI builds them on a
runner with full Xcode.

Pushing a `v*` tag builds the same zip on a macOS runner and attaches it to the matching
GitHub release — see [`.github/workflows/build-macos.yml`](../.github/workflows/build-macos.yml).

## Known limits

- The badge is only readable while Slack has a Dock tile. If you run Slack with the Dock
  icon hidden, the alarm has nothing to watch (the activity nudge still works).
- Slack's badge is the trigger, so a message that Slack chooses not to badge — a muted
  channel, for instance — won't ring.
- macOS clears Accessibility permission when an app's signature changes, so re-granting
  after an upgrade is expected.
