#!/bin/bash
# Builds the release app and packages it into a drag-to-install DMG and a zip.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP="$ROOT/build/Adhder.app"
DIST="$ROOT/dist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/scripts/Info.plist" 2>/dev/null || echo 1.0)"
DMG="$DIST/Adhder-$VERSION.dmg"
ZIP="$DIST/Adhder-$VERSION.zip"

echo "==> Building release app"
"$ROOT/scripts/build_app.sh" release >/dev/null

rm -rf "$DIST"
mkdir -p "$DIST"

echo "==> Creating zip"
( cd "$ROOT/build" && ditto -c -k --sequesterRsrc --keepParent "Adhder.app" "$ZIP" )

echo "==> Creating DMG"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Adhder" \
  -srcfolder "$STAGE" \
  -ov -format UDZO \
  "$DMG" >/dev/null
rm -rf "$STAGE"

echo "==> Done"
echo "    $DMG"
echo "    $ZIP"
ls -lh "$DMG" "$ZIP"
