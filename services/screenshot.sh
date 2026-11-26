#!/usr/bin/env bash
set -euo pipefail
# Ensure valid HYPRLAND_INSTANCE_SIGNATURE even when launched via systemd user service
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || [ ! -S "/run/user/$(id -u)/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket.sock" ]; then
    _LIVE_SIG="$(ls -t "/run/user/$(id -u)/hypr" 2>/dev/null | head -n 1 || true)"
    [ -n "${_LIVE_SIG}" ] && export HYPRLAND_INSTANCE_SIGNATURE="${_LIVE_SIG}"
fi

CMD="${1:-}"
SHOT_DIR="${XDG_PICTURES_DIR:-${HOME}/Pictures}/Screenshots"
mkdir -p "${SHOT_DIR}"

case "${CMD}" in
  freeze)
    MON="${2:-}"
    OUT="${3:-/tmp/ams-shot-freeze.png}"
    pkill -x slurp 2>/dev/null || true
    rm -f /tmp/ams-shot-freeze-*.png 2>/dev/null || true

    # Determine active monitor from hyprctl if not specified
    if [ -z "${MON}" ] && command -v hyprctl >/dev/null 2>&1; then
      MON=$(hyprctl monitors -j 2>/dev/null | python3 -c '
import sys, json
try:
    ms = json.load(sys.stdin)
    foc = next((m for m in ms if m.get("focused")), ms[0] if ms else None)
    print(foc.get("name", "") if foc else "")
except Exception:
    print("")
')
    fi

    if [ -n "${MON}" ]; then
      grim -o "${MON}" "${OUT}" 2>/dev/null || grim "${OUT}"
    else
      grim "${OUT}"
    fi

    # Return monitor geometry + visible windows on active workspace as JSON
    python3 - "${MON}" "${OUT}" <<'PYEOF'
import sys, json, subprocess

mon_name = sys.argv[1]
out_path = sys.argv[2]

def run_json(cmd):
    try:
        raw = subprocess.check_output(cmd, stderr=subprocess.DEVNULL, text=True)
        return json.loads(raw)
    except Exception:
        return []

monitors = run_json(["hyprctl", "monitors", "-j"])
clients = run_json(["hyprctl", "clients", "-j"])

mon = None
for m in monitors:
    if mon_name and m.get("name") == mon_name:
        mon = m
        break
if not mon and monitors:
    mon = next((m for m in monitors if m.get("focused")), monitors[0])

mx = mon.get("x", 0) if mon else 0
my = mon.get("y", 0) if mon else 0
scale = float(mon.get("scale", 1.0)) if mon else 1.0
active_ws = (mon.get("activeWorkspace") or {}).get("id") if mon else None
mname = mon.get("name", "") if mon else mon_name

wins = []
for c in clients:
    if not c.get("mapped", True) or c.get("hidden", False):
        continue
    ws_id = (c.get("workspace") or {}).get("id")
    if active_ws is not None and ws_id != active_ws:
        continue
    at = c.get("at") or [0, 0]
    sz = c.get("size") or [0, 0]
    if sz[0] <= 10 or sz[1] <= 10:
        continue
    wins.append({
        "x": int(at[0] - mx),
        "y": int(at[1] - my),
        "w": int(sz[0]),
        "h": int(sz[1]),
        "app": c.get("class") or c.get("initialClass") or "Window",
        "title": c.get("title") or "",
        "floating": bool(c.get("floating", False))
    })

# Put floating windows first so hover picks them over tiled windows underneath
wins.sort(key=lambda w: (0 if w["floating"] else 1))

print(json.dumps({
    "monitor": mname,
    "path": out_path,
    "scale": scale,
    "windows": wins
}, ensure_ascii=False))
PYEOF
    ;;

  crop)
    SRC="${2:-}"
    ACTION="${3:-save}"
    X="${4:-0}"
    Y="${5:-0}"
    W="${6:-0}"
    H="${7:-0}"

    if [ ! -f "${SRC}" ]; then
      exit 1
    fi

    TS="$(date +'%Y-%m-%d_%H-%M-%S')"
    FINAL_FILE="${SHOT_DIR}/Screenshot_${TS}.png"
    TMP_CROP="/tmp/ams-shot-crop-${TS}.png"

    if [ "${W}" -gt 0 ] && [ "${H}" -gt 0 ]; then
      if command -v magick >/dev/null 2>&1; then
        magick "${SRC}" -crop "${W}x${H}+${X}+${Y}" +repage "${TMP_CROP}"
      elif command -v ffmpeg >/dev/null 2>&1; then
        ffmpeg -y -loglevel error -i "${SRC}" -vf "crop=${W}:${H}:${X}:${Y}" -frames:v 1 "${TMP_CROP}"
      else
        python3 - "${SRC}" "${TMP_CROP}" "${X}" "${Y}" "${W}" "${H}" <<'PYEOF'
