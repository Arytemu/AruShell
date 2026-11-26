#!/usr/bin/env bash
set -euo pipefail

# Fast 1-second updater for AruShell (no pacman/yay/pip, preserves config.json, settings.json, .venv)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}/.config/quickshell/AruShell"

echo "==> Быстрое обновление AruShell..."
# Permanently stop & disable competing old shells (dms.service & rice-* daemons)
systemctl --user stop arushell.service dms.service 2>/dev/null || true
systemctl --user disable dms.service 2>/dev/null || true
systemctl --user mask dms.service 2>/dev/null || true
pkill -9 -x quickshell 2>/dev/null || true
pkill -9 -x qs 2>/dev/null || true
pkill -9 -f 'rice-desktop|rice-settings|rice-canvasd|rice-ws-watch|rice-rules|rice-update|rice-busy|rice-bar|rice-notifyd' 2>/dev/null || true
sleep 0.25

mkdir -p "${TARGET_DIR}"
cp "${SCRIPT_DIR}/shell.qml" "${TARGET_DIR}/"
rm -rf "${TARGET_DIR}/components" "${TARGET_DIR}/services" "${TARGET_DIR}/assets" "${TARGET_DIR}/sddm-theme"
cp -r "${SCRIPT_DIR}/components" "${SCRIPT_DIR}/services" "${SCRIPT_DIR}/assets" "${SCRIPT_DIR}/sddm-theme" "${TARGET_DIR}/"
chmod +x "${TARGET_DIR}/services/backend.py" \
         "${TARGET_DIR}/services/extract_color.py" \
         "${TARGET_DIR}/services/websearch.py" \
         "${TARGET_DIR}/services/kitty_autofont.py" \
         "${TARGET_DIR}/services/clip_preview.py" \
         "${TARGET_DIR}/services/theme_sync.py" \
         "${TARGET_DIR}/services/hypr_anims.py" \
         "${TARGET_DIR}/services/smart_lock.sh" \
         "${TARGET_DIR}/services/audio_mixer.py" \
         "${TARGET_DIR}/services/sysinfo.sh" \
         "${TARGET_DIR}/services/screenshot.sh"

# 1. Bulletproof systemd user service for Hyprland (uwsm-managed) & reboot persistence!
QS_BIN="$(command -v quickshell || echo /usr/bin/quickshell)"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"
mkdir -p "${SYSTEMD_USER_DIR}"
cat > "${SYSTEMD_USER_DIR}/arushell.service" <<EOF
[Unit]
Description=AruShell Material 3 Expressive Desktop Shell
PartOf=graphical-session.target
After=graphical-session.target

[Service]
Type=simple
KillMode=process
ExecStartPre=-/usr/bin/pkill -x quickshell
ExecStartPre=-/usr/bin/pkill -x qs
ExecStart=${QS_BIN} -c AruShell
Restart=on-failure
RestartSec=1
StandardOutput=append:/tmp/arushell.log
StandardError=append:/tmp/arushell.log

[Install]
WantedBy=graphical-session.target
EOF

if command -v systemctl >/dev/null 2>&1; then
    systemctl --user import-environment HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP 2>/dev/null || true
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable arushell.service 2>/dev/null || true
    echo "  [OK] Автозапуск настроен через systemd user service (arushell.service)"
fi

# 2. Configure SUPER+W (wallpapers), SUPER+L (Caelestia Lock Screen), and 10-min hypridle auto-lock
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
                "rice-dashboard",
                "rice-desktop",
                "rice-settings",
                "rice-canvasd",
                "rice-ws-watch",
                "rice-rules",
                "rice-update",
                "rice-busy",
                "rice-bar",
                "rice-notifyd",
                "rice-walls",
                "rice-start",
                "hyprquickpaper",
                "dms ipc",
                "dms run",
                "ambient-music-shell",
                "quickshell/rice-",
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
    # Remove any direct quickshell launch lines in hyprland.lua so systemd arushell.service is the single owner (never 2 shells!)
    txt = re.sub(r'^[^\n]*hl\.exec_cmd\([^\n]*quickshell[^\n]*\)[^\n]*\n?', '', txt, flags=re.M)
    block = (
        "\n-- AruShell lock & wallpaper binds\n"
        'pcall(function() hl.unbind("SUPER + W") end)\n'
        'pcall(function() hl.unbind("SUPER + w") end)\n'
        'hl.bind("SUPER + W", hl.dsp.exec_cmd("quickshell ipc -c AruShell call wallpaper toggle"))\n'
        'pcall(function() hl.unbind("SUPER + L") end)\n'
        'pcall(function() hl.unbind("SUPER + l") end)\n'
        'hl.bind("SUPER + L", hl.dsp.exec_cmd("quickshell ipc -c AruShell call lock lock"))\n'
        'pcall(function() hl.unbind("SUPER + B") end)\n'
        'pcall(function() hl.unbind("SUPER + b") end)\n'
        'hl.bind("SUPER + B", hl.dsp.exec_cmd("quickshell ipc -c AruShell call globe toggle"))\n'
        'hl.config({ general = { border_size = 2 }, decoration = { active_opacity = 1.0, inactive_opacity = 0.94, fullscreen_opacity = 1.0, blur = { enabled = true, size = 7, passes = 3, vibrancy = 0.22, ignore_opacity = true, new_optimizations = true } } })\n'
        'hl.window_rule({ name = "arushell-kitty-glass", match = { class = "kitty" }, opacity = "1.0 override 0.94 override" })\n'
        'hl.window_rule({ name = "arushell-games-opaque", match = { class = "^(steam_app_.*|gamescope|mpv|vlc|firefox|zen)$" }, opacity = "1.0 override 1.0 override" })\n'
        'hl.exec_cmd("pgrep -f cliphist >/dev/null || wl-paste --watch cliphist store")\n'
        'hl.exec_cmd("pgrep -x hypridle >/dev/null || hypridle")\n'
        'pcall(dofile, os.getenv("HOME") .. "/.config/hypr/arushell_anims.lua")\n'
        "-- end AruShell lock & wallpaper binds\n"
    )
    orig_lua = open(lua_main, encoding="utf-8").read()
    new_lua = txt.rstrip() + "\n" + block
    if new_lua != orig_lua:
        open(lua_main, "w", encoding="utf-8").write(new_lua)
        open("/tmp/.arushell_hypr_changed", "w").write("1")
        print("  [OK] Бинды SUPER+W, SUPER+L, SUPER+B и автозапуск обновлены в hyprland.lua")
