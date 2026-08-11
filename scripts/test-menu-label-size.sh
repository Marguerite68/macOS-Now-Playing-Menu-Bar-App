#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build/menu-label-test"
MODULE_CACHE_DIR="$BUILD_DIR/module-cache"
ARCHITECTURE="$(uname -m)"

mkdir -p "$MODULE_CACHE_DIR"

swiftc \
    -parse-as-library \
    -target "$ARCHITECTURE-apple-macosx13.0" \
    -vfsoverlay "$PROJECT_DIR/Resources/SwiftToolchainOverlay.yaml" \
    -module-cache-path "$MODULE_CACHE_DIR" \
    -o "$BUILD_DIR/MenuBarSizingHarness" \
    "$PROJECT_DIR/Sources/NowPlayingBar/Models/AppSettings.swift" \
    "$PROJECT_DIR/Sources/NowPlayingBar/Models/MediaInfo.swift" \
    "$PROJECT_DIR/Sources/NowPlayingBar/Utilities/MarqueeMetrics.swift" \
    "$PROJECT_DIR/Sources/NowPlayingBar/Views/MenuBarLabel.swift" \
    "$PROJECT_DIR/Sources/NowPlayingBar/Views/ScrollingTextView.swift" \
    "$PROJECT_DIR/scripts/MenuBarSizingHarness.swift"

"$BUILD_DIR/MenuBarSizingHarness"
