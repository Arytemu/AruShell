#!/usr/bin/env bash
set -euo pipefail

# Fast 1-second updater for AruShell (no pacman/yay/pip, preserves config.json, settings.json, .venv)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}/.config/quickshell/AruShell"

echo "==> Быстрое обновление AruShell..."
pkill -9 -x quickshell 2>/dev/null || true
pkill -9 -x qs 2>/dev/null || true
sleep 0.25

mkdir -p "${TARGET_DIR}"
cp "${SCRIPT_DIR}/shell.qml" "${TARGET_DIR}/"
rm -rf "${TARGET_DIR}/components" "${TARGET_DIR}/services" "${TARGET_DIR}/assets" "${TARGET_DIR}/sddm-theme"
cp -r "${SCRIPT_DIR}/components" "${SCRIPT_DIR}/services" "${SCRIPT_DIR}/assets" "${SCRIPT_DIR}/sddm-theme" "${TARGET_DIR}/"
chmod +x "${TARGET_DIR}/services/backend.py" \
         "${TARGET_DIR}/services/extract_color.py" \
         "${TARGET_DIR}/services/sysinfo.sh" \
         "${TARGET_DIR}/services/screenshot.sh"

# Configure autostart, SUPER+W (wallpapers), SUPER+L (Caelestia Lock Screen), and 10-min hypridle auto-lock
HYPR_DIR="${HOME}/.config/hypr"
if [ -d "${HYPR_DIR}" ]; then
    python3 - "${HYPR_DIR}" "${HOME}" <<'PYEOF'
import glob, os, re, sys

hypr_dir = sys.argv[1]
home_dir = sys.argv[2]

all_cfgs = sorted(
    glob.glob(os.path.join(hypr_dir, "**", "*.lua"), recursive=True)
    + glob.glob(os.path.join(hypr_dir, "**", "*.conf"), recursive=True)
)

rice_keys_conf = os.path.join(home_dir, ".config", "rice", "keys.conf")
if os.path.isfile(rice_keys_conf):
    all_cfgs.append(rice_keys_conf)

for fp in all_cfgs:
    if ".bak" in fp or ".dms-backups" in fp or fp.endswith("hypridle.conf"):
        continue
    try:
        lines = open(fp, encoding="utf-8").readlines()
    except Exception:
        continue

    is_lua = fp.endswith(".lua")
    cmt = "--" if is_lua else "#"
    in_our_block = False
    out, ch = [], False

    for l in lines:
        s = l.strip()
        if ("AruShell" in s) and ("end " not in s) and (s.startswith(cmt)):
            in_our_block = True
            out.append(l)
            continue
        if ("end AruShell" in s) and s.startswith(cmt):
            in_our_block = False
            out.append(l)
            continue
        if in_our_block or s.startswith(cmt) or "AruShell" in s:
            out.append(l)
            continue

        sl = s.lower()
        has_old_cmd = any(
            k in sl
            for k in (
                "rice-lock",
                "rice-dashboard wallpaper",
                "hyprquickpaper",
                "dms ipc call lock",
                "ambient-music-shell",
                "rice-bar start",
                "rice-desktop start",
                "rice-notifyd",
                "rice-walls",
            )
        )
        has_super_l = bool(
            re.search(r'["\']\s*SUPER\s*\+\s*L\s*["\']', s, re.IGNORECASE)
            or re.search(r"^\s*bind[a-z]*\s*=\s*SUPER\s*,\s*L\s*,", s, re.IGNORECASE)
            or (fp == rice_keys_conf and re.match(r"^\s*lock\s*=", s, re.IGNORECASE))
        )
        if has_old_cmd or has_super_l:
            out.append(f"{cmt} [disabled by AruShell] {l}")
            print("  [OFF]", os.path.relpath(fp, home_dir), "->", s)
            ch = True
        else:
            out.append(l)

    if ch:
        open(fp, "w", encoding="utf-8").writelines(out)

lua_main = os.path.join(hypr_dir, "hyprland.lua")
if os.path.isfile(lua_main):
    txt = open(lua_main, encoding="utf-8").read()
    # Remove previous AruShell lock & wallpaper block so fresh binds + reboot-safe autostart sit at the end
    txt = re.sub(
        r"\n?-- AruShell lock & wallpaper binds.*?-- end AruShell lock & wallpaper binds[^\n]*\n?",
        "\n",
        txt,
        flags=re.S,
    )
    txt = re.sub(
        r"\n?-- AruShell lock & wallpaper binds\n(?:[^\n]*(?:SUPER \+ [WL]|hypridle|quickshell)[^\n]*\n?)+",
        "\n",
        txt,
    )
    block = (
        "\n-- AruShell lock & wallpaper binds\n"
        'pcall(function() hl.unbind("SUPER + W") end)\n'
        'pcall(function() hl.unbind("SUPER + w") end)\n'
        'hl.bind("SUPER + W", hl.dsp.exec_cmd("quickshell ipc -c AruShell call wallpaper toggle"))\n'
        'pcall(function() hl.unbind("SUPER + L") end)\n'
        'pcall(function() hl.unbind("SUPER + l") end)\n'
        'hl.bind("SUPER + L", hl.dsp.exec_cmd("quickshell ipc -c AruShell call lock lock"))\n'
        'hl.exec_cmd("sh -c \'sleep 0.8; pgrep -x quickshell >/dev/null || nohup quickshell -c AruShell >/tmp/arushell.log 2>&1 &\'")\n'
        'hl.exec_cmd("pgrep -f \'cliphist store\' >/dev/null || nohup wl-paste --watch cliphist store >/dev/null 2>&1 &")\n'
        'hl.exec_cmd("pgrep -x hypridle >/dev/null || nohup hypridle >/dev/null 2>&1 &")\n'
        "-- end AruShell lock & wallpaper binds\n"
    )
    open(lua_main, "w", encoding="utf-8").write(txt.rstrip() + "\n" + block)
    print("  [OK] Автозапуск AruShell после перезагрузки, бинды SUPER+W/SUPER+L и hypridle обновлены в hyprland.lua")
PYEOF

    cat > "${HYPR_DIR}/hypridle.conf" <<'IDLEEOF'
general {
    lock_cmd = quickshell ipc -c AruShell call lock lock
    before_sleep_cmd = quickshell ipc -c AruShell call lock lock
    after_sleep_cmd = hyprctl dispatch dpms on
}

listener {
    timeout = 600
    on-timeout = quickshell ipc -c AruShell call lock lock
}
IDLEEOF
    echo "  [OK] Настроен автолок через 10 минут бездействия (${HYPR_DIR}/hypridle.conf)"

    hyprctl reload >/dev/null 2>&1 || true
    sleep 0.3
fi

if command -v hypridle >/dev/null 2>&1; then
    pkill -x hypridle 2>/dev/null || true
    nohup hypridle >/dev/null 2>&1 &
else
    echo "  [!] Для автоблокировки через 10 мин установите hypridle: sudo pacman -S hypridle"
fi

rm -rf "${HOME}/.cache/quickshell/qmlcache" 2>/dev/null || true
if ! pgrep -x quickshell >/dev/null 2>&1; then
    nohup quickshell -c AruShell >/tmp/arushell.log 2>&1 &
fi
sleep 0.8
if pgrep -x quickshell >/dev/null 2>&1; then
    echo "Готово! AruShell обновлён и запущен (лог: /tmp/arushell.log)."
else
    echo "[!] AruShell не запустился. Последние строки /tmp/arushell.log:"
    tail -n 25 /tmp/arushell.log 2>/dev/null || true
fi
