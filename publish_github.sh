#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

echo "==> Публикация AruShell на GitHub..."
if [ ! -d .git ]; then
    git init -b main
fi

git add .
if ! git diff --cached --quiet; then
    git commit -m "Initial release: AruShell (Material 3 Expressive Quickshell for Hyprland)"
fi

if command -v gh >/dev/null 2>&1; then
    echo "Использую GitHub CLI (gh)..."
    gh repo create AruShell --public --source=. --remote=origin --push \
        --description "Material 3 Expressive Desktop Shell built with Quickshell for Hyprland"
else
    read -r -p "Вставьте URL вашего пустого репозитория GitHub (например, https://github.com/USER/AruShell.git): " REPO_URL
    git remote remove origin 2>/dev/null || true
    git remote add origin "${REPO_URL}"
    git push -u origin main
fi

echo "Готово! AruShell опубликован на GitHub."
