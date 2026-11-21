#!/usr/bin/env python3
"""Fast vibrant dominant-color extractor for AruShell Material You HUD theming."""
import colorsys
import re
import shutil
import subprocess
import sys


def score_rgb_list(pixels):
    # Pass 1: vivid mid-tone accents (aurora, neon, sky, sunset, foliage)
    for min_l, max_l, min_s in ((0.16, 0.92, 0.18), (0.08, 0.95, 0.10)):
        bins = {}
        for r, g, b in pixels:
            h, l, s = colorsys.rgb_to_hls(r / 255.0, g / 255.0, b / 255.0)
            if l < min_l or l > max_l or s < min_s:
                continue
            w = (s ** 2.0) * (l ** 1.1) * (1.0 - abs(l - 0.52) * 0.85)
            if w <= 0:
                continue
            hb = int(h * 24) % 24
            if hb not in bins:
                bins[hb] = [0.0, 0.0, 0.0, 0.0]
            bins[hb][0] += w
            bins[hb][1] += r * w
            bins[hb][2] += g * w
            bins[hb][3] += b * w
        if bins:
            best = max(bins.values(), key=lambda x: x[0])
            rr = int(best[1] / best[0])
            gg = int(best[2] / best[0])
            bb = int(best[3] / best[0])
            return f"#{rr:02x}{gg:02x}{bb:02x}"

    if not pixels:
        return ""
    rr = sum(p[0] for p in pixels) // len(pixels)
    gg = sum(p[1] for p in pixels) // len(pixels)
    bb = sum(p[2] for p in pixels) // len(pixels)
    return f"#{rr:02x}{gg:02x}{bb:02x}"


def extract_with_pil(path):
    from PIL import Image
    with Image.open(path) as im:
        im = im.convert("RGB")
        im.thumbnail((96, 96))
        return score_rgb_list(list(im.getdata()))


def extract_with_magick(path):
    tool = shutil.which("magick") or shutil.which("convert")
    if not tool:
        return ""
    proc = subprocess.run(
        [tool, path, "-resize", "64x64!", "-colors", "16", "-unique-colors", "txt:-"],
        capture_output=True,
        text=True,
        timeout=5,
    )
    if proc.returncode != 0:
        return ""
    pixels = []
    for m in re.finditer(r"#([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})", proc.stdout):
        pixels.append((int(m.group(1), 16), int(m.group(2), 16), int(m.group(3), 16)))
    return score_rgb_list(pixels)


def main():
    if len(sys.argv) < 2 or not sys.argv[1]:
        return
    path = sys.argv[1]
    hex_col = ""
    try:
        hex_col = extract_with_pil(path)
    except Exception:
        try:
            hex_col = extract_with_magick(path)
        except Exception:
            hex_col = ""
    if hex_col:
        print(hex_col)


if __name__ == "__main__":
    main()
