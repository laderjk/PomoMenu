#!/usr/bin/env bash
set -euo pipefail

# Package build/PomoMenu.app into build/PomoMenu-<version>.dmg.
# Prefers `create-dmg`; falls back to `hdiutil`.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
APP="$BUILD_DIR/PomoMenu.app"

if [ ! -d "$APP" ]; then
  echo "ERROR: $APP not found. Run scripts/build-release.sh first." >&2
  exit 1
fi

VERSION="$(defaults read "$APP/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "1.0")"
DMG_PATH="$BUILD_DIR/PomoMenu-$VERSION.dmg"
rm -f "$DMG_PATH"

if command -v create-dmg >/dev/null 2>&1; then
  echo "→ Building DMG with create-dmg"
  create-dmg \
    --volname "PomoMenu $VERSION" \
    --window-size 520 320 \
    --icon-size 96 \
    --icon "PomoMenu.app" 140 150 \
    --app-drop-link 380 150 \
    --hide-extension "PomoMenu.app" \
    --no-internet-enable \
    "$DMG_PATH" \
    "$APP"
else
  echo "→ create-dmg not found; using hdiutil fallback"
  STAGING="$(mktemp -d)"
  trap 'rm -rf "$STAGING"' EXIT
  cp -R "$APP" "$STAGING/"
  ln -s /Applications "$STAGING/Applications"
  hdiutil create \
    -volname "PomoMenu $VERSION" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG_PATH"
fi

echo "✅ DMG ready → $DMG_PATH"
