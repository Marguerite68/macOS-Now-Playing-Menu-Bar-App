#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ARTWORK_VIEW="$PROJECT_DIR/Sources/NowPlayingBar/Views/AlbumArtworkView.swift"

high_quality_interpolation_count="$(rg -c '\.interpolation\(\.high\)' "$ARTWORK_VIEW" || true)"
antialiasing_count="$(rg -c '\.antialiased\(true\)' "$ARTWORK_VIEW" || true)"
light_smoothing_count="$(rg -c '\.blur\(radius: 0\.25, opaque: false\)' "$ARTWORK_VIEW" || true)"
overscan_count="$(rg -c '\.scaleEffect\(1\.02\)' "$ARTWORK_VIEW" || true)"

if [[ "$high_quality_interpolation_count" -ne 2 ]]; then
    echo 'FAIL: local and remote artwork must both use high-quality interpolation'
    exit 1
fi

if [[ "$antialiasing_count" -ne 2 ]]; then
    echo 'FAIL: local and remote artwork must both enable antialiasing'
    exit 1
fi

if [[ "$light_smoothing_count" -ne 2 ]]; then
    echo 'FAIL: local and remote artwork must both apply transparent light smoothing'
    exit 1
fi

if [[ "$overscan_count" -ne 2 ]]; then
    echo 'FAIL: local and remote artwork must both overscan blurred edges before clipping'
    exit 1
fi

echo 'PASS: local and remote artwork use high-quality interpolation and edge-safe smoothing'
