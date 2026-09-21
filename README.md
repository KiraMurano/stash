# Stash

Stash is a minimal macOS clipboard history app inspired by Windows clipboard journal.

## Features

- Global `Option+V` shortcut opens the journal.
- Text and images are saved from the system pasteboard.
- The journal is split: clips on the left, the selected clip in full on the right. Hover a clip and press the orange return button, double-click it, or press Paste to paste it where your cursor is; the copy button next to Paste only puts it on the pasteboard. Drag the divider to resize the list; clicking an image opens it in Preview. The journal never takes the keyboard: whatever you type goes to the app you are typing in, and a click anywhere outside the journal closes it. While it is open, ↑/↓ move the selection, Return pastes and Esc closes it; switch `Intercept Keys` off in the menu to leave those keys to your app too and work the journal with the mouse.
- The journal opens next to the text cursor of the app you are typing in, like Win+V: under the caret, or above it when there is no room below. Where an app does not report its caret (Electron apps, terminals) the journal opens next to the focused field, and failing that where you last left it.
- Menu settings open the journal at the cursor (`Open at the Cursor`, on by default), close it after a paste or copy, take or leave the journal's keys (`Intercept Keys`, on by default), and switch theme and interface language (System, English, Русский).
- A short tour opens in a window of its own, in the middle of the screen, on the first launch and walks through the journal in five slides. Closing it leaves nothing behind: the journal is not what was asked for. It takes no keys at all — click the window's left third to go back, the rest to go on, or use the button and the close cross; everything you type keeps going to the app underneath. `How to Use Stash?` in the menu bar menu plays it again. The default theme is Stash Auto.
- `About Stash` in the menu bar menu opens a window under the menu bar icon with the app's version, the studio's wordmark set in Booker Display — its letters change their form on their own — and a link to the repository.
- History keeps up to 20 clips for 24 hours and is stored locally in `~/Library/Application Support/BufferJournal`.
- The app runs as a menu bar accessory with a frosted-glass SwiftUI panel with orange accents. The app icon is built from `Resources/AppIconSource.png` with `swift Scripts/make_icon.swift`; the menu bar icon is built from `Resources/StatusIconSource.png` with `swift Scripts/make_status_icon.swift`.

## Install

Download `Stash-<version>.dmg` from [Releases](https://github.com/KiraMurano/stash/releases), open it and drag `Stash.app` onto the Applications folder. The app is not notarized, so macOS blocks the first launch: click Done, then open System Settings → Privacy & Security, scroll down and click Open Anyway next to Stash. Or run `xattr -dr com.apple.quarantine /Applications/Stash.app`. Stash needs Accessibility access to paste (System Settings → Privacy & Security → Accessibility); until it has it, the panel shows the tour's access slide on its own, with a button that opens those settings. Stash is signed with a self-signed certificate, so its identity stays the same from release to release and the Accessibility permission survives an update. The one exception is the release that introduced updating: the signature changed with it, so that permission has to be granted once more — remove the old Stash entry from the list with − and click Open Settings again.

## Updates

Stash checks GitHub for a new release ten seconds after it has settled — on the very first launch that means after the tour and after Accessibility access is granted — and once a day after that. A new version lights an orange dot on the menu bar icon and turns `Check for Updates…` into `Update to 1.27`; nothing pops up over what you are typing. The menu item opens a window under the menu bar icon, as tall as the release notes need, with a button that downloads the image, checks its signature, replaces the app and relaunches it; the download runs as a line above the button. `Check for Updates Automatically` in the same menu turns the daily check off; the menu item still works by hand.

A build made from source carries no release signature, so it offers no updates and both menu items are hidden.

## Build

```bash
Scripts/build_app.sh
```

The app bundle is created at:

```text
.build/Stash.app
```

The build is universal (Apple silicon and Intel).

The wordmark on the About screen is set in Booker Display, a typeface of ozero.digital. Its file lives in `Resources/Fonts` next to its licence, which allows the font inside an app as long as the two travel together; `Scripts/build_app.sh` copies both into the bundle, and `ATSApplicationFontsPath` in `Info.plist` has macOS register the font at launch.

### Signing

Releases are signed with a self-signed certificate named `Stash Updates`, not with an Apple Developer ID. It is free, and it is what keeps the app's identity — and with it the Accessibility permission — the same from build to build. Create it once in Keychain Access → Certificate Assistant → Create a Certificate: name `Stash Updates`, identity type Self Signed Root, certificate type Code Signing.

`Scripts/build_app.sh` signs with it, writes the matching requirement into the bundle as `StashUpdateRequirement`, and the updater checks every download against that requirement. Without the certificate the script warns and signs ad hoc, as before; such a build runs but offers no updates. Another name can be given with `STASH_SIGNING_IDENTITY`.

The app is still not notarized, so a DMG downloaded by hand is still blocked on first launch — the Install section says what to do about it.

## Versioning

Versions are `MAJOR.MINOR`. `MAJOR` is set by hand in the `VERSION` file. `MINOR` is a running release counter: every release takes the next number and it is not reset when `MAJOR` changes (0.25 → 1.26). Write the release notes first — they are shown inside the app, so they are sentences for a person, not a list of commits — then publish:

```bash
Scripts/release.sh docs/releases/v1.27.md
```

The notes file is required. `release.sh` copies it into `docs/releases/`, commits it, tags the release and uploads the DMG.

## Run

Open the generated app bundle. Copy text or an image, press `Option+V`, then double-click a clip: Stash pastes it into the app you are typing in by sending `Cmd+V`.

The app was previously called Buffer Journal. The bundle identifier (`local.buffer-journal`) and the storage folder (`~/Library/Application Support/BufferJournal`) keep their old names so settings and history carry over.
