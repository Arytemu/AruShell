#!/usr/bin/env bash
set -euo pipefail

echo "==> Удаление AruShell..."
pkill -x quickshell 2>/dev/null || true
pkill -x qs 2>/dev/null || true

rm -rf "${HOME}/.config/quickshell/AruShell"
rm -rf "${HOME}/.cache/quickshell/qmlcache"

HYPR_LUA="${HOME}/.config/hypr/hyprland.lua"
HYPR_CONF="${HOME}/.config/hypr/hyprland.conf"

if [ -f "${HYPR_LUA}" ]; then
    python3 - "${HYPR_LUA}" <<'PYEOF'
import sys, re
p = sys.argv[1]
txt = open(p, encoding="utf-8").read()
txt = re.sub(r"\n?-- AruShell binds.*?-- end AruShell binds[^\n]*\n?", "\n", txt, flags=re.S)
open(p, "w", encoding="utf-8").write(txt)
PYEOF
    echo "  [OK] Бинды AruShell удалены из ${HYPR_LUA}"
fi

if [ -f "${HYPR_CONF}" ]; then
    python3 - "${HYPR_CONF}" <<'PYEOF'
import sys, re
p = sys.argv[1]
txt = open(p, encoding="utf-8").read()
txt = re.sub(r"\n?# AruShell binds.*?# end AruShell binds[^\n]*\n?", "\n", txt, flags=re.S)
open(p, "w", encoding="utf-8").write(txt)
PYEOF
    echo "  [OK] Бинды AruShell удалены из ${HYPR_CONF}"
fi

hyprctl reload >/dev/null 2>&1 || true
echo "AruShell полностью удалён."
