#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

"$SCRIPT_DIR/build-app.sh" debug
open "$PROJECT_DIR/build/debug/NowPlayingBar.app"

APP_PID=""
for _ in {1..20}; do
    APP_PID="$(pgrep -x NowPlayingBar || true)"
    [[ -n "$APP_PID" ]] && break
    sleep 0.25
done

if [[ -z "$APP_PID" ]]; then
    echo "FAIL: NowPlayingBar did not launch"
    exit 1
fi

printf '\n>>> Click the NowPlayingBar menu item, then close and reopen it once.\n'
read -r -p "    [Press Enter when done] " _

BASE_RSS="$(ps -o rss= -p "$APP_PID" | tr -d ' ')"
PEAK_RSS="$BASE_RSS"

for _ in {1..15}; do
    CURRENT_RSS="$(ps -o rss= -p "$APP_PID" | tr -d ' ')"
    if [[ -z "$CURRENT_RSS" ]]; then
        echo "FAIL: process exited during sampling"
        exit 1
    fi
    (( CURRENT_RSS > PEAK_RSS )) && PEAK_RSS="$CURRENT_RSS"
    sleep 1
done

GROWTH_KB=$((PEAK_RSS - BASE_RSS))
printf 'BASE_RSS_KB=%s\n' "$BASE_RSS"
printf 'PEAK_RSS_KB=%s\n' "$PEAK_RSS"
printf 'GROWTH_KB=%s\n' "$GROWTH_KB"

if (( PEAK_RSS > 524288 || GROWTH_KB > 102400 )); then
    echo "FAIL: memory exceeded the 512 MB peak or 100 MB growth limit"
    exit 1
fi

echo "PASS: memory remained bounded after opening the menu"
