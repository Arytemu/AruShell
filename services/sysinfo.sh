#!/usr/bin/env bash
set -uo pipefail

CMD="${1:-status}"

case "${CMD}" in
  status)
    wifi_en=0
    wifi_ssid=""
    eth_con=0
    if command -v nmcli >/dev/null 2>&1; then
        ws="$(nmcli radio wifi 2>/dev/null || echo disabled)"
        [ "$ws" = "enabled" ] && wifi_en=1
        wifi_ssid="$(nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: '$1=="yes"{print $2; exit}' || true)"
        eth_line="$(nmcli -t -f TYPE,STATE dev 2>/dev/null | awk -F: '$1=="ethernet" && $2=="connected"{print 1; exit}' || true)"
        [ "$eth_line" = "1" ] && eth_con=1
    fi

    bt_en=0
    bt_dev=""
    if command -v bluetoothctl >/dev/null 2>&1; then
        if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
            bt_en=1
            bt_dev="$(bluetoothctl devices Connected 2>/dev/null | head -n1 | cut -d' ' -f3- || true)"
        fi
    fi

    vol=50
    muted=0
    if command -v wpctl >/dev/null 2>&1; then
        vout="$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || true)"
        if [ -n "$vout" ]; then
            vol="$(echo "$vout" | awk '{printf "%d", $2*100}')"
            echo "$vout" | grep -q "MUTED" && muted=1
        fi
    elif command -v pactl >/dev/null 2>&1; then
        vol="$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -oP '\d+%' | head -n1 | tr -d '%' || echo 50)"
        pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | grep -qi "yes" && muted=1
    fi

    has_br=0
    br=100
    if command -v brightnessctl >/dev/null 2>&1; then
        bcur="$(brightnessctl g 2>/dev/null || true)"
        bmax="$(brightnessctl m 2>/dev/null || true)"
        if [ -n "$bcur" ] && [ -n "$bmax" ] && [ "$bmax" -gt 0 ] 2>/dev/null; then
            has_br=1
            br=$(( bcur * 100 / bmax ))
        fi
    fi

    has_bat=0
    bat_pct=100
    bat_chg=0
    for b in /sys/class/power_supply/BAT*; do
        if [ -d "$b" ]; then
            has_bat=1
            bat_pct="$(cat "$b/capacity" 2>/dev/null || echo 100)"
            bst="$(cat "$b/status" 2>/dev/null || echo Discharging)"
            if [ "$bst" = "Charging" ] || [ "$bst" = "Full" ]; then
                bat_chg=1
            fi
            break
        fi
    done

    cpu="$(awk '{u=$2+$4; t=$2+$4+$5; if (t>0) printf "%d", (u*100)/t; else print 0; exit}' /proc/stat 2>/dev/null || echo 0)"
    read -r ram_pct ram_txt < <(free -m 2>/dev/null | awk '/Mem:/{printf "%d %.1f/%.1fG\n", ($3*100)/$2, $3/1024, $2/1024}' || echo "0 0/0G")
    read -r disk_pct disk_txt < <(df -h / 2>/dev/null | awk 'NR==2{gsub("%","",$5); printf "%d %s/%s\n", $5, $3, $2}' || echo "0 0/0G")
    up_txt="$(uptime -p 2>/dev/null | sed 's/^up //' || echo "")"
    usr="${USER:-user}"

    night_light=0
    pgrep -x hyprsunset >/dev/null 2>&1 && night_light=1

    power_prof=""
    if command -v powerprofilesctl >/dev/null 2>&1; then
        power_prof="$(powerprofilesctl get 2>/dev/null || true)"
    fi

    kbd_layout="EN"
    if command -v hyprctl >/dev/null 2>&1; then
        kbd_layout="$(hyprctl devices -j 2>/dev/null | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    kbs = d.get("keyboards") or []
    main = next((k for k in kbs if k.get("main")), kbs[0] if kbs else None)
    km = (main.get("active_keymap") or "") if main else ""
    low = km.lower()
    if "russian" in low or low.startswith("ru"): print("RU")
    elif "english" in low or "us" in low or low.startswith("en"): print("EN")
    elif "ukrain" in low: print("UK")
    elif "german" in low: print("DE")
    elif "french" in low: print("FR")
    elif km: print(km[:2].upper())
    else: print("EN")
except Exception:
    print("EN")
')"
    fi

    python3 -c '
