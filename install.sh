#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
#  AruShell — Multi-Distro Installer (Quickshell + Material 3 Expressive)
#  Originally designed and tested for Hyprland (0.55+ Lua & classic .conf)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}/.config/quickshell/AruShell"
AUTO_YES=0
SKIP_DEPS=0

for arg in "$@"; do
    case "$arg" in
        -y|--yes)       AUTO_YES=1 ;;
        --skip-deps)    SKIP_DEPS=1 ;;
        -h|--help)
            echo "Использование: ./install.sh [опции]"
            echo "  -y, --yes       Автоматическая установка без интерактивных вопросов"
            echo "  --skip-deps     Пропустить установку системных пакетов"
            exit 0
            ;;
    esac
done

C_RST="\033[0m"
C_ACC="\033[1;35m"
C_OK="\033[1;32m"
C_WRN="\033[1;33m"
C_DIM="\033[0;37m"

ask_yn() {
    local prompt="$1"
    local default="${2:-Y}"
    if [ "${AUTO_YES}" -eq 1 ]; then
        return 0
    fi
    local hint="[Y/n]"
    [ "${default}" = "N" ] && hint="[y/N]"
    read -r -p "${prompt} ${hint}: " ans || ans=""
    ans="${ans:-$default}"
    [[ "${ans}" =~ ^[YyДд]$ ]]
}

detect_distro() {
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        local id_low="${ID:-unknown}"
        local like_low="${ID_LIKE:-}"
        case "${id_low}" in
            arch|cachyos|endeavouros|manjaro|garuda|arcolinux) echo "arch" ;;
            fedora|nobara|ultramarine)                          echo "fedora" ;;
            ubuntu|debian|pop|linuxmint|elementary)             echo "debian" ;;
            opensuse*|suse*)                                    echo "opensuse" ;;
            nixos)                                              echo "nixos" ;;
            *)
                if [[ "${like_low}" == *"arch"* ]]; then echo "arch"
                elif [[ "${like_low}" == *"fedora"* ]]; then echo "fedora"
                elif [[ "${like_low}" == *"debian"* || "${like_low}" == *"ubuntu"* ]]; then echo "debian"
                elif [[ "${like_low}" == *"suse"* ]]; then echo "opensuse"
                else echo "unknown"
                fi
                ;;
        esac
    else
        echo "unknown"
    fi
}

DISTRO="$(detect_distro)"

echo -e "${C_ACC}"
echo "   █████╗ ██████╗ ██╗   ██╗███████╗██╗  ██╗███████╗██╗     ██╗     "
echo "  ██╔══██╗██╔══██╗██║   ██║██╔════╝██║  ██║██╔════╝██║     ██║     "
echo "  ███████║██████╔╝██║   ██║███████╗███████║█████╗  ██║     ██║     "
echo "  ██╔══██║██╔══██╗██║   ██║╚════██║██╔══██║██╔══╝  ██║     ██║     "
echo "  ██║  ██║██║  ██║╚██████╔╝███████║██║  ██║███████╗███████╗███████╗"
echo "  ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝"
echo -e "${C_RST}"
echo -e "  ${C_DIM}Material 3 Expressive Desktop Shell на базе Quickshell (Qt6 QML)${C_RST}"
echo -e "  ${C_WRN}Примечание:${C_RST} изначально создавался и тестировался под ${C_ACC}Hyprland${C_RST}."
echo -e "  Обнаруженный дистрибутив: ${C_OK}${DISTRO}${C_RST}"
echo ""

