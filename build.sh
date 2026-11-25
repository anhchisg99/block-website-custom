#!/bin/bash
# Builds build/WebBlocker.app (needs only Xcode Command Line Tools).
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/WebBlocker"

APP=build/WebBlocker.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/WebBlocker"
cp Support/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

echo "✅ Built $APP"
