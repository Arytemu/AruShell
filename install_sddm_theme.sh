#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_THEME="${SCRIPT_DIR}/sddm-theme/arushell-material-you"
DST_THEME="/usr/share/sddm/themes/arushell-material-you"
SETTINGS_JSON="${HOME}/.config/quickshell/AruShell/settings.json"

echo "==> Установка темы SDDM 'AruShell Material You' (в стиле Super+L)..."
sudo mkdir -p /usr/share/sddm/themes /etc/sddm.conf.d
sudo rm -rf "${DST_THEME}"
sudo cp -r "${SRC_THEME}" "${DST_THEME}"

# Sync Bebas Neue font for Caelestia-style clock
if [ -f "${SCRIPT_DIR}/assets/fonts/BebasNeue-Regular.ttf" ]; then
    sudo cp "${SCRIPT_DIR}/assets/fonts/BebasNeue-Regular.ttf" "${DST_THEME}/BebasNeue-Regular.ttf"
fi

# Sync user's ~/.face avatar if present
if [ -f "${HOME}/.face" ]; then
    sudo cp "${HOME}/.face" "${DST_THEME}/avatar.png"
    sudo chmod 644 "${DST_THEME}/avatar.png"
    echo "  [OK] Скопирован аватар из ~/.face"
fi

# Sync current wallpaper & Material You palette from AruShell settings.json
if [ -f "${SETTINGS_JSON}" ]; then
    python3 - "${SETTINGS_JSON}" "${SCRIPT_DIR}/services/extract_color.py" "${DST_THEME}" <<'PYEOF'
import colorsys, json, os, shutil, subprocess, sys

settings_path, extractor, dst_theme = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    cfg = json.load(open(settings_path, encoding="utf-8"))
except Exception:
    cfg = {}

wp = str(cfg.get("wallpaperPath") or "").strip()
dark = True  # SDDM sits on blurred dark backdrop; always keep light high-contrast typography
accent_ov = str(cfg.get("accentOverride") or "").strip()
font_fam = str(cfg.get("fontFamily") or "Google Sans").strip()

bg_file = ""
seed_hex = accent_ov

if wp and os.path.isfile(wp):
    ext = os.path.splitext(wp)[1].lower() or ".jpg"
    bg_file = "background" + ext
    subprocess.run(["sudo", "cp", wp, os.path.join(dst_theme, bg_file)], check=False)
    subprocess.run(["sudo", "chmod", "644", os.path.join(dst_theme, bg_file)], check=False)
    print(f"  [OK] Скопированы текущие обои в SDDM: {os.path.basename(wp)}")
    if not seed_hex and os.path.isfile(extractor):
        try:
            seed_hex = subprocess.check_output(["python3", extractor, wp], text=True).strip()
        except Exception:
            seed_hex = ""

def hsla_hex(h, s, l):
    r, g, b = colorsys.hls_to_rgb(h % 1.0, max(0.0, min(1.0, l)), max(0.0, min(1.0, s)))
    return f"#{int(r*255):02x}{int(g*255):02x}{int(b*255):02x}"

h, s = 0.72, 0.50
if seed_hex.startswith("#") and len(seed_hex) == 7:
    r = int(seed_hex[1:3], 16) / 255.0
    g = int(seed_hex[3:5], 16) / 255.0
    b = int(seed_hex[5:7], 16) / 255.0
    hh, ll, ss = colorsys.rgb_to_hls(r, g, b)
    h = hh
    s = max(0.28, min(0.85, ss))

if dark:
    accent = hsla_hex(h, min(0.76, s + 0.12), 0.78)
    on_accent = hsla_hex(h, min(0.55, s), 0.15)
    pcont = hsla_hex(h, min(0.52, s * 0.85), 0.27)
    on_pcont = hsla_hex(h, min(0.65, s), 0.91)
    surf = hsla_hex(h, min(0.28, s * 0.45), 0.12)
    surf_h = hsla_hex(h, min(0.30, s * 0.48), 0.18)
    on_surf = hsla_hex(h, 0.10, 0.94)
    on_svar = hsla_hex(h, 0.12, 0.74)
    outline = hsla_hex(h, 0.16, 0.34)
else:
    accent = hsla_hex(h, min(0.72, s + 0.10), 0.38)
    on_accent = hsla_hex(h, 0.10, 0.98)
    pcont = hsla_hex(h, min(0.60, s * 0.80), 0.86)
    on_pcont = hsla_hex(h, min(0.65, s), 0.16)
    surf = hsla_hex(h, min(0.24, s * 0.35), 0.94)
    surf_h = hsla_hex(h, min(0.24, s * 0.35), 0.89)
    on_surf = hsla_hex(h, 0.14, 0.12)
    on_svar = hsla_hex(h, 0.12, 0.34)
    outline = hsla_hex(h, 0.16, 0.65)

conf = f"""[General]
FontFamily={font_fam}
Background={bg_file}
AccentColor={accent}
OnAccentColor={on_accent}
PrimaryContainerColor={pcont}
OnPrimaryContainerColor={on_pcont}
SurfaceColor={surf}
SurfaceHighColor={surf_h}
OnSurfaceColor={on_surf}
OnSurfaceVariantColor={on_svar}
OutlineColor={outline}
"""
p = subprocess.run(["sudo", "tee", os.path.join(dst_theme, "theme.conf")], input=conf, text=True, stdout=subprocess.DEVNULL)
if p.returncode == 0:
    print(f"  [OK] Палитра Material You ({accent}) синхронизирована в theme.conf")
PYEOF
fi

sudo tee /etc/sddm.conf.d/zz-arushell.conf >/dev/null <<'EOF'
[Theme]
Current=arushell-material-you
EOF

echo "Готово! Тема SDDM установлена и активирована."
echo "Проверить превью без перезагрузки:"
echo "  sddm-greeter-qt6 --test-mode --theme ${DST_THEME}"