# ------------------------------------------------------------------------------
# 1. System Dependencies per Distro
# ------------------------------------------------------------------------------
if [ "${SKIP_DEPS}" -eq 0 ]; then
    case "${DISTRO}" in
        arch)
            if ask_yn "==> Установить/проверить системные пакеты для Arch/CachyOS (pacman + AUR)?" "Y"; then
                sudo pacman -S --needed --noconfirm \
                    qt6-multimedia qt6-multimedia-ffmpeg qt6-svg \
                    grim wl-clipboard cliphist brightnessctl \
                    networkmanager bluez-utils libnotify python
                AUR_HELPER=""
                command -v yay >/dev/null 2>&1 && AUR_HELPER="yay"
                [ -z "${AUR_HELPER}" ] && command -v paru >/dev/null 2>&1 && AUR_HELPER="paru"
                if [ -n "${AUR_HELPER}" ]; then
                    if ! command -v quickshell >/dev/null 2>&1; then
                        "${AUR_HELPER}" -S --needed --noconfirm quickshell-git || true
                    fi
                    if ask_yn "  Установить опциональные пакеты из AUR (ttf-google-sans, satty, hyprsunset)?" "Y"; then
                        "${AUR_HELPER}" -S --needed --noconfirm ttf-google-sans satty hyprsunset || true
                    fi
                else
                    echo -e "  ${C_WRN}[!] AUR-хелпер (yay/paru) не найден. Установите quickshell-git и ttf-google-sans вручную.${C_RST}"
                fi
            fi
            ;;
        fedora)
            if ask_yn "==> Установить системные пакеты для Fedora (dnf)?" "Y"; then
                sudo dnf install -y \
                    qt6-qtmultimedia qt6-qtsvg \
                    grim wl-clipboard brightnessctl \
                    NetworkManager bluez libnotify python3 python3-pip || true
                if ! command -v quickshell >/dev/null 2>&1; then
                    echo -e "  ${C_WRN}[!] Установите Quickshell из COPR:${C_RST} sudo dnf copr enable errornointernet/quickshell && sudo dnf install quickshell"
                fi
            fi
            ;;
        debian)
            if ask_yn "==> Установить системные пакеты для Debian/Ubuntu (apt)?" "Y"; then
                sudo apt update
                sudo apt install -y \
                    qt6-multimedia-dev qml6-module-qtmultimedia qml6-module-qtquick-effects \
                    libqt6svg6 grim wl-clipboard brightnessctl \
                    network-manager bluez libnotify-bin python3-venv python3-pip || true
                if ! command -v quickshell >/dev/null 2>&1; then
                    echo -e "  ${C_WRN}[!] Quickshell на Debian/Ubuntu собирается из исходников: https://quickshell.org/docs/guide/install-setup/${C_RST}"
                fi
            fi
            ;;
        opensuse)
            if ask_yn "==> Установить системные пакеты для openSUSE (zypper)?" "Y"; then
                sudo zypper install -y \
                    qt6-multimedia qt6-svg grim wl-clipboard brightnessctl \
                    NetworkManager bluez libnotify-tools python3 || true
                if ! command -v quickshell >/dev/null 2>&1; then
                    echo -e "  ${C_WRN}[!] Установите Quickshell через OBS/исходники: https://quickshell.org/docs/guide/install-setup/${C_RST}"
                fi
            fi
            ;;
        nixos)
            echo -e "  ${C_WRN}[NixOS]${C_RST} Добавьте в configuration.nix / home.nix пакеты:"
            echo "    quickshell qt6.qtmultimedia qt6.qtsvg grim wl-clipboard cliphist satty hyprsunset brightnessctl python3"
            echo "  Конфигурация AruShell всё равно будет скопирована в ${TARGET_DIR}."
            ;;
        *)
            echo -e "  ${C_WRN}[!] Неизвестный дистрибутив — убедитесь, что установлены: quickshell, qt6-multimedia, qt6-svg, grim, wl-clipboard, cliphist, python3.${C_RST}"
            ;;
    esac
fi

# ------------------------------------------------------------------------------
# 2. Stop running Quickshell & Install AruShell cleanly (preserving user settings)
# ------------------------------------------------------------------------------
echo ""
echo "==> Останавливаю запущенный Quickshell..."
pkill -x quickshell 2>/dev/null || true
pkill -x qs 2>/dev/null || true
sleep 0.3

# Preserve existing settings.json and Yandex token from previous install if present
TMP_BACKUP="/tmp/arushell-backup-$$"
mkdir -p "${TMP_BACKUP}"
for old_dir in "${TARGET_DIR}" "${HOME}/.config/quickshell/ambient-music-shell"; do
    if [ -f "${old_dir}/settings.json" ] && [ ! -f "${TMP_BACKUP}/settings.json" ]; then
        cp "${old_dir}/settings.json" "${TMP_BACKUP}/settings.json"
    fi
    if [ -f "${old_dir}/config.json" ] && [ ! -f "${TMP_BACKUP}/config.json" ]; then
        cp "${old_dir}/config.json" "${TMP_BACKUP}/config.json"
    fi
