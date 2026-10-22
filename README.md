# Clipboard History

A tiny macOS menu bar app (Swift + AppKit, no Xcode project needed). Press
your shortcut (default **⌘⇧V**), and a small popup shows your last 10 copies,
anchored near your text cursor — pick one (click, arrow keys + Return, or
press a digit `1`-`9`/`0` to jump straight to it) and it's pasted into
whatever you were typing in. Escape or clicking away dismisses it.

## Build & run

```bash
./build_app.sh
open ClipboardHistory.app
```

This compiles a release binary and wraps it into `ClipboardHistory.app`,
signed with a local dev identity (see below), in this folder. Drag it into
`/Applications` if you want it to stick around / launch at login via
System Settings → General → Login Items.

## Required permission

The app needs **Accessibility** access to:
- intercept the shortcut globally (so it works in any app, and doesn't also
  trigger a conflicting binding like "Paste and Match Style"),
- read the focused app's text-cursor position (to anchor the popup there),
  and
- simulate the paste keystroke when you pick an item.

On first launch, if it's not yet trusted, it opens
**System Settings → Privacy & Security → Accessibility** for you — add
`ClipboardHistory.app` there with the **+** button and enable it.

### Stable signing identity (already set up on this machine)

Rebuilding an ad-hoc signed app (`codesign --sign -`) changes its identity
every time, so macOS forgets the Accessibility grant on every rebuild. To
avoid that, this project is signed with a local self-signed "ClipboardHistory
Dev" code-signing certificate (already created in this Mac's login keychain).
`build_app.sh` uses it automatically — as long as you keep building on this
machine, Accessibility stays granted across rebuilds. On a different Mac,
you'd need to create that identity once (Keychain Access → Certificate
Assistant → Create a Certificate → type "Code Signing"), or just re-grant
Accessibility after each rebuild if you don't bother.

## Features

- **Configurable shortcut**: menu bar icon → **Settings… → General**. Click
  the shortcut field and press any key combo (with a modifier) — or an extra
  mouse button (middle click / side buttons, with or without modifiers) if
  your mouse has one.
- **About**: menu bar icon → **Settings… → About** — shows the app logo
  (`Resources/Logo.png`) and `developerName` from
  [AboutViewController.swift](Sources/ClipboardHistory/AboutViewController.swift).
- **Caret-aware positioning**: the popup tries to anchor right under your
  text cursor (via Accessibility), flipping above it or clamping to the
  screen edges when there isn't room (e.g. near the Dock or menu bar). Some
  apps — mainly Electron/web-based ones — don't expose reliable caret info;
  it falls back to your mouse position in that case.

## Notes / limitations

- History is plain text only, kept in memory (max 10 items, deduped), and is
  cleared when the app quits.
- Menu bar icon offers "Show History", "Clear History", "Settings…", and
  "Quit".
