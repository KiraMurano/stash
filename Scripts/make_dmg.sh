#!/usr/bin/env bash
# Packs .build/Stash.app into .build/Stash-<version>.dmg with an Applications
# shortcut, so installing is a drag onto the folder.
# Usage: Scripts/make_dmg.sh <version>
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$1"
DMG="$ROOT_DIR/.build/Stash-$VERSION.dmg"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

cp -R "$ROOT_DIR/.build/Stash.app" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG"
hdiutil create -volname "Stash $VERSION" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
echo "$DMG"
