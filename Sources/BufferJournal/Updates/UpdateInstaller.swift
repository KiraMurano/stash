import AppKit
import Foundation

/// Stash cannot overwrite itself while it runs, so the swap is done by a detached script: the app
/// writes it, starts it and quits. Every path reaches the script through the environment — a path
/// with a space must not have to survive a round trip through quoting.
///
/// The image's signature is checked by the app before this runs (`UpdateController`); the script
/// checks it again, and checks the copied bundle, because by then the app is gone and nobody else
/// can.
enum UpdateInstaller {
    static let script = """
    #!/bin/bash
    # Swaps Stash for a freshly downloaded build. Started by the app just before it quits.
    set -u

    LOG="${STASH_LOG:-/dev/null}"
    MNT=""

    note() { printf '%s\\n' "$1" >>"$LOG" 2>/dev/null || true; }

    cleanup() {
        if [ -n "$MNT" ]; then
            /usr/bin/hdiutil detach "$MNT" -quiet 2>/dev/null \\
                || /usr/bin/hdiutil detach "$MNT" -force -quiet 2>/dev/null || true
            /bin/rmdir "$MNT" 2>/dev/null || true
        fi
        /bin/rm -rf "$(/usr/bin/dirname "$STASH_DMG")" 2>/dev/null || true
        /bin/rm -f "$0" 2>/dev/null || true
    }

    relaunch() {
        [ "${STASH_RELAUNCH:-1}" = "1" ] || return 0
        /usr/bin/open "$STASH_DEST" 2>/dev/null || true
    }

    fail() {
        note "$1"
        printf '%s\\n' "$1" >"$STASH_MARKER" 2>/dev/null || true
        cleanup
        relaunch
        exit 1
    }

    # 1. Wait for the app to go: at most ten seconds, then give up on waiting and try anyway.
    i=0
    while [ "$i" -lt 100 ]; do
        /bin/kill -0 "$STASH_PID" 2>/dev/null || break
        /bin/sleep 0.1
        i=$((i + 1))
    done

    # 2. The image must satisfy this build's requirement before it is even mounted.
    /usr/bin/codesign -v --strict -R="$STASH_REQUIREMENT" "$STASH_DMG" 2>>"$LOG" \\
        || fail "The downloaded image failed its signature check. Nothing was installed."

    MNT="$(/usr/bin/mktemp -d)" || fail "The update could not be mounted."
    /usr/bin/hdiutil attach "$STASH_DMG" -nobrowse -quiet -mountpoint "$MNT" 2>>"$LOG" \\
        || fail "The update could not be mounted."

    SRC="$MNT/$STASH_APP_NAME"
    [ -d "$SRC" ] || fail "The image holds no $STASH_APP_NAME."

    # 3. Copy beside the installed app, clear every xattr the DMG round trip leaves behind
    #    (quarantine and FinderInfo), then check the copy itself.
    STAGE="$STASH_DEST.update-new"
    /bin/rm -rf "$STAGE"
    /usr/bin/ditto "$SRC" "$STAGE" 2>>"$LOG" || fail "The new version could not be copied into place."
    /usr/bin/xattr -cr "$STAGE" 2>/dev/null || true

    if ! /usr/bin/codesign -v --deep --strict -R="$STASH_REQUIREMENT" "$STAGE" 2>>"$LOG"; then
        /bin/rm -rf "$STAGE"
        fail "The copied app failed its signature check. Nothing was installed."
    fi

    # 4. Swap. If the new version cannot take the old one's place, the old one goes back.
    /bin/rm -rf "$STASH_DEST".update-old.* 2>/dev/null || true
    BACKUP="$STASH_DEST.update-old.$$"
    if ! /bin/mv "$STASH_DEST" "$BACKUP"; then
        /bin/rm -rf "$STAGE"
        fail "The old version could not be moved aside."
    fi

    if ! /bin/mv "$STAGE" "$STASH_DEST"; then
        /bin/mv "$BACKUP" "$STASH_DEST" 2>/dev/null || true
        /bin/rm -rf "$STAGE"
        fail "The new version could not be put in place."
    fi

    /bin/rm -rf "$BACKUP"
    cleanup
    relaunch
    exit 0
    """

    static func environment(
        dmg: URL,
        destination: URL,
        requirement: String,
        pid: Int32,
        relaunch: Bool
    ) -> [String: String] {
        [
            "STASH_DMG": dmg.path,
            "STASH_DEST": destination.path,
            "STASH_APP_NAME": destination.lastPathComponent,
            "STASH_REQUIREMENT": requirement,
            "STASH_PID": String(pid),
            "STASH_MARKER": UpdateFailureMarker.url.path,
            "STASH_LOG": dmg.deletingLastPathComponent().appendingPathComponent("install.log").path,
            "STASH_RELAUNCH": relaunch ? "1" : "0",
        ]
    }

    /// Writes the script, starts it detached and returns. The caller quits the app right after:
    /// the script waits for this process to go before it touches anything.
    static func launch(dmg: URL, environment updates: UpdateEnvironment) throws {
        guard let requirement = updates.requirement else {
            throw UpdateError.install("This build carries no update requirement.")
        }

        let scriptURL = dmg.deletingLastPathComponent().appendingPathComponent("stash-update.sh")
        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        } catch {
            throw UpdateError.install("The install script could not be written.")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptURL.path]
        process.environment = ProcessInfo.processInfo.environment.merging(
            environment(
                dmg: dmg,
                destination: updates.bundleURL,
                requirement: requirement,
                pid: ProcessInfo.processInfo.processIdentifier,
                relaunch: true
            )
        ) { _, new in new }

        do {
            try process.run()
        } catch {
            throw UpdateError.install("The install script could not be started.")
        }
    }
}
