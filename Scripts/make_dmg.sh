#!/usr/bin/env bash
# Packs .build/Stash.app into .build/Stash-<version>.dmg: a white window with an
# orange arc from Stash to an Applications shortcut, so installing is one drag.
# The window layout is written by dmgbuild (Finder scripting no longer keeps it
# on macOS 26); it is installed into .build/dmg-venv on first run.
# Usage: Scripts/make_dmg.sh <version>
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$1"
DMG="$ROOT_DIR/.build/Stash-$VERSION.dmg"
VENV="$ROOT_DIR/.build/dmg-venv"

if [[ ! -x "$VENV/bin/dmgbuild" ]]; then
    python3 -m venv "$VENV"
    "$VENV/bin/pip" install --quiet dmgbuild==1.6.7
fi

rm -f "$DMG"
"$VENV/bin/dmgbuild" -s "$ROOT_DIR/Scripts/dmg_settings.py" -D root="$ROOT_DIR" "Stash $VERSION" "$DMG" >/dev/null

# The image carries the app's identifier on purpose, so one requirement checks both the image and
# the bundle inside it.
IDENTITY="${STASH_SIGNING_IDENTITY:-Stash Updates}"
if security find-certificate -c "$IDENTITY" >/dev/null 2>&1; then
    codesign --force --sign "$IDENTITY" --identifier local.buffer-journal "$DMG"
else
    codesign --force --sign - --identifier local.buffer-journal "$DMG"
fi

echo "$DMG"
