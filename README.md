# Stash

Stash is a minimal macOS clipboard history app inspired by Windows clipboard journal.

## Features

- Global `Option+V` shortcut opens the journal.
- Text and images are saved from the system pasteboard.
- Clicking an item replaces the current pasteboard content.
- Menu settings can also paste immediately after selection, close the journal after selection, and switch theme and interface language (System, English, Русский).
- History keeps up to 20 clips for 24 hours and is stored locally in `~/Library/Application Support/BufferJournal`.
- The app runs as a menu bar accessory with a compact glass-style SwiftUI panel. The app icon is built from `Resources/AppIconSource.png` with `swift Scripts/make_icon.swift`.

## Build

```bash
Scripts/build_app.sh
```

The app bundle is created at:

```text
.build/Stash.app
```

## Run

Open the generated app bundle. Copy text or an image, press `Option+V`, then click a card to copy it back into the system pasteboard. If `Paste on Selection` is enabled in the menu bar menu, Buffer Journal also sends `Cmd+V` without refocusing the target app.

The app was previously called Buffer Journal. The bundle identifier (`local.buffer-journal`) and the storage folder (`~/Library/Application Support/BufferJournal`) keep their old names so settings and history carry over.
