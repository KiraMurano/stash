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
# Normally SwiftPM builds the binary, universal. Without Xcode it cannot: the Command Line
# Tools ship libPackageDescription.dylib but not the module interface beside it, and SwiftPM
# has to compile Package.swift to read it — so `swift build` fails on every manifest, not
# just this one. There the sources are handed straight to swiftc instead, for this Mac's own
# architecture, which is all such a machine can run anyway.
ARCHS=(--arch arm64 --arch x86_64)
# `dump-package` is the probe that tells the truth: it has to parse the manifest, while
# `--show-bin-path` only works a path out and succeeds even where nothing can be built.
if swift package dump-package >/dev/null 2>&1; then
    swift build -c release "${ARCHS[@]}"
    BIN_DIR="$(swift build -c release "${ARCHS[@]}" --show-bin-path)"
else
    echo "note: SwiftPM cannot read the manifest (no Xcode); compiling with swiftc." >&2
    DEPLOYMENT="$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$ROOT_DIR/Info.plist")"
    BIN_DIR="$ROOT_DIR/.build/direct"
    mkdir -p "$BIN_DIR"
    find "$ROOT_DIR/Sources/BufferJournal" -name '*.swift' > "$BIN_DIR/sources.txt"
    swiftc -O -target "$(uname -m)-apple-macos$DEPLOYMENT" -module-name BufferJournal \
        -parse-as-library @"$BIN_DIR/sources.txt" -o "$BIN_DIR/BufferJournal"
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$CONTENTS_DIR/Resources"
cp "$BIN_DIR/BufferJournal" "$MACOS_DIR/BufferJournal"
cp "Info.plist" "$CONTENTS_DIR/Info.plist"
cp "Resources/AppIcon.icns" "Resources/StatusIcon.png" "Resources/StatusIcon@2x.png" "$CONTENTS_DIR/Resources/"
# The About screen sets the wordmark in Booker Display. Its licence allows the file inside an
# app, but only travelling together with the licence itself, so both go into the bundle.
cp -R "Resources/Fonts" "$CONTENTS_DIR/Resources/Fonts"

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
    # plutil, not PlistBuddy: PlistBuddy parses its own command line and eats the quotes around
    # the identifier, leaving a requirement codesign cannot read.
    plutil -replace StashUpdateRequirement -string "$REQUIREMENT" "$CONTENTS_DIR/Info.plist"
    codesign --force --deep --sign "$IDENTITY" "$APP_DIR"
else
    echo "warning: no '$IDENTITY' certificate in the keychain; signing ad hoc." >&2
    echo "warning: this build will not offer updates. See README, \"Signing\"." >&2
    codesign --force --deep --sign - "$APP_DIR"
fi
echo "$APP_DIR"
