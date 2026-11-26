#!/usr/bin/env python3
"""
AruShell Clipboard History helper with cached image thumbnails for cliphist.
Outputs JSON array: [{id, text, isImage, thumbPath}, ...]
"""

import json
import os
import shutil
import subprocess
import sys


CACHE_DIR = os.path.join(os.path.expanduser("~"), ".cache", "arushell", "clip_thumbs")


def main() -> int:
    if not shutil.which("cliphist"):
        print(json.dumps({"missing": True}))
        return 0

    os.makedirs(CACHE_DIR, exist_ok=True)
    try:
        res = subprocess.run(
            ["cliphist", "list"],
            capture_output=True,
            text=True,
            timeout=3,
        )
        lines = (res.stdout or "").splitlines()[:40]
    except Exception:
        print("[]")
        return 0

    out = []
    valid_ids = set()
    img_decoded = 0

    for line in lines:
        if "\t" not in line:
            continue
        item_id, preview = line.split("\t", 1)
        item_id = item_id.strip()
        preview = preview.strip()
        is_image = "binary data" in preview.lower()
        thumb_path = ""

        if is_image and item_id.isdigit():
            valid_ids.add(item_id)
            candidate = os.path.join(CACHE_DIR, f"{item_id}.img")
            if os.path.isfile(candidate) and os.path.getsize(candidate) > 0:
                thumb_path = candidate
            elif img_decoded < 10:
                try:
                    dec = subprocess.run(
                        ["cliphist", "decode"],
                        input=f"{item_id}\t\n".encode("utf-8"),
                        capture_output=True,
                        timeout=2,
                    )
                    if dec.returncode == 0 and dec.stdout:
                        with open(candidate, "wb") as f:
                            f.write(dec.stdout)
                        thumb_path = candidate
                        img_decoded += 1
                except Exception:
                    pass

        out.append({
            "id": item_id,
            "text": preview,
            "isImage": is_image,
            "thumbPath": thumb_path,
        })

    # Prune old thumbnails no longer in top 40
    try:
        for fn in os.listdir(CACHE_DIR):
            stem = fn.rsplit(".", 1)[0]
            if stem not in valid_ids:
                os.remove(os.path.join(CACHE_DIR, fn))
    except Exception:
        pass

    print(json.dumps(out, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
