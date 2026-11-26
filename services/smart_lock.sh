#!/usr/bin/env bash
# Smart idle auto-lock wrapper for hypridle:
# Skips automatic idle lock if inhibitWhenAudio is enabled in AruShell settings
# and audio/video is actively playing in PipeWire/PulseAudio.
set -euo pipefail

SETTINGS="${HOME}/.config/quickshell/AruShell/settings.json"
INHIBIT="true"
if [ -f "${SETTINGS}" ]; then
    INHIBIT="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print("true" if d.get("inhibitWhenAudio", True) else "false")' "${SETTINGS}" 2>/dev/null || echo "true")"
fi

if [ "${INHIBIT}" = "true" ]; then
    if command -v pactl >/dev/null 2>&1 && pactl list sink-inputs 2>/dev/null | grep -qi "State: RUNNING"; then
        exit 0
    fi
    if command -v playerctl >/dev/null 2>&1 && playerctl -a status 2>/dev/null | grep -q "^Playing$"; then
        exit 0
    fi
fi

exec quickshell ipc -c AruShell call lock lock
