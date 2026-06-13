# Buffer Journal

Minimal macOS clipboard history app inspired by Windows clipboard journal.

## Features

- Global `Option+V` shortcut opens the journal.
- Text and images are saved from the system pasteboard.
- Selecting an item replaces the current pasteboard content and sends `Cmd+V`.
- History is stored locally in `~/Library/Application Support/BufferJournal`.
- The app runs as a menu bar accessory with a compact glass-style SwiftUI panel.

## Build

```bash
Scripts/build_app.sh
```

The app bundle is created at:

```text
.build/Buffer Journal.app
```

## Run

Open the generated app bundle. On first paste action, macOS may ask for Accessibility permission so Buffer Journal can send the synthetic `Cmd+V` event.

If the prompt does not appear, enable the app manually:

```text
System Settings -> Privacy & Security -> Accessibility -> Buffer Journal
```

After permission is granted, copy text or an image, press `Option+V`, choose an item, and it will be pasted into the active app.