done

echo "==> Копирую AruShell в ${TARGET_DIR}..."
mkdir -p "${TARGET_DIR}"
rm -rf "${TARGET_DIR}/shaders" \
       "${TARGET_DIR}/components/AmbientBorder.qml" \
       "${TARGET_DIR}/components/QueuePanel.qml" \
       "${TARGET_DIR}/components/GlassSurface.qml"

cp -r "${SCRIPT_DIR}/." "${TARGET_DIR}/"
chmod +x "${TARGET_DIR}/services/backend.py" \
         "${TARGET_DIR}/services/extract_color.py" \
         "${TARGET_DIR}/services/sysinfo.sh" \
         "${TARGET_DIR}/services/screenshot.sh" \
         "${TARGET_DIR}/auth_yandex.py" \
         "${TARGET_DIR}/install.sh" \
         "${TARGET_DIR}/uninstall.sh" \
         "${TARGET_DIR}/install_sddm_theme.sh" \
         "${TARGET_DIR}/publish_github.sh"

# Restore user's settings.json & yandex_music_token if they existed
if [ -f "${TMP_BACKUP}/settings.json" ]; then
    cp "${TMP_BACKUP}/settings.json" "${TARGET_DIR}/settings.json"
    echo "  [OK] Сохранены пользовательские настройки settings.json"
fi
if [ -f "${TMP_BACKUP}/config.json" ]; then
    python3 - "${TMP_BACKUP}/config.json" "${TARGET_DIR}/config.json" <<'PYTOK'
import sys, json
try:
    old = json.load(open(sys.argv[1], encoding="utf-8"))
    new = json.load(open(sys.argv[2], encoding="utf-8"))
    if old.get("yandex_music_token"):
        new["yandex_music_token"] = old["yandex_music_token"]
        json.dump(new, open(sys.argv[2], "w", encoding="utf-8"), indent=2, ensure_ascii=False)
        print("  [OK] Перенесён токен Яндекс Музыки из предыдущей установки")
except Exception:
    pass
PYTOK
fi
rm -rf "${TMP_BACKUP}"

# ------------------------------------------------------------------------------
# 3. Python venv for Yandex Music & yt-dlp
# ------------------------------------------------------------------------------
echo ""
echo "==> Проверка Python venv (yandex-music, yt-dlp)..."
if command -v python3 >/dev/null 2>&1; then
    if [ -x "${TARGET_DIR}/.venv/bin/python" ] && "${TARGET_DIR}/.venv/bin/python" -c "import yandex_music, yt_dlp" >/dev/null 2>&1; then
        echo "  [OK] Python venv уже готов"
    else
        python3 -m venv "${TARGET_DIR}/.venv"
        "${TARGET_DIR}/.venv/bin/pip" install --upgrade pip >/dev/null
        "${TARGET_DIR}/.venv/bin/pip" install -U yandex-music yt-dlp
    fi
else
    echo -e "  ${C_WRN}[!] python3 не найден.${C_RST}"
fi

# ------------------------------------------------------------------------------
# 4. Hyprland Keybinds & Floating Rules (Lua 0.55+ and classic .conf)
# ------------------------------------------------------------------------------
HYPR_DIR="${HOME}/.config/hypr"
if [ -d "${HYPR_DIR}" ]; then
    echo ""
    if ask_yn "==> Прописать бинды AruShell в Hyprland (SUPER -> Launcher, SUPER+V -> Буфер, SUPER+Shift+S / Print -> Скриншот)?" "Y"; then
        python3 - "${HYPR_DIR}" <<'PYEOF'
import os, sys, re, glob

hypr_dir = sys.argv[1]
lua_main = os.path.join(hypr_dir, "hyprland.lua")
conf_main = os.path.join(hypr_dir, "hyprland.conf")

all_cfgs = sorted(
    glob.glob(os.path.join(hypr_dir, "**", "*.lua"), recursive=True)
    + glob.glob(os.path.join(hypr_dir, "**", "*.conf"), recursive=True)
)

