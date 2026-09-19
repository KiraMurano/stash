# Stash

Stash is a minimal macOS clipboard history app inspired by Windows clipboard journal.

## Features

- Global `Option+V` shortcut opens the journal.
- Text and images are saved from the system pasteboard.
- The journal is split: clips on the left, the selected clip in full on the right. Hover a clip and press the orange return button, double-click it, or press Paste to paste it where your cursor is; the copy button next to Paste only puts it on the pasteboard. Drag the divider to resize the list; clicking an image opens it in Preview. The journal never takes the keyboard: whatever you type goes to the app you are typing in, and a click anywhere outside the journal closes it. While it is open, ↑/↓ move the selection, Return pastes and Esc closes it; switch `Intercept Keys` off in the menu to leave those keys to your app too and work the journal with the mouse.
- The journal opens next to the text cursor of the app you are typing in, like Win+V: under the caret, or above it when there is no room below. Where an app does not report its caret (Electron apps, terminals) the journal opens next to the focused field, and failing that where you last left it.
- Menu settings open the journal at the cursor (`Open at the Cursor`, on by default), close it after a paste or copy, take or leave the journal's keys (`Intercept Keys`, on by default), and switch theme and interface language (System, English, Русский).
- History keeps up to 20 clips for 24 hours and is stored locally in `~/Library/Application Support/BufferJournal`.
- The app runs as a menu bar accessory with a frosted-glass SwiftUI panel with orange accents. The app icon is built from `Resources/AppIconSource.png` with `swift Scripts/make_icon.swift`; the menu bar icon is built from `Resources/StatusIconSource.png` with `swift Scripts/make_status_icon.swift`.

## Install

Download `Stash-<version>.dmg` from [Releases](https://github.com/KiraMurano/stash/releases), open it and drag `Stash.app` onto the Applications folder. The app is not notarized, so macOS blocks the first launch: click Done, then open System Settings → Privacy & Security, scroll down and click Open Anyway next to Stash. Or run `xattr -dr com.apple.quarantine /Applications/Stash.app`. Stash needs Accessibility access to paste (System Settings → Privacy & Security → Accessibility); until it has it, the journal shows an access screen with a button that opens those settings. The app is signed ad hoc, so macOS treats every update as a new app: if the access screen stays although Stash is switched on, remove Stash from the list with − and click Open Settings again.

## Build

```bash
Scripts/build_app.sh
```

The app bundle is created at:

```text
.build/Stash.app
```

The build is universal (Apple silicon and Intel).

## Versioning

Versions are `MAJOR.MINOR`. `MAJOR` is set by hand in the `VERSION` file. `MINOR` is a running release counter: every release takes the next number and it is not reset when `MAJOR` changes (0.25 → 1.26). To publish a release:

```bash
Scripts/release.sh
```

## Run

Open the generated app bundle. Copy text or an image, press `Option+V`, then double-click a clip: Stash pastes it into the app you are typing in by sending `Cmd+V`.

The app was previously called Buffer Journal. The bundle identifier (`local.buffer-journal`) and the storage folder (`~/Library/Application Support/BufferJournal`) keep their old names so settings and history carry over.
