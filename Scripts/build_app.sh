#!/usr/bin/env bash
# Builds .build/Stash.app. Pass a version (e.g. 0.3) to stamp it into the bundle;
# without one the bundle keeps the placeholder version from Info.plist.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/Stash.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
VERSION="${1:-}"

cd "$ROOT_DIR"
swift build -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$CONTENTS_DIR/Resources"
cp "$BIN_DIR/BufferJournal" "$MACOS_DIR/BufferJournal"
cp "Info.plist" "$CONTENTS_DIR/Info.plist"
cp "Resources/AppIcon.icns" "Resources/StatusIcon.png" "Resources/StatusIcon@2x.png" "$CONTENTS_DIR/Resources/"

if [[ -n "$VERSION" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS_DIR/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION#*.}" "$CONTENTS_DIR/Info.plist"
fi

codesign --force --deep --sign - "$APP_DIR"
echo "$APP_DIR"
