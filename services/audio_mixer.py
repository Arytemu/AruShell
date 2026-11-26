#!/usr/bin/env python3
"""
AruShell Per-Application Audio Mixer (PipeWire / PulseAudio via pactl).
Commands:
  list           -> JSON list of active app audio streams [{id, name, volume, muted}]
  set <id> <pct> -> sets stream volume (0..150%)
  mute <id>      -> toggles stream mute
"""

import json
import re
import shutil
import subprocess
import sys


def list_streams() -> list:
    if not shutil.which("pactl"):
        return []
    try:
        res = subprocess.run(
            ["pactl", "list", "sink-inputs"],
            capture_output=True,
            text=True,
            timeout=2,
            env={**dict(**__import__("os").environ), "LC_ALL": "C"},
        )
        out = res.stdout or ""
    except Exception:
        return []

    streams = []
    blocks = re.split(r"(?m)^Sink Input #", out)
    for blk in blocks[1:]:
        id_m = re.match(r"(\d+)", blk)
        if not id_m:
            continue
        sid = int(id_m.group(1))

        muted = bool(re.search(r"Mute:\s*yes", blk, re.I))
        vol_m = re.search(r"Volume:.*?(\d+)%", blk)
        vol = int(vol_m.group(1)) if vol_m else 100

        app_m = re.search(r'application\.name\s*=\s*"([^"]+)"', blk)
        bin_m = re.search(r'application\.process\.binary\s*=\s*"([^"]+)"', blk)
        media_m = re.search(r'media\.name\s*=\s*"([^"]+)"', blk)
        name = (app_m.group(1) if app_m else (bin_m.group(1) if bin_m else (media_m.group(1) if media_m else f"Stream #{sid}"))).strip()

        streams.append({
            "id": sid,
            "name": name,
            "volume": max(0, min(150, vol)),
            "muted": muted,
        })
    return streams


def main() -> int:
    if len(sys.argv) < 2:
        return 1
    cmd = sys.argv[1]
    if cmd == "list":
        print(json.dumps(list_streams(), ensure_ascii=False))
        return 0
    if cmd == "set" and len(sys.argv) >= 4:
        try:
            sid = str(int(sys.argv[2]))
            pct = max(0, min(150, int(round(float(sys.argv[3])))))
        except ValueError:
            return 1
        subprocess.run(["pactl", "set-sink-input-volume", sid, f"{pct}%"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return 0
    if cmd == "mute" and len(sys.argv) >= 3:
        try:
            sid = str(int(sys.argv[2]))
        except ValueError:
            return 1
        subprocess.run(["pactl", "set-sink-input-mute", sid, "toggle"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
