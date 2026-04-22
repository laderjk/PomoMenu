#!/usr/bin/env bash
set -euo pipefail

# Release build of PomoMenu.app with ad-hoc signing.
# Output: build/PomoMenu.app

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
DERIVED="$BUILD_DIR/DerivedData"
ARCHIVE_PATH="$BUILD_DIR/PomoMenu.xcarchive"
EXPORT_DIR="$BUILD_DIR"

mkdir -p "$BUILD_DIR"

echo "→ Cleaning previous build artifacts"
rm -rf "$ARCHIVE_PATH" "$BUILD_DIR/PomoMenu.app"

echo "→ Archiving PomoMenu (Release, ad-hoc sign)"
xcodebuild \
  -project "$PROJECT_ROOT/PomoMenu.xcodeproj" \
  -scheme PomoMenu \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED" \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  archive

APP_IN_ARCHIVE="$ARCHIVE_PATH/Products/Applications/PomoMenu.app"
if [ ! -d "$APP_IN_ARCHIVE" ]; then
  echo "ERROR: archive did not produce $APP_IN_ARCHIVE" >&2
  exit 1
fi

echo "→ Copying .app to $EXPORT_DIR"
rm -rf "$EXPORT_DIR/PomoMenu.app"
cp -R "$APP_IN_ARCHIVE" "$EXPORT_DIR/PomoMenu.app"

echo "→ Ad-hoc signing"
codesign --force --deep --sign - "$EXPORT_DIR/PomoMenu.app"
codesign --verify --verbose=2 "$EXPORT_DIR/PomoMenu.app" || true

echo "✅ Release build complete → $EXPORT_DIR/PomoMenu.app"
