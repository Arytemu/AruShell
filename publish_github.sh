#!/usr/bin/env bash
set -euo pipefail

# Universal GitHub publisher & release formatter for Arytemu/AruShell
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_SLUG="Arytemu/AruShell"
RELEASE_TAG="${1:-v1.0.0}"
TMP_REPO="/tmp/AruShell-gh-publish"

echo "==> Публикация и оформление ${REPO_SLUG} (${RELEASE_TAG})..."

if ! command -v gh >/dev/null 2>&1; then
    echo "[!] Установите GitHub CLI: sudo pacman -S github-cli && gh auth login"
    exit 1
fi

gh auth setup-git >/dev/null 2>&1 || true

rm -rf "${TMP_REPO}"
if gh repo view "${REPO_SLUG}" >/dev/null 2>&1; then
    git clone "https://github.com/${REPO_SLUG}.git" "${TMP_REPO}"
else
    mkdir -p "${TMP_REPO}"
    git -C "${TMP_REPO}" init -b main
fi

# Sync fresh files into repo (preserving .git, skipping .venv and caches)
find "${TMP_REPO}" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +
cp -r "${SCRIPT_DIR}/." "${TMP_REPO}/"
rm -rf "${TMP_REPO}/.git.bak" "${TMP_REPO}/.venv" "${TMP_REPO}/__pycache__" "${TMP_REPO}/services/__pycache__"

cd "${TMP_REPO}"
git add -A
if ! git diff --cached --quiet; then
    git commit -m "Release ${RELEASE_TAG}: Caelestia lock screen, 4-tab Dynamic Island, QuickSettings constructor, Wi-Fi & MPRIS fixes"
fi

if ! git remote get-url origin >/dev/null 2>&1; then
    gh repo create AruShell --public --source=. --remote=origin --push
else
    git push -u origin main
fi

# Update About: Description & Topics
echo "==> Обновляю Description и Topics репозитория..."
gh repo edit "${REPO_SLUG}" \
    --description "Material 3 Expressive Desktop Shell built with Quickshell (Qt6 QML) for Hyprland — Caelestia-style lock screen, 4-tab Dynamic Island, live wallpaper theming, QuickSettings constructor, Pac-Man workspaces & screenshot tool" \
    --add-topic quickshell \
    --add-topic hyprland \
    --add-topic material-you \
    --add-topic material-3 \
    --add-topic wayland \
    --add-topic qml \
    --add-topic qt6 \
    --add-topic linux-ricing \
    --add-topic dotfiles \
    --add-topic desktop-shell

# Create release zip asset
ZIP_ASSET="/tmp/AruShell-${RELEASE_TAG}.zip"
rm -f "${ZIP_ASSET}"
(cd "$(dirname "${SCRIPT_DIR}")" && zip -qr "${ZIP_ASSET}" "$(basename "${SCRIPT_DIR}")" -x "*/.git/*" "*/.venv/*" "*/__pycache__/*" "*.pyc") || true

NOTES="## Что внутри AruShell ${RELEASE_TAG}
- **Экран блокировки в стиле Caelestia** (\`Super + L\` + автолок 10 мин в \`hypridle\`): двухфазная анимация замка и плавающей bento-карточки, шрифт Bebas Neue, погода, \`arushellfetch.sh\`, медиа, индикаторы CPU/RAM/BAT и уведомления.
- **Dynamic Island (4 вкладки)**: Dashboard с календарём, Media с синхронизированным текстом песни, Performance с живой скоростью сети (\`↓/↑\`) и Weather с прогнозом на 3 дня; плавная подстройка размера под контент.
- **Material You из текущих обоев + карусель (\`Super + W\`)**: автоперекрашивание всего HUD, свои папки с обоями, переключение стрелками, Тёмная и Светлая темы, прозрачность панелей.
- **QuickSettings-конструктор**: добавление/удаление плиток и значков пилюли, ширина плиток \`1× / 2×\`, настройка размеров, Game Mode, Keep Awake, выбор Wi-Fi с паролем (без лагов сети).
- **Pac-Man Workspaces & Скриншоты**: красная пульсирующая подсветка urgent-воркспейсов, замороженный скриншот с лупой (\`Super + Shift + S\` / \`Print\`), мгновенный OSD раскладки через Hyprland IPC.
- **Нативные и Electron-плееры (MPRIS)**: выбор клиента (\`Авто\`, \`Яндекс Музыка\`, \`Spotify\`, \`Apple Music\`, \`YT Music\`, \`Свой\`) с игнорированием браузеров и Telegram Web.

### Установка и обновление
- Первая установка: \`./install.sh\`
- Быстрое обновление (1 сек): \`./update.sh\`"

echo "==> Публикую релиз ${RELEASE_TAG}..."
if gh release view "${RELEASE_TAG}" --repo "${REPO_SLUG}" >/dev/null 2>&1; then
    gh release edit "${RELEASE_TAG}" --repo "${REPO_SLUG}" --title "AruShell ${RELEASE_TAG}" --notes "${NOTES}"
    [ -f "${ZIP_ASSET}" ] && gh release upload "${RELEASE_TAG}" "${ZIP_ASSET}" --repo "${REPO_SLUG}" --clobber || true
else
    if [ -f "${ZIP_ASSET}" ]; then
        gh release create "${RELEASE_TAG}" "${ZIP_ASSET}" --repo "${REPO_SLUG}" --title "AruShell ${RELEASE_TAG}" --notes "${NOTES}"
    else
        gh release create "${RELEASE_TAG}" --repo "${REPO_SLUG}" --title "AruShell ${RELEASE_TAG}" --notes "${NOTES}"
    fi
fi

rm -rf "${TMP_REPO}"
echo "Готово! https://github.com/${REPO_SLUG}/releases/tag/${RELEASE_TAG}"
