#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MUSIC_SCRIPT="$PROJECT_DIR/Sources/NowPlayingBar/Resources/Scripts/ReadMusic.applescript"
PROVIDER="$PROJECT_DIR/Sources/NowPlayingBar/Providers/SystemNowPlayingProvider.swift"

if ! rg -q '^on run argv$' "$MUSIC_SCRIPT"; then
    echo 'FAIL: Music artwork script does not accept an app-controlled cache path'
    exit 1
fi

if ! rg -q 'raw data of artwork 1 of mediaTrack' "$MUSIC_SCRIPT"; then
    echo 'FAIL: Music artwork script does not export raw artwork data'
    exit 1
fi

if ! rg -q 'write artworkData to fileReference' "$MUSIC_SCRIPT"; then
    echo 'FAIL: Music artwork script does not write artwork to the cache file'
    exit 1
fi

if ! rg -q 'ArtworkCache.musicArtworkURL' "$PROVIDER"; then
    echo 'FAIL: provider does not supply a controlled artwork cache path to Music'
    exit 1
fi

echo 'PASS: Apple Music artwork is exported to the app-controlled cache path'
