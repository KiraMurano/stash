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

# Stash is signed with a self-signed certificate, not a Developer ID. Gatekeeper still knows
# nothing about it, but the requirement below stays the same from build to build — so updates can
# be verified, and macOS keeps the Accessibility permission across them instead of treating every
# build as a new app.
IDENTITY="${STASH_SIGNING_IDENTITY:-Stash Updates}"
# `|| true`: without the certificate `security` fails, and under `set -euo pipefail` that would
# end the build instead of falling back to an ad hoc signature.
HASH="$(security find-certificate -c "$IDENTITY" -Z 2>/dev/null | awk '/SHA-1 hash:/ { print $3 }' | head -1 || true)"

if [[ -n "$HASH" ]]; then
    REQUIREMENT="identifier \"local.buffer-journal\" and certificate leaf H\"$HASH\""
    /usr/libexec/PlistBuddy -c "Add :StashUpdateRequirement string $REQUIREMENT" "$CONTENTS_DIR/Info.plist"
    codesign --force --deep --sign "$IDENTITY" "$APP_DIR"
else
    echo "warning: no '$IDENTITY' certificate in the keychain; signing ad hoc." >&2
    echo "warning: this build will not offer updates. See README, \"Signing\"." >&2
    codesign --force --deep --sign - "$APP_DIR"
fi
echo "$APP_DIR"
