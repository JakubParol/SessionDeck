#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="SessionDeck"
BUNDLE_IDENTIFIER="local.SessionDeck"
BUNDLE_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
EXECUTABLE_PATH="$ROOT_DIR/.build/debug/$APP_NAME"

cd "$ROOT_DIR"

if pgrep -x "$APP_NAME" >/dev/null; then
  pkill -x "$APP_NAME"
  sleep 0.2
fi

swift build

case "$BUNDLE_DIR" in
  "$ROOT_DIR"/dist/*.app) rm -rf "$BUNDLE_DIR" ;;
  *) echo "Refusing to remove unexpected bundle path: $BUNDLE_DIR" >&2; exit 1 ;;
esac

mkdir -p "$MACOS_DIR"
cp "$EXECUTABLE_PATH" "$MACOS_DIR/$APP_NAME"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_IDENTIFIER</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

/usr/bin/open -n "$BUNDLE_DIR"