import sys
from PIL import Image
src, dst, x, y, w, h = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5]), int(sys.argv[6])
im = Image.open(src)
im.crop((x, y, x + w, y + h)).save(dst, "PNG")
PYEOF
      fi
    else
      cp "${SRC}" "${TMP_CROP}"
    fi

    case "${ACTION}" in
      save)
        mv "${TMP_CROP}" "${FINAL_FILE}"
        if command -v wl-copy >/dev/null 2>&1; then
          wl-copy --type image/png < "${FINAL_FILE}"
        fi
        if command -v notify-send >/dev/null 2>&1; then
          notify-send -a "Скриншот" -i "${FINAL_FILE}" "Скриншот сохранён" "Скопирован в буфер · $(basename "${FINAL_FILE}")"
        fi
        ;;
      copy)
        if command -v wl-copy >/dev/null 2>&1; then
          wl-copy --type image/png < "${TMP_CROP}"
        fi
        if command -v notify-send >/dev/null 2>&1; then
          notify-send -a "Скриншот" -i "${TMP_CROP}" "Скриншот скопирован" "Изображение помещено в буфер обмена"
        fi
        (sleep 3 && rm -f "${TMP_CROP}") >/dev/null 2>&1 &
        ;;
      edit)
        if command -v satty >/dev/null 2>&1; then
          nohup satty --filename "${TMP_CROP}" --copy-command wl-copy --output-filename "${FINAL_FILE}" >/dev/null 2>&1 &
        elif command -v swappy >/dev/null 2>&1; then
          nohup swappy -f "${TMP_CROP}" -o "${FINAL_FILE}" >/dev/null 2>&1 &
        else
          mv "${TMP_CROP}" "${FINAL_FILE}"
          if command -v wl-copy >/dev/null 2>&1; then
            wl-copy --type image/png < "${FINAL_FILE}"
          fi
          if command -v notify-send >/dev/null 2>&1; then
            notify-send -a "Скриншот" -i "${FINAL_FILE}" "satty/swappy не найден" "Снимок сохранён в ${FINAL_FILE}"
          fi
          command -v xdg-open >/dev/null 2>&1 && nohup xdg-open "${FINAL_FILE}" >/dev/null 2>&1 &
        fi
        ;;
    esac

    rm -f "${SRC}" 2>/dev/null || true
    ;;

  full)
    MON="${2:-}"
    TS="$(date +'%Y-%m-%d_%H-%M-%S')"
    FINAL_FILE="${SHOT_DIR}/Screenshot_${TS}.png"
    if [ -n "${MON}" ]; then
      grim -o "${MON}" "${FINAL_FILE}" 2>/dev/null || grim "${FINAL_FILE}"
    else
      grim "${FINAL_FILE}"
    fi
    if command -v wl-copy >/dev/null 2>&1; then
      wl-copy --type image/png < "${FINAL_FILE}"
    fi
    if command -v notify-send >/dev/null 2>&1; then
      notify-send -a "Скриншот" -i "${FINAL_FILE}" "Весь экран сохранён" "Скопирован в буфер · $(basename "${FINAL_FILE}")"
    fi
    ;;

  cleanup)
    rm -f /tmp/ams-shot-freeze-*.png 2>/dev/null || true
    ;;
esac
