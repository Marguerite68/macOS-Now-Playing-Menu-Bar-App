#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONTROLLER_FILE="$PROJECT_DIR/Sources/NowPlayingBar/StatusBar/DetailsPanelController.swift"
BUILD_DIR="$PROJECT_DIR/.build/details-panel-test"
MODULE_CACHE_DIR="$BUILD_DIR/module-cache"
ARCHITECTURE="$(uname -m)"

mkdir -p "$MODULE_CACHE_DIR"

if ! rg -q 'convertToScreen' "$CONTROLLER_FILE"; then
    echo 'FAIL: detail panel still uses status-button coordinates without converting them to screen coordinates'
    exit 1
fi

if ! rg -q 'containing: buttonFrame' "$CONTROLLER_FILE"; then
    echo 'FAIL: detail panel display is not selected from the status-button screen frame'
    exit 1
fi

if ! rg -q 'NSVisualEffectView' "$CONTROLLER_FILE" || \
   ! rg -q '\.material = \.popover' "$CONTROLLER_FILE" || \
   ! rg -q '\.blendingMode = \.behindWindow' "$CONTROLLER_FILE"; then
    echo 'FAIL: detail panel does not use the native behind-window popover material'
    exit 1
fi

if ! rg -q 'panel\.hasShadow = false' "$CONTROLLER_FILE"; then
    echo 'FAIL: detail panel still renders a rectangular system-window shadow'
    exit 1
fi

swiftc \
    -parse-as-library \
    -target "$ARCHITECTURE-apple-macosx13.0" \
    -vfsoverlay "$PROJECT_DIR/Resources/SwiftToolchainOverlay.yaml" \
    -module-cache-path "$MODULE_CACHE_DIR" \
    -o "$BUILD_DIR/DetailsPanelPlacementHarness" \
    "$PROJECT_DIR/Sources/NowPlayingBar/StatusBar/DetailsPanelPlacement.swift" \
    "$PROJECT_DIR/scripts/DetailsPanelPlacementHarness.swift"

"$BUILD_DIR/DetailsPanelPlacementHarness"