for cfg_path in all_cfgs:
    if ".bak" in cfg_path or ".dms-backups" in cfg_path:
        continue
    try:
        with open(cfg_path, "r", encoding="utf-8") as fh:
            lines = fh.readlines()
    except Exception:
        continue

    is_lua = cfg_path.endswith(".lua")
    cmt = "--" if is_lua else "#"
    in_our_block = False
    changed = False
    new_lines = []

    for line in lines:
        s = line.strip()
        if ("AruShell binds" in s or "ambient-music-shell" in s) and "end " not in s:
            in_our_block = True
            new_lines.append(line)
            continue
        if "end AruShell binds" in s or "end ambient-music-shell" in s:
            in_our_block = False
            new_lines.append(line)
            continue
        if in_our_block or s.startswith(cmt) or "AruShell" in s or "ambient-music-shell" in s:
            new_lines.append(line)
            continue

        is_bind = ("hl.bind" in s or ".bind(" in s) if is_lua else bool(re.match(r"^bind[a-z]*\s*=", s))
        has_print = bool(re.search(r"\b(Print|code:107)\b", s, re.IGNORECASE))
        has_super_shift_s = bool(re.search(r"SHIFT.*?\bS\b", s, re.IGNORECASE)) and bool(re.search(r"(SUPER|mainMod|MOD)", s, re.IGNORECASE))
        has_old_shot_cmd = any(k in s.lower() for k in ("rice-hotcorner shot", ".local/bin/screenshot", "dms screenshot", "grimblast", "hyprshot", "flameshot", "rice-lock", "dms ipc call lock", "rice-dashboard wallpaper", "hyprquickpaper", "rice-bar start", "rice-walls awww", "rice-notifyd", "rice-desktop start"))
        if (is_bind and (has_print or has_super_shift_s)) or has_old_shot_cmd:
            new_lines.append(f"{cmt} [disabled by AruShell] {line}")
            print(f"  [OFF] Отключён старый бинд в {cfg_path}: {s}")
            changed = True
        else:
            new_lines.append(line)

    if changed:
        with open(cfg_path, "w", encoding="utf-8") as fh:
            fh.writelines(new_lines)

if os.path.isfile(lua_main):
    with open(lua_main, "r", encoding="utf-8") as fh:
        txt = fh.read()
    txt = re.sub(r"\n?-- ambient-music-shell.*?-- end ambient-music-shell[^\n]*\n?", "\n", txt, flags=re.S)
    txt = re.sub(r"\n?-- AruShell binds.*?-- end AruShell binds[^\n]*\n?", "\n", txt, flags=re.S)
    block = """
-- AruShell binds
pcall(function() hl.unbind("SUPER + SHIFT + S") end)
pcall(function() hl.unbind("SUPER + SHIFT + s") end)
pcall(function() hl.unbind("SUPER + Shift + S") end)
pcall(function() hl.unbind("Print") end)
pcall(function() hl.unbind("PRINT") end)
pcall(function() hl.unbind("SHIFT + Print") end)
pcall(function() hl.unbind("SUPER + SUPER_L") end)
pcall(function() hl.unbind("SUPER + V") end)
pcall(function() hl.unbind("SUPER + W") end)
pcall(function() hl.unbind("SUPER + L") end)
pcall(function() hl.unbind("SUPER + l") end)
hl.bind("SUPER + SUPER_L", hl.dsp.exec_cmd("quickshell ipc -c AruShell call launcher toggle"), { release = true })
hl.bind("SUPER + V", hl.dsp.exec_cmd("quickshell ipc -c AruShell call clipboard toggle"))
hl.bind("SUPER + W", hl.dsp.exec_cmd("quickshell ipc -c AruShell call wallpaper toggle"))
hl.bind("SUPER + L", hl.dsp.exec_cmd("quickshell ipc -c AruShell call lock lock"))
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("quickshell ipc -c AruShell call screenshot open"))
hl.bind("Print", hl.dsp.exec_cmd("quickshell ipc -c AruShell call screenshot open"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("quickshell ipc -c AruShell call screenshot full"))
hl.window_rule({ name = "arushell-screenshot-editor-float", match = { class = "^(com\\\\.gabm\\\\.satty|satty|swappy)$" }, float = true, center = true })
hl.exec_cmd("sh -c 'sleep 0.8; pgrep -x quickshell >/dev/null || nohup quickshell -c AruShell >/tmp/arushell.log 2>&1 &'")
hl.exec_cmd("pgrep -x hypridle >/dev/null || nohup hypridle >/dev/null 2>&1 &")
hl.exec_cmd("pgrep -f cliphist >/dev/null || wl-paste --watch cliphist store")
-- end AruShell binds
"""
    with open(lua_main, "w", encoding="utf-8") as fh:
        fh.write(txt.rstrip() + "\n" + block)
    print(f"  [OK] Бинды и правила записаны в {lua_main}")
