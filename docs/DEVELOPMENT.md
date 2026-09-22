# Building Stash

Everything here is for working on the app. If you only want to use it, the [README](../README.md) is enough.

## Build

```bash
Scripts/build_app.sh
```

The app bundle is created at:

```text
.build/Stash.app
```

The build is universal (Apple silicon and Intel).

A build made from source carries no release signature, so it offers no updates and both update items are hidden from the menu.

## Icons

The app icon is built from `Resources/AppIconSource.png`:

```bash
swift Scripts/make_icon.swift
```

The menu bar icon is built from `Resources/StatusIconSource.png`:

```bash
swift Scripts/make_status_icon.swift
```

## Fonts

The wordmark on the About screen is set in Booker Display, a typeface of ozero.digital. Its file lives in `Resources/Fonts` next to its licence, which allows the font inside an app as long as the two travel together; `Scripts/build_app.sh` copies both into the bundle, and `ATSApplicationFontsPath` in `Info.plist` has macOS register the font at launch.

## Signing

Releases are signed with a self-signed certificate named `Stash Updates`, not with an Apple Developer ID. It is free, and it is what keeps the app's identity — and with it the Accessibility permission — the same from build to build. Create it once in Keychain Access → Certificate Assistant → Create a Certificate: name `Stash Updates`, identity type Self Signed Root, certificate type Code Signing.

`Scripts/build_app.sh` signs with it, writes the matching requirement into the bundle as `StashUpdateRequirement`, and the updater checks every download against that requirement. Without the certificate the script warns and signs ad hoc, as before; such a build runs but offers no updates. Another name can be given with `STASH_SIGNING_IDENTITY`.

The app is still not notarized, so a DMG downloaded by hand is still blocked on first launch — the README's Install section says what to do about it.

## Versioning

Versions are `MAJOR.MINOR`. `MAJOR` is set by hand in the `VERSION` file. `MINOR` is a running release counter: every release takes the next number and it is not reset when `MAJOR` changes (0.25 → 1.26).

## Releasing

Write the release notes first — they are shown inside the app, so they are sentences for a person, not a list of commits — then publish:

```bash
Scripts/release.sh docs/releases/v1.27.md
```

The notes file is required. `release.sh` copies it into `docs/releases/`, commits it, tags the release and uploads the DMG.

## How updating works

Stash checks GitHub for a new release ten seconds after it has settled — on the very first launch that means after the tour and after Accessibility access is granted — and once a day after that. A new version lights an orange dot on the menu bar icon and turns `Check for Updates…` into `Update to 1.27`; nothing pops up over what you are typing. The menu item opens a window under the menu bar icon, as tall as the release notes need, with a button that downloads the image, checks its signature, replaces the app and relaunches it; the download runs as a line above the button. `Check for Updates Automatically` in the same menu turns the daily check off; the menu item still works by hand.

## The old name

The app was previously called Buffer Journal. The bundle identifier (`local.buffer-journal`) and the storage folder (`~/Library/Application Support/BufferJournal`) keep their old names so settings and history carry over.

## README artwork

The animations on the front page are hand-written SVG in `docs/assets/`: `hero.svg`, `open.svg`, `paste.svg`, `keys.svg`, `pin.svg` and the `download.svg` button. They animate with CSS inside the file, carry a light and a dark palette through `prefers-color-scheme`, and stop for `prefers-reduced-motion`. Their metrics follow `JournalView.Layout` and `ThemePalette`, so when the journal's look changes they should be edited to match.
