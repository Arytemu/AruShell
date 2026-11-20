#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_THEME="${SCRIPT_DIR}/sddm-theme/arushell-material-you"
DST_THEME="/usr/share/sddm/themes/arushell-material-you"

echo "==> Установка темы SDDM 'AruShell Material You'..."
sudo mkdir -p /usr/share/sddm/themes /etc/sddm.conf.d
sudo rm -rf "${DST_THEME}"
sudo cp -r "${SRC_THEME}" "${DST_THEME}"

sudo tee /etc/sddm.conf.d/arushell-material-you.conf >/dev/null <<'EOF'
[Theme]
Current=arushell-material-you
EOF

echo "Готово! Тема SDDM установлена и активирована."
echo "Проверить превью без перезагрузки:"
echo "  sddm-greeter-qt6 --test-mode --theme ${DST_THEME}"
