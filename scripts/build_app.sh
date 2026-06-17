#!/bin/bash
# Builds Adhder.app: compiles the SwiftPM executable, assembles a .app bundle,
# embeds Info.plist, and ad-hoc code-signs it (required for EventKit TCC prompts).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIG="${1:-release}"
APP="$ROOT/build/Adhder.app"
CONTENTS="$APP/Contents"

echo "==> Building ($CONFIG)"
swift build -c "$CONFIG"

BIN="$(swift build -c "$CONFIG" --show-bin-path)/Adhder"
if [[ ! -f "$BIN" ]]; then
  echo "Build product not found at $BIN" >&2
  exit 1
fi

echo "==> Assembling bundle at $APP"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN" "$CONTENTS/MacOS/Adhder"
cp "$ROOT/scripts/Info.plist" "$CONTENTS/Info.plist"
printf 'APPL????' > "$CONTENTS/PkgInfo"

if [[ -f "$ROOT/scripts/AppIcon.icns" ]]; then
  cp "$ROOT/scripts/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
fi

# Use a Developer ID identity if provided (for notarization), else ad-hoc.
if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  echo "==> Code signing (Developer ID: $CODESIGN_IDENTITY)"
  codesign --force --deep --sign "$CODESIGN_IDENTITY" \
    --entitlements "$ROOT/scripts/Adhder.entitlements" \
    --options runtime --timestamp \
    "$APP"
else
  echo "==> Code signing (ad-hoc)"
  codesign --force --sign - \
    --entitlements "$ROOT/scripts/Adhder.entitlements" \
    --options runtime \
    "$APP" 2>/dev/null || \
  codesign --force --sign - \
    --entitlements "$ROOT/scripts/Adhder.entitlements" \
    "$APP"
fi

echo "==> Done: $APP"
