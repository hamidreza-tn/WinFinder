#!/bin/bash
# Builds the "Drag WinFinder to Applications" installer DMG.
#
# Dependency-free: only macOS built-ins (hdiutil, osascript, ditto). The
# layout (window size, background picture, icon positions) is applied to the
# mounted read-write image via Finder AppleScript and persisted in the
# volume's .DS_Store before compression.
#
# Usage: scripts/build_dmg.sh [app_path] [output.dmg] [background_png]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_PATH="${1:-$ROOT/.build/Build/Products/Release/WinFinder.app}"
OUTPUT="${2:-}"
BACKGROUND="${3:-$SCRIPT_DIR/dmg/background.png}"
VOLNAME="WinFinder"

[ -d "$APP_PATH" ] || { echo "error: app bundle not found: $APP_PATH" >&2; exit 1; }
[ -f "$BACKGROUND" ] || { echo "error: background PNG not found: $BACKGROUND (run: swift scripts/make_dmg_background.swift)" >&2; exit 1; }

if [ -z "$OUTPUT" ]; then
    VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo unknown)"
    OUTPUT="$ROOT/WinFinder-$VERSION.dmg"
fi

STAGING="$(mktemp -d -t winfinder-dmg.XXXXXX)"
RW_DMG="$STAGING/WinFinder-rw.dmg"
DEVICE=""
MOUNT=""

cleanup() {
    if [ -n "$MOUNT" ]; then
        hdiutil detach "$MOUNT" -force >/dev/null 2>&1 || true
    fi
    rm -rf "$STAGING"
}
trap cleanup EXIT

echo "==> staging app: $APP_PATH"
mkdir "$STAGING/payload"
ditto "$APP_PATH" "$STAGING/payload/WinFinder.app"
ln -s /Applications "$STAGING/payload/Applications"
mkdir "$STAGING/payload/.background"
cp "$BACKGROUND" "$STAGING/payload/.background/background.png"

# Confirm the staged app is at least ad-hoc signed, like the shipped builds.
codesign --verify "$STAGING/payload/WinFinder.app" 2>/dev/null \
    || echo "note: staged app is not code-signed"

echo "==> creating read-write image"
# No explicit -size: hdiutil sizes the image from the staged payload, so the
# script cannot fail when the app bundle grows.
hdiutil create -ov -quiet \
    -volname "$VOLNAME" \
    -srcfolder "$STAGING/payload" \
    -fs HFS+ \
    -format UDRW \
    "$RW_DMG"

echo "==> mounting"
ATTACH_OUTPUT="$(hdiutil attach "$RW_DMG" -readwrite -noautoopen)"
DEVICE="$(printf '%s' "$ATTACH_OUTPUT" | awk '/^\/dev\//{print $1; exit}')"
MOUNT="$(printf '%s' "$ATTACH_OUTPUT" | grep -o '/Volumes/.*$' | head -1)"
[ -n "$DEVICE" ] && [ -n "$MOUNT" ] || { echo "error: could not resolve mount point" >&2; exit 1; }

echo "==> applying Finder layout on $MOUNT"
# Layout constants match the background artwork's empty icon areas
# (660x510 pt window, app icon and Applications symlink centered at the
# left/right thirds, y=215, labels below at y≈330).
osascript <<EOF || { echo "error: Finder layout failed" >&2; exit 1; }
on closeVolumeWindows()
    tell application "Finder"
        repeat with w in windows
            try
                if (name of w as text) is "$VOLNAME" then close w
            end try
        end repeat
    end tell
end closeVolumeWindows

tell application "Finder"
    my closeVolumeWindows()
    delay 0.4
    set vol to disk "$VOLNAME"
    open vol
    delay 0.6
    set w to container window of vol
    with timeout of 10 seconds
        set w's current view to icon view
        set theViewOptions to icon view options of w
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 80
        set shows item info of theViewOptions to false
        set bounds of w to {160, 120, 820, 630}
        set background picture of theViewOptions to POSIX file ("$MOUNT/.background/background.png")
        set position of item "WinFinder.app" of w to {170, 215}
        set position of item "Applications" of w to {490, 215}
        set w's toolbar visible to false
        set w's statusbar visible to true
    end timeout
    delay 0.5
    close w
    delay 0.3
    open vol
    delay 0.6
    close container window of vol
end tell
EOF

# Sync so .DS_Store is flushed before detach.
sync
sleep 1

echo "==> detaching"
hdiutil detach "$DEVICE" -quiet >/dev/null 2>&1 || hdiutil detach "$MOUNT" -force >/dev/null 2>&1
MOUNT=""

echo "==> compressing to $OUTPUT"
rm -f "$OUTPUT"
hdiutil convert "$RW_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$OUTPUT" -quiet

echo "==> done: $OUTPUT"