import json, sys
print(json.dumps({
    "wifiEnabled": sys.argv[1] == "1",
    "wifiSsid": sys.argv[2],
    "ethernetConnected": sys.argv[3] == "1",
    "btEnabled": sys.argv[4] == "1",
    "btDevice": sys.argv[5],
    "volume": int(sys.argv[6] or 0),
    "muted": sys.argv[7] == "1",
    "hasBrightness": sys.argv[8] == "1",
    "brightness": int(sys.argv[9] or 100),
    "hasBattery": sys.argv[10] == "1",
    "batteryPercent": int(sys.argv[11] or 100),
    "batteryCharging": sys.argv[12] == "1",
    "cpuPercent": int(sys.argv[13] or 0),
    "ramPercent": int(sys.argv[14] or 0),
    "ramText": sys.argv[15],
    "diskPercent": int(sys.argv[16] or 0),
    "diskText": sys.argv[17],
    "uptimeText": sys.argv[18],
    "userName": sys.argv[19],
    "nightLight": sys.argv[20] == "1",
    "powerProfile": sys.argv[21],
    "kbdLayout": sys.argv[22]
}, ensure_ascii=False))
' "$wifi_en" "$wifi_ssid" "$eth_con" "$bt_en" "$bt_dev" "$vol" "$muted" "$has_br" "$br" "$has_bat" "$bat_pct" "$bat_chg" "$cpu" "$ram_pct" "$ram_txt" "$disk_pct" "$disk_txt" "$up_txt" "$usr" "$night_light" "$power_prof" "$kbd_layout"
    ;;

  wifi-list)
    if ! command -v nmcli >/dev/null 2>&1; then
        echo "[]"
        exit 0
    fi
    nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null | python3 -c '
import sys, json
seen = {}
for line in sys.stdin:
    parts = line.rstrip("\n").split(":")
    if len(parts) < 4: continue
    in_use = parts[0].strip() == "*"
    ssid = parts[1].strip()
    if not ssid: continue
    sig = int(parts[2] or 0) if parts[2].isdigit() else 0
    sec = parts[3].strip()
    if ssid not in seen or in_use or sig > seen[ssid]["signal"]:
        seen[ssid] = {"ssid": ssid, "signal": sig, "inUse": in_use, "security": sec}
out = sorted(seen.values(), key=lambda x: (0 if x["inUse"] else 1, -x["signal"]))
print(json.dumps(out[:14], ensure_ascii=False))
'
    ;;

  bt-list)
    if ! command -v bluetoothctl >/dev/null 2>&1; then
        echo "[]"
        exit 0
    fi
    python3 - <<'PYEOF'
import subprocess, json
def run(args):
    try:
        return subprocess.check_output(args, stderr=subprocess.DEVNULL, text=True)
    except Exception:
        return ""
conn_macs = set()
for line in run(["bluetoothctl", "devices", "Connected"]).splitlines():
    p = line.split(" ", 2)
    if len(p) >= 2: conn_macs.add(p[1])
devs = []
for line in run(["bluetoothctl", "devices"]).splitlines():
    p = line.split(" ", 2)
    if len(p) >= 3 and p[0] == "Device":
        devs.append({"mac": p[1], "name": p[2].strip(), "connected": p[1] in conn_macs})
devs.sort(key=lambda d: (0 if d["connected"] else 1, d["name"].lower()))
print(json.dumps(devs[:14], ensure_ascii=False))
PYEOF
    ;;

  audio-list)
    python3 - <<'PYEOF'
import subprocess, json
def run(args):
    try:
        return subprocess.check_output(args, stderr=subprocess.DEVNULL, text=True)
    except Exception:
        return ""
sinks = []
default_sink = run(["pactl", "get-default-sink"]).strip()
raw = run(["pactl", "-f", "json", "list", "sinks"])
if raw.strip().startswith("["):
    try:
        for s in json.loads(raw):
            name = s.get("name") or ""
            desc = s.get("description") or name
            sinks.append({"id": name, "desc": desc, "active": name == default_sink})
    except Exception:
        pass
if not sinks:
    for line in run(["pactl", "list", "short", "sinks"]).splitlines():
        p = line.split("\t")
        if len(p) >= 2:
            sinks.append({"id": p[1], "desc": p[1], "active": p[1] == default_sink})
print(json.dumps(sinks, ensure_ascii=False))
PYEOF
    ;;

  audio-set)
    SINK="${2:-}"
    if [ -n "${SINK}" ] && command -v pactl >/dev/null 2>&1; then
        pactl set-default-sink "${SINK}" 2>/dev/null || true
        for inp in $(pactl list short sink-inputs 2>/dev/null | awk '{print $1}'); do
            pactl move-sink-input "${inp}" "${SINK}" 2>/dev/null || true
        done
    fi
    ;;

  weather)
    curl -sf --max-time 6 "https://wttr.in/?format=j1&lang=ru" 2>/dev/null | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    cc = (d.get("current_condition") or [{}])[0]
    area = (d.get("nearest_area") or [{}])[0]
    city = ((area.get("areaName") or [{}])[0]).get("value", "")
    desc_ru = ((cc.get("lang_ru") or [{}])[0]).get("value", "")
    desc_en = ((cc.get("weatherDesc") or [{}])[0]).get("value", "")
    temp = cc.get("temp_C", "")
    feels = cc.get("FeelsLikeC", "")
    print(json.dumps({
        "temp": (temp + "°C") if temp != "" else "",
        "feels": (feels + "°C") if feels != "" else "",
        "desc": desc_ru or desc_en,
        "city": city
    }, ensure_ascii=False))
except Exception:
    print("{}")
'
    ;;

  switch-layout)
    command -v hyprctl >/dev/null 2>&1 && hyprctl switchxkblayout all next >/dev/null 2>&1 || true
    ;;
esac
