#!/bin/bash
# Renders the app icon master and compiles it into scripts/AppIcon.icns.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MASTER="$ROOT/assets/icon_master.png"
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"

echo "==> Rendering 1024px master"
swift build -c release >/dev/null
BIN="$(swift build -c release --show-bin-path)/Adhder"
mkdir -p "$ROOT/assets"
"$BIN" --icon "$MASTER"

echo "==> Generating iconset sizes"
gen() { sips -z "$2" "$2" "$MASTER" --out "$ICONSET/$1" >/dev/null; }
gen icon_16x16.png 16
gen icon_16x16@2x.png 32
gen icon_32x32.png 32
gen icon_32x32@2x.png 64
gen icon_128x128.png 128
gen icon_128x128@2x.png 256
gen icon_256x256.png 256
gen icon_256x256@2x.png 512
gen icon_512x512.png 512
cp "$MASTER" "$ICONSET/icon_512x512@2x.png"

echo "==> Compiling AppIcon.icns"
iconutil -c icns "$ICONSET" -o "$ROOT/scripts/AppIcon.icns"
echo "    $ROOT/scripts/AppIcon.icns"
ls -lh "$ROOT/scripts/AppIcon.icns"
