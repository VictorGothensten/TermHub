# TermHub

A native macOS terminal multiplexer. Manage multiple terminal sessions in a single window with tiled workspaces.

## Features

- **Tiled terminals** — 1 terminal fills the window, 2 split side-by-side, 3-4 form a 2x2 grid, and so on
- **Workspaces** — Tabs to organize terminals by project or task. Double-click to rename.
- **Zoom** — Double-click a tile header or use the zoom button to expand any terminal to full size
- **Archive sessions** — Save a terminal's full scrollback history to disk before closing. Reopen later with the working directory and history preserved.
- **Auto-naming** — Terminals pick up their title from the shell (current command, directory). Double-click to rename manually.
- **Persistence** — Workspace layout and archives survive app restarts
- **Quit protection** — Warns before closing if you have active sessions

## Install

Requires macOS 13+ and Xcode Command Line Tools.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/VictorGothensten/TermHub/main/install.sh)
```

Or manually:

```bash
git clone https://github.com/VictorGothensten/TermHub.git
cd TermHub
swift build -c release
cp .build/release/TermHub /usr/local/bin/termhub
```

## Usage

Launch from Spotlight, Finder (`/Applications/TermHub.app`), or terminal:

```bash
termhub
```

**Keyboard shortcuts:**
| Shortcut | Action |
|---|---|
| `Cmd+T` | New terminal |
| `Cmd+Shift+T` | New workspace |
| `Cmd+Q` | Quit (with confirmation) |
| `Esc` | Exit zoom / cancel rename |

**Mouse:**
| Action | Effect |
|---|---|
| Click tile | Focus terminal for typing |
| Double-click tile header | Zoom terminal |
| Double-click tile title | Rename terminal |
| Double-click workspace tab | Rename workspace |
| Hover tile | Show zoom / archive / close buttons |

## Uninstall

```bash
rm -rf /Applications/TermHub.app /usr/local/bin/termhub
rm -rf ~/Library/Application\ Support/TermHub
```

## How it works

TermHub is a native Swift/SwiftUI app that spawns real shell sessions (zsh/bash) via pseudo-terminals. Each tile is a full terminal emulator powered by [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm). There are no web views, no Electron, no network calls. Everything runs locally.

## Tech stack

- **Swift + SwiftUI + AppKit** — Native macOS, no cross-platform overhead
- **[SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)** (MIT) — Terminal emulation, PTY management, ANSI rendering

## License

MIT — see [LICENSE](LICENSE).

Third-party licenses: [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md).