PYEOF

    cat > "${HYPR_DIR}/hypridle.conf" <<IDLEEOF
general {
    lock_cmd = quickshell ipc -c AruShell call lock lock
    before_sleep_cmd = quickshell ipc -c AruShell call lock lock
    after_sleep_cmd = hyprctl dispatch dpms on
}

listener {
    timeout = 600
    on-timeout = ${HOME}/.config/quickshell/AruShell/services/smart_lock.sh
}
IDLEEOF
    echo "  [OK] Настроен автолок через 10 минут бездействия (${HYPR_DIR}/hypridle.conf)"

    # Clean up any previous Liquid Glass / HyprGlass experiment files and restore normal Hyprland/Kitty state
    rm -f "${HYPR_DIR}/arushell_glass.lua" "${HOME}/.cache/arushell/liquid_glass_state.json" /tmp/arushell_glass.log 2>/dev/null || true
    if command -v hyprpm >/dev/null 2>&1; then
        hyprpm disable hyprglass >/dev/null 2>&1 || true
    fi
    hyprctl eval 'if hl.plugin and hl.plugin.hyprglass then hl.plugin.hyprglass.config({ enabled = false, layers = { enabled = false } }) end' >/dev/null 2>&1 || true
    if [ -f "${HOME}/.config/kitty/kitty.conf" ]; then
        sed -i 's/^background_opacity[[:space:]]\+0\.\(26\|28\|30\|32\|42\|58\)/background_opacity       0.80/' "${HOME}/.config/kitty/kitty.conf" 2>/dev/null || true
        pkill -USR1 kitty 2>/dev/null || true
    fi

    # Only reload Hyprland when hyprland.lua actually changed (avoids freezing Electron/YandexMusic!)
    if [ -f /tmp/.arushell_hypr_changed ]; then
        rm -f /tmp/.arushell_hypr_changed
        hyprctl reload >/dev/null 2>&1 || true
        sleep 0.3
    fi
fi


# 3. Glassy translucent background for GTK3 & GTK4 apps (Nautilus/Files, etc.) — text & icons stay 100% crisp!
for GTK_VER in gtk-3.0 gtk-4.0; do
    GTK_DIR="${HOME}/.config/${GTK_VER}"
    GTK_CSS="${GTK_DIR}/gtk.css"
    mkdir -p "${GTK_DIR}"
    touch "${GTK_CSS}"
    python3 - "${GTK_CSS}" <<'GTKEOF'
import re, sys
p = sys.argv[1]
txt = open(p, encoding="utf-8").read()
txt = re.sub(r"\n?/\* AruShell Glass Background \*/.*?/\* end AruShell Glass Background \*/\n?", "\n", txt, flags=re.S)
block = '''
/* AruShell Glass Background */
window.background,
window.background > box,
.nautilus-window,
.nautilus-window paned,
.nautilus-window scrolledwindow,
navigation-split-view,
navigation-view-page,
headerbar,
.navigation-sidebar,
sidebar {
    background-color: rgba(20, 19, 24, 0.78);
}
popover > contents,
menu {
    background-color: rgba(26, 25, 32, 0.86);
}
/* end AruShell Glass Background */
'''
open(p, "w", encoding="utf-8").write(txt.rstrip() + "\n" + block)
GTKEOF
done
echo "  [OK] Настроен полупрозрачный фон (без замутнения текста) для GTK3/GTK4 окон"

if command -v hypridle >/dev/null 2>&1; then
    pkill -x hypridle 2>/dev/null || true
    nohup hypridle >/dev/null 2>&1 &
fi

rm -rf "${HOME}/.cache/quickshell/qmlcache" 2>/dev/null || true
if command -v systemctl >/dev/null 2>&1 && systemctl --user restart arushell.service 2>/dev/null; then
    sleep 0.6
else
    if ! pgrep -x quickshell >/dev/null 2>&1; then
        nohup quickshell -c AruShell >/tmp/arushell.log 2>&1 &
    fi
    sleep 0.8
fi

if pgrep -x quickshell >/dev/null 2>&1; then
    echo "Готово! AruShell обновлён и запущен (лог: /tmp/arushell.log)."
else
    echo "[!] AruShell не запустился. Последние строки /tmp/arushell.log:"
    tail -n 25 /tmp/arushell.log 2>/dev/null || true
fi
