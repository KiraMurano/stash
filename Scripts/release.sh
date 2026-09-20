#!/usr/bin/env bash
# Publishes a GitHub release as vMAJOR.MINOR.
# MAJOR is set by hand in the VERSION file. MINOR is a running counter across
# all releases: it is one more than the highest minor ever tagged and is never
# reset when MAJOR changes (0.25 → 1.26).
# Usage: Scripts/release.sh <release notes file>
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

NOTES="${1:-}"
if [[ -z "$NOTES" || ! -f "$NOTES" ]]; then
    echo "Usage: Scripts/release.sh <release notes file>" >&2
    echo "The notes are shown inside the app, so a generated list of commits will not do." >&2
    exit 1
fi

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
DMG="$(Scripts/make_dmg.sh "$VERSION")"

# The notes are kept with the code: they are what the update screen shows, and a release page can
# be edited afterwards while this copy stays as it shipped.
mkdir -p docs/releases
cp "$NOTES" "docs/releases/$TAG.md"
git add "docs/releases/$TAG.md"
git commit -m "Release notes for Stash $VERSION"
git push origin HEAD

git tag -a "$TAG" -m "Stash $VERSION"
git push origin "$TAG"

gh release create "$TAG" "$DMG" --title "Stash $VERSION" --notes-file "$NOTES"
