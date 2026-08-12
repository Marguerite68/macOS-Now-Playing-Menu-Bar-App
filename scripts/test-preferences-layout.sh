#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_FILE="$SCRIPT_DIR/../Sources/NowPlayingBar/Views/PreferencesView.swift"

if rg -q 'LabeledContent\("最多字符数"\)' "$SOURCE_FILE"; then
    echo 'FAIL: maximum-character controls are still constrained by Form value-column layout'
    exit 1
fi

if rg -q 'TextField\("字符数"' "$SOURCE_FILE"; then
    echo 'FAIL: the character-count input still renders the 字符数 placeholder label'
    exit 1
fi

if ! rg -Uq 'HStack\(spacing: 8\) \{\n\s*Text\("最多字符数"\)' "$SOURCE_FILE"; then
    echo 'FAIL: maximum-character controls no longer have the expected horizontal layout'
    exit 1
fi

echo 'PASS: maximum-character controls use an unconstrained horizontal layout without a placeholder label'
