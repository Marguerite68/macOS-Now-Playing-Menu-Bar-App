#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIGURATION="${1:-debug}"
BUILD_ROOT="$PROJECT_DIR/.build"
MODULE_CACHE_DIR="$BUILD_ROOT/module-cache-vfs"
APP_DIR="$PROJECT_DIR/build/$CONFIGURATION/NowPlayingBar.app"
ARCHITECTURE="$(uname -m)"
SWIFT_FLAGS=(-parse-as-library -target "$ARCHITECTURE-apple-macosx13.0")

if [[ "$CONFIGURATION" == "release" ]]; then
    SWIFT_FLAGS+=(-O)
else
    SWIFT_FLAGS+=(-Onone -g)
fi

SOURCE_FILES=()
while IFS= read -r -d '' source_file; do
    SOURCE_FILES+=("$source_file")
done < <(find "$PROJECT_DIR/Sources/NowPlayingBar" -name '*.swift' -print0)

mkdir -p "$MODULE_CACHE_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources/Scripts"

swiftc \
    "${SWIFT_FLAGS[@]}" \
    -vfsoverlay "$PROJECT_DIR/Resources/SwiftToolchainOverlay.yaml" \
    -module-cache-path "$MODULE_CACHE_DIR" \
    -o "$APP_DIR/Contents/MacOS/NowPlayingBar" \
    "${SOURCE_FILES[@]}"

cp "$PROJECT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$PROJECT_DIR"/Sources/NowPlayingBar/Resources/Scripts/*.applescript "$APP_DIR/Contents/Resources/Scripts/"

if command -v codesign >/dev/null 2>&1; then
    codesign --force --sign - "$APP_DIR"
fi

echo "$APP_DIR"
