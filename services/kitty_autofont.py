#!/usr/bin/env python3
import glob
import json
import os
import subprocess
import sys

CACHE_FILE = "/tmp/.arushell_kitty_fonts.json"

def get_hypr_sig() -> str:
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    uid = os.getuid()
    if sig and os.path.exists(f"/run/user/{uid}/hypr/{sig}/.socket.sock"):
        return sig
    base = f"/run/user/{uid}/hypr"
    if os.path.isdir(base):
        dirs = sorted(
            (os.path.join(base, d) for d in os.listdir(base)),
            key=lambda p: os.path.getmtime(p),
            reverse=True,
        )
        if dirs:
            return os.path.basename(dirs[0])
    return ""

def target_font_for(w: int, h: int) -> float:
    if w <= 0:
        return 11.5
    if w < 720 or h < 420:
        return 7.5
    if w < 1020 or h < 560:
        return 8.5
    if w < 1280:
        return 10.0
    return 11.5

def main():
    sig = get_hypr_sig()
    if not sig:
        return
    env = os.environ.copy()
    env["HYPRLAND_INSTANCE_SIGNATURE"] = sig
    try:
        out = subprocess.check_output(["hyprctl", "clients", "-j"], env=env, text=True, stderr=subprocess.DEVNULL)
        clients = json.loads(out)
    except Exception:
        return

    try:
        cache = json.load(open(CACHE_FILE, encoding="utf-8"))
    except Exception:
        cache = {}

    new_cache = {}
    changed = False

    for c in clients:
        cls = str(c.get("class", "") or "").lower()
        if "kitty" not in cls:
            continue
        pid = c.get("pid")
        size = c.get("size") or [0, 0]
        w, h = int(size[0] or 0), int(size[1] or 0)
        if not pid or w <= 0:
            continue

        sock = f"/tmp/kitty-sock-{pid}"
        if not os.path.exists(sock):
            # Fallback: try matching any kitty-sock-* if single instance
            socks = glob.glob("/tmp/kitty-sock-*")
            sock = socks[0] if len(socks) == 1 else ""
        if not sock or not os.path.exists(sock):
            continue

        sz = target_font_for(w, h)
        key = str(pid)
        new_cache[key] = sz
        if cache.get(key) != sz:
            try:
                subprocess.run(
                    ["kitty", "@", "--to", f"unix:{sock}", "set-font-size", str(sz)],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    timeout=1.5,
                )
                changed = True
            except Exception:
                pass

    if changed or new_cache != cache:
        try:
            with open(CACHE_FILE, "w", encoding="utf-8") as f:
                json.dump(new_cache, f)
        except Exception:
            pass

if __name__ == "__main__":
    main()
