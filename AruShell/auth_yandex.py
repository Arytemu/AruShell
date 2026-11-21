#!/usr/bin/env python3
"""
Помощник авторизации Яндекс Музыки для Ambient Music Shell.
Открывает https://ym-token.marshal.dev (актуальный web-app с Яндекс Device Flow)
или чистую OAuth-ссылку без HTML-экранирования, проверяет токен и сохраняет его в config.json.
"""

import json
import shutil
import subprocess
import sys
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
CONFIG_PATH = BASE_DIR / "config.json"
TOKEN_URL = "https://ym-token.marshal.dev"
DIRECT_OAUTH_URL = "https://oauth.yandex.ru/authorize?response_type=token&client_id=23cabbbdc6cd418abb4b39c32c41195d"


def verify_token(token: str) -> tuple[bool, str]:
    try:
        from yandex_music import Client
    except ImportError:
        return True, "Библиотека yandex-music ещё не установлена — токен сохранён без проверки."
    try:
        client = Client(token).init()
        acc = client.me.account if client.me else None
        name = (acc.display_name or acc.login) if acc else "Аккаунт Яндекс"
        return True, f"Успешный вход: {name}"
    except Exception as exc:
        return False, f"Ошибка проверки токена: {exc}"


def main():
    print("==============================================")
    print("  Авторизация Яндекс Музыки (Ambient Shell)")
    print("==============================================")
    print(f"\nСпособ 1 (рекомендуемый, Device Flow): {TOKEN_URL}")
    print(f"Способ 2 (прямой OAuth в браузере):    {DIRECT_OAUTH_URL}")
    print("\nПосле входа скопируйте токен (начинается с y0_...)\n")

    opener = shutil.which("xdg-open")
    if opener:
        ans = input("Открыть https://ym-token.marshal.dev в браузере? [Y/n]: ").strip().lower()
        if ans in ("", "y", "yes", "д", "да"):
            subprocess.Popen([opener, TOKEN_URL], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    token = input("\nВставьте ваш OAuth-токен Яндекс Музыки: ").strip()
    if not token:
        print("Отменено: пустой токен.")
        sys.exit(1)

    ok, msg = verify_token(token)
    print(f"\n==> {msg}")
    if not ok:
        ans = input("Всё равно сохранить токен в config.json? [y/N]: ").strip().lower()
        if ans not in ("y", "yes", "д", "да"):
            sys.exit(1)

    cfg = {}
    if CONFIG_PATH.exists():
        try:
            cfg = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
        except Exception:
            cfg = {}
    cfg["yandex_music_token"] = token
    CONFIG_PATH.write_text(json.dumps(cfg, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Токен сохранён в {CONFIG_PATH}!")
    print("Перезапустите шелл: quickshell -c ambient-music-shell")


if __name__ == "__main__":
    main()
