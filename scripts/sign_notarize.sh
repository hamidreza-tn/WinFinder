#!/bin/bash
# Developer ID signing and notarization for CI release builds.
#
# Fully conditional: when the APPLE_* secrets are not configured in the
# repository, the script exits successfully and the build ships ad-hoc signed
# exactly as before. When they are, it signs the app with a Developer ID
# Application certificate, submits it to the Apple notary service, staples the
# ticket, and (for a DMG) staples the image directly.
#
# Required secrets:
#   APPLE_CERTIFICATE_P12        base64-encoded Developer ID Application .p12
#   APPLE_CERTIFICATE_PASSWORD   passphrase of the .p12
#   APPLE_NOTARY_ID              Apple ID used with notarytool
#   APPLE_NOTARY_PASSWORD        app-specific password for that Apple ID
#   APPLE_NOTARY_TEAMID          the Developer Team ID
#
# Usage: scripts/sign_notarize.sh app <path/to/WinFinder.app>
#        scripts/sign_notarize.sh dmg <path/to/WinFinder.dmg>
set -euo pipefail

MODE="${1:-}"
TARGET="${2:-}"

if [ "$MODE" != "app" ] && [ "$MODE" != "dmg" ]; then
    echo "usage: $0 app|dmg <path>" >&2
    exit 1
fi
[ -n "$TARGET" ] && [ -e "$TARGET" ] || { echo "error: target not found: $TARGET" >&2; exit 1; }

P12="${APPLE_CERTIFICATE_P12:-}"
P12_PASSWORD="${APPLE_CERTIFICATE_PASSWORD:-}"
NOTARY_ID="${APPLE_NOTARY_ID:-}"
NOTARY_PASSWORD="${APPLE_NOTARY_PASSWORD:-}"
NOTARY_TEAMID="${APPLE_NOTARY_TEAMID:-}"

if [ -z "$P12" ] || [ -z "$P12_PASSWORD" ] || [ -z "$NOTARY_ID" ] || [ -z "$NOTARY_PASSWORD" ] || [ -z "$NOTARY_TEAMID" ]; then
    echo "==> notarization secrets are not configured; shipping ad-hoc signed"
    exit 0
fi

KEYCHAIN="winfinder-notarize.keychain-db"
P12_FILE="$(mktemp -t winfinder-p12)"
ORIGINAL_KEYCHAINS="$(security list-keychains -d user | tr -d '\"' | tr '\n' ' ')"
KEYCHAIN_PASSWORD="$(openssl rand -hex 16)"

cleanup() {
    security list-keychains -d user -s $ORIGINAL_KEYCHAINS >/dev/null 2>&1 || true
    security delete-keychain "$KEYCHAIN" >/dev/null 2>&1 || true
    rm -f "$P12_FILE"
}
trap cleanup EXIT

printf '%s' "$P12" | base64 --decode > "$P12_FILE"

echo "==> importing the Developer ID certificate into a temporary keychain"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -t 3600 "$KEYCHAIN"
security import "$P12_FILE" -k "$KEYCHAIN" -P "$P12_PASSWORD" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null
security list-keychains -d user -s "$KEYCHAIN" $ORIGINAL_KEYCHAINS

IDENTITY_NAME="$(security find-identity -v -p codesigning "$KEYCHAIN" | awk -F'"' '/Developer ID Application/{print $2; exit}')"
[ -n "$IDENTITY_NAME" ] || { echo "error: no Developer ID Application identity in the imported certificate" >&2; exit 1; }
echo "==> identity: $IDENTITY_NAME"

notarize_and_staple() {
    local item="$1"
    local zip
    zip="$(mktemp -t winfinder-notary).zip"
    ditto -c -k --keepParent "$item" "$zip"
    echo "==> submitting to the Apple notary service (this can take a few minutes)"
    xcrun notarytool submit "$zip" \
        --apple-id "$NOTARY_ID" \
        --password "$NOTARY_PASSWORD" \
        --team-id "$NOTARY_TEAMID" \
        --wait
    rm -f "$zip"
    echo "==> stapling the notary ticket onto $item"
    xcrun stapler staple "$item"
    xcrun stapler validate "$item"
}

if [ "$MODE" = "app" ]; then
    echo "==> signing the app with a hardened runtime"
    codesign --force --sign "$IDENTITY_NAME" --options runtime --timestamp "$TARGET"
    codesign --verify --strict "$TARGET"
    notarize_and_staple "$TARGET"
else
    # The DMG already contains the signed/notarized app; notarize the image
    # itself so Gatekeeper accepts it without extra prompts.
    notarize_and_staple "$TARGET"
fi

echo "==> done: $TARGET is signed, notarized, and stapled"
