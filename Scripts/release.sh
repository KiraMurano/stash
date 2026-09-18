#!/usr/bin/env bash
# Publishes a GitHub release as vMAJOR.MINOR.
# MAJOR is set by hand in the VERSION file. MINOR is a running counter across
# all releases: it is one more than the highest minor ever tagged and is never
# reset when MAJOR changes (0.25 → 1.26).
# Usage: Scripts/release.sh [release notes file]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -n "$(git status --porcelain)" ]]; then
    echo "Working tree is not clean" >&2
    exit 1
fi

git fetch --tags --quiet
MAJOR="$(tr -d '[:space:]' < VERSION)"
LAST_MINOR="$(git tag --list 'v*.*' | sed -nE 's/^v[0-9]+\.([0-9]+)$/\1/p' | sort -n | tail -1)"
MINOR=$(( ${LAST_MINOR:-0} + 1 ))
VERSION="$MAJOR.$MINOR"
TAG="v$VERSION"

Scripts/build_app.sh "$VERSION"
ZIP="$ROOT_DIR/.build/Stash-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$ROOT_DIR/.build/Stash.app" "$ZIP"

git tag -a "$TAG" -m "Stash $VERSION"
git push origin "$TAG"

if [[ -n "${1:-}" ]]; then
    gh release create "$TAG" "$ZIP" --title "Stash $VERSION" --notes-file "$1"
else
    gh release create "$TAG" "$ZIP" --title "Stash $VERSION" --generate-notes
fi
