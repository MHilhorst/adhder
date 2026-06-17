#!/bin/bash
# Builds, Developer ID-signs, notarizes, and staples a distributable DMG.
#
# Prerequisites (one-time, done by you so secrets never leave your machine):
#   1. Install a "Developer ID Application" certificate (Xcode > Settings >
#      Accounts > Manage Certificates > + Developer ID Application).
#   2. Store notarization credentials in a keychain profile named "adhder-notary":
#        xcrun notarytool store-credentials adhder-notary \
#          --apple-id "you@example.com" \
#          --team-id "YOURTEAMID" \
#          --password "app-specific-password"
#      (or use --key/--key-id/--issuer for an App Store Connect API key)
#
# Usage:
#   CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
#     ./scripts/notarize.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

: "${CODESIGN_IDENTITY:?Set CODESIGN_IDENTITY to your 'Developer ID Application: ...' identity}"
PROFILE="${NOTARY_PROFILE:-adhder-notary}"

APP="$ROOT/build/Adhder.app"
DIST="$ROOT/dist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/scripts/Info.plist" 2>/dev/null || echo 1.0)"
DMG="$DIST/Adhder-$VERSION.dmg"

echo "==> Building + Developer ID signing"
CODESIGN_IDENTITY="$CODESIGN_IDENTITY" "$ROOT/scripts/build_app.sh" release >/dev/null

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP"

mkdir -p "$DIST"
echo "==> Building DMG"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Adhder" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

echo "==> Signing DMG"
codesign --force --sign "$CODESIGN_IDENTITY" --timestamp "$DMG"

echo "==> Submitting to Apple notary service (this can take a few minutes)"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait

echo "==> Stapling ticket"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo "==> Done: $DMG (signed + notarized + stapled)"
