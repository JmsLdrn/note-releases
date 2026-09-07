# note-releases

Public download host for **Note** — the app that keeps you active in Slack and sounds an
alarm the moment a message arrives.

| Platform | Download | Source |
| --- | --- | --- |
| Windows | `Note.exe` from [Releases](https://github.com/JmsLdrn/note-releases/releases) — no installer, just run it | elsewhere |
| macOS 13+ | `Note-<version>-macos-universal.zip` from [Releases](https://github.com/JmsLdrn/note-releases/releases) | [`macos/`](macos/) |

The macOS build is a menu bar app: it posts a synthetic key press so Slack never sees the
Mac as idle, and rings when Slack's Dock badge picks up an unread. It needs the
Accessibility permission for both. See [`macos/README.md`](macos/README.md) for install
steps, the permission rationale, and how to build it.