elif os.path.isfile(conf_main):
    with open(conf_main, "r", encoding="utf-8") as fh:
        txt = fh.read()
    txt = re.sub(r"\n?# ambient-music-shell.*?# end ambient-music-shell[^\n]*\n?", "\n", txt, flags=re.S)
    txt = re.sub(r"\n?# AruShell binds.*?# end AruShell binds[^\n]*\n?", "\n", txt, flags=re.S)
    block = """
# AruShell binds
unbind = SUPER SHIFT, S
unbind = , Print
unbind = SHIFT, Print
unbind = SUPER, V
bindr = SUPER, SUPER_L, exec, quickshell ipc -c AruShell call launcher toggle
bind = SUPER, V, exec, quickshell ipc -c AruShell call clipboard toggle
bind = SUPER, W, exec, quickshell ipc -c AruShell call wallpaper toggle
bind = SUPER, L, exec, quickshell ipc -c AruShell call lock lock
bind = SUPER SHIFT, S, exec, quickshell ipc -c AruShell call screenshot open
bind = , Print, exec, quickshell ipc -c AruShell call screenshot open
bind = SHIFT, Print, exec, quickshell ipc -c AruShell call screenshot full
exec-once = wl-paste --watch cliphist store
exec-once = quickshell -c AruShell
windowrulev2 = float, class:^(com\\.gabm\\.satty|satty|swappy)$
windowrulev2 = center, class:^(com\\.gabm\\.satty|satty|swappy)$
# end AruShell binds
"""
    with open(conf_main, "w", encoding="utf-8") as fh:
        fh.write(txt.rstrip() + "\n" + block)
    print(f"  [OK] Бинды и правила записаны в {conf_main}")
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
        if command -v hypridle >/dev/null 2>&1; then
            pkill -x hypridle 2>/dev/null || true
            nohup hypridle >/dev/null 2>&1 &
        fi
        hyprctl reload >/dev/null 2>&1 || true
    fi
fi

# ------------------------------------------------------------------------------
# 5. Optional SDDM Theme Installation
# ------------------------------------------------------------------------------
echo ""
if [ "${AUTO_YES}" -eq 0 ] && ask_yn "==> Установить тему входа SDDM (AruShell Material You)?" "N"; then
    "${TARGET_DIR}/install_sddm_theme.sh"
fi

# ------------------------------------------------------------------------------
# 6. Start cliphist watcher & launch AruShell
# ------------------------------------------------------------------------------
if command -v cliphist >/dev/null 2>&1 && command -v wl-paste >/dev/null 2>&1; then
    if ! pgrep -f "cliphist store" >/dev/null 2>&1; then
        nohup wl-paste --watch cliphist store >/dev/null 2>&1 &
    fi
fi

rm -rf "${HOME}/.cache/quickshell/qmlcache" 2>/dev/null || true
if command -v quickshell >/dev/null 2>&1; then
    echo ""
    echo "==> Запускаю AruShell..."
    if ! pgrep -x quickshell >/dev/null 2>&1; then
        nohup quickshell -c AruShell >/tmp/arushell.log 2>&1 &
    fi
    echo -e "${C_OK}Готово! AruShell запущен (лог: /tmp/arushell.log).${C_RST}"
else
    echo -e "${C_WRN}Файлы AruShell установлены в ${TARGET_DIR}. Установите quickshell и запустите: quickshell -c AruShell${C_RST}"
fi
