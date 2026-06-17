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

echo "==> Code signing (ad-hoc)"
codesign --force --sign - \
  --entitlements "$ROOT/scripts/Adhder.entitlements" \
  --options runtime \
  "$APP" 2>/dev/null || \
codesign --force --sign - \
  --entitlements "$ROOT/scripts/Adhder.entitlements" \
  "$APP"

echo "==> Done: $APP"
