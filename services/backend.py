#!/usr/bin/env python3
"""
Ambient Music Shell Backend v6
- Multi-platform search (Yandex Music API + yt-dlp + iTunes)
- Guaranteed in-app audio stream resolver (NEVER opens browser when in_app_playback is true)
- Rock-solid 16:9 Music Video Backdrop resolver:
  1. Custom external video backend URL (config: custom_video_backend_url)
  2. Apple / iTunes Official Music Video API (instant 16:9 HD .m4v/.mp4, works in RU without VPN or yt-dlp!)
  3. yt-dlp direct progressive MP4 (YouTube / Dailymotion / RuTube)
  4. Piped API proxy backends
  5. Optional Yandex Music vertical videoshot / local fallback_video_path
- Synced lyrics (Yandex Music native LRC + LRCLIB public API)
"""

import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
CONFIG_PATH = BASE_DIR / "config.json"
VENV_BIN = BASE_DIR / ".venv" / "bin"
CACHE_DIR = Path.home() / ".cache" / "ambient-music-shell"
QUEUE_FILE = CACHE_DIR / "queue.json"
DEBUG_LOG = CACHE_DIR / "debug.log"

USER_AGENT = "AmbientMusicShell/6.0 (Quickshell Linux)"


def log_debug(msg: str):
    try:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        ts = time.strftime("%H:%M:%S")
        with open(DEBUG_LOG, "a", encoding="utf-8") as f:
            f.write(f"[{ts}] {msg}\n")
    except Exception:
        pass


def find_bin(name: str):
    venv_candidate = VENV_BIN / name
    if venv_candidate.exists() and os.access(venv_candidate, os.X_OK):
        return str(venv_candidate)
    return shutil.which(name)


def load_config() -> dict:
    defaults = {
        "layer": "bottom",
        "respect_bar_margin_top": 44,
        "default_platform": "yandex",
        "playback_mode": "in_app",
        "in_app_playback": True,
        "yandex_music_token": "",
        "video_wallpaper": True,
        "video_engine": "qtmultimedia",
        "prefer_yandex_videoshots": False,
        "video_rotation": 0,
        "custom_video_backend_url": "",
        "piped_instances": [
            "https://api.piped.private.coffee",
            "https://pipedapi.kavin.rocks",
            "https://pipedapi.adminforge.de",
        ],
        "fallback_video_path": "",
        "clock_24h": False,
        "font_clock": "Bebas Neue",
        "font_ui": "Inter",
        "ambient_glow_opacity": 0.92,
        "ambient_glow_thickness": 22,
    }
    if CONFIG_PATH.exists():
        try:
            with open(CONFIG_PATH, "r", encoding="utf-8") as f:
                defaults.update(json.load(f))
        except Exception:
            pass
    env_token = os.environ.get("YANDEX_MUSIC_TOKEN", "").strip()
    if env_token and not defaults.get("yandex_music_token"):
        defaults["yandex_music_token"] = env_token
    return defaults


def http_get_json(url: str, timeout: int = 6):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def get_yandex_client(cfg: dict):
    try:
        from yandex_music import Client
    except ImportError:
        return None
    token = (cfg.get("yandex_music_token") or "").strip()
    try:
        client = Client(token) if token else Client()
        client.init()
        return client
    except Exception:
        return None


def yandex_cover_url(uri: str, size: str = "600x600") -> str:
    if not uri:
        return ""
    if uri.startswith("http"):
        return uri.replace("%%", size)
    return f"https://{uri.replace('%%', size)}"


# ---------------------------------------------------------------------------
# Search
# ---------------------------------------------------------------------------

def search_yandex(query: str, cfg: dict) -> dict:
    tracks = []
    artists = []
    client = get_yandex_client(cfg)
    if client is not None:
        try:
            res = client.search(query, type_="all")
            if res and res.tracks and res.tracks.results:
                for t in res.tracks.results[:8]:
                    artist_names = ", ".join(a.name for a in (t.artists or []) if a.name) or "Unknown"
                    album_id = t.albums[0].id if t.albums else ""
                    album_title = t.albums[0].title if t.albums else ""
                    cover = yandex_cover_url(t.cover_uri or (t.albums[0].cover_uri if t.albums else ""))
                    url = (
                        f"https://music.yandex.ru/album/{album_id}/track/{t.id}"
                        if album_id
                        else f"https://music.yandex.ru/track/{t.id}"
                    )
                    tracks.append({
                        "id": str(t.id),
                        "albumId": str(album_id),
                        "title": t.title or "",
                        "artist": artist_names,
                        "album": album_title,
                        "cover": cover,
                        "duration": int((t.duration_ms or 0) / 1000),
                        "platform": "yandex",
                        "url": url,
                    })
            if res and res.artists and res.artists.results:
                for a in res.artists.results[:6]:
                    cover = ""
                    if getattr(a, "cover", None) and getattr(a.cover, "uri", None):
                        cover = yandex_cover_url(a.cover.uri, "400x400")
                    artists.append({
                        "id": str(a.id),
                        "name": a.name or "",
                        "cover": cover,
                        "platform": "yandex",
                        "url": f"https://music.yandex.ru/artist/{a.id}",
                    })
            if tracks or artists:
                return {"tracks": tracks, "artists": artists, "source": "yandex-music-api"}
        except Exception:
            pass

    fallback = search_itunes(query, target_platform="yandex")
    for item in fallback["tracks"]:
        q = urllib.parse.quote(f"{item['artist']} {item['title']}")
        item["url"] = f"https://music.yandex.ru/search?text={q}"
        item["platform"] = "yandex"
    for a in fallback["artists"]:
        q = urllib.parse.quote(a["name"])
        a["url"] = f"https://music.yandex.ru/search?text={q}"
        a["platform"] = "yandex"
    return fallback


def search_ytdlp(query: str, platform: str) -> dict:
    ytdlp = find_bin("yt-dlp")
    if not ytdlp:
        return search_itunes(query, target_platform=platform)
    prefix = "scsearch6:" if platform == "soundcloud" else "ytsearch6:"
    try:
        proc = subprocess.run(
            [ytdlp, "--flat-playlist", "--dump-single-json", "--no-warnings", "--socket-timeout", "6", f"{prefix}{query}"],
            capture_output=True,
            text=True,
            timeout=9,
        )
        if proc.returncode == 0 and proc.stdout.strip():
            data = json.loads(proc.stdout)
            tracks = []
            seen_artists = {}
            for e in (data.get("entries") or [])[:8]:
                title = e.get("title") or ""
                artist = e.get("uploader") or e.get("channel") or "Unknown"
                vid = e.get("id") or ""
                url = e.get("webpage_url") or e.get("url") or ""
                if platform == "youtube_music" and vid and not url.startswith("http"):
                    url = f"https://music.youtube.com/watch?v={vid}"
                elif platform == "youtube_music" and "youtube.com/watch" in url:
                    url = url.replace("www.youtube.com", "music.youtube.com")
                thumbs = e.get("thumbnails") or []
                cover = thumbs[-1].get("url", "") if thumbs else (e.get("thumbnail") or "")
                tracks.append({
                    "id": str(vid),
                    "title": title,
                    "artist": artist,
                    "album": "",
                    "cover": cover,
                    "duration": int(e.get("duration") or 0),
                    "platform": platform,
                    "url": url,
                })
                if artist not in seen_artists:
                    seen_artists[artist] = {
                        "id": artist,
                        "name": artist,
                        "cover": cover,
                        "platform": platform,
                        "url": e.get("uploader_url") or e.get("channel_url") or url,
                    }
            return {
                "tracks": tracks,
                "artists": list(seen_artists.values())[:6],
                "source": "yt-dlp",
            }
    except Exception:
        pass
    return search_itunes(query, target_platform=platform)


def search_itunes(query: str, target_platform: str = "apple") -> dict:
    q = urllib.parse.quote(query)
    url = f"https://itunes.apple.com/search?term={q}&media=music&entity=song&limit=8"
    tracks = []
    artists_map = {}
    try:
        data = http_get_json(url, timeout=7)
        for item in data.get("results", []):
            title = item.get("trackName") or ""
            artist = item.get("artistName") or "Unknown"
            album = item.get("collectionName") or ""
            art = (item.get("artworkUrl100") or "").replace("100x100bb", "600x600bb")
            duration = int((item.get("trackTimeMillis") or 0) / 1000)
            track_url = build_platform_url(target_platform, title, artist, item.get("trackViewUrl", ""))
            tracks.append({
                "id": str(item.get("trackId", "")),
                "title": title,
                "artist": artist,
                "album": album,
                "cover": art,
                "duration": duration,
                "previewUrl": item.get("previewUrl") or "",
                "platform": target_platform,
                "url": track_url,
            })
            if artist not in artists_map:
                artists_map[artist] = {
                    "id": str(item.get("artistId", artist)),
                    "name": artist,
                    "cover": art,
                    "platform": target_platform,
                    "url": build_platform_url(target_platform, "", artist, item.get("artistViewUrl", "")),
                }
    except Exception:
        pass
    return {"tracks": tracks, "artists": list(artists_map.values())[:6], "source": "itunes"}


def build_platform_url(platform: str, title: str, artist: str, fallback_url: str = "") -> str:
    q = urllib.parse.quote(f"{artist} {title}".strip())
    if platform == "yandex":
        return f"https://music.yandex.ru/search?text={q}"
    if platform == "spotify":
        return f"spotify:search:{q}"
    if platform == "spotify_web":
        return f"https://open.spotify.com/search/{q}"
    if platform == "youtube_music":
        return f"https://music.youtube.com/search?q={q}"
    if platform == "soundcloud":
        return f"https://soundcloud.com/search?q={q}"
    if platform == "amazon":
        return f"https://music.amazon.com/search/{q}"
    if platform == "apple":
        return fallback_url or f"https://music.apple.com/search?term={q}"
    return fallback_url or f"https://music.yandex.ru/search?text={q}"


def cmd_search(platform: str, query: str, cfg: dict):
    if not query.strip():
        print(json.dumps({"tracks": [], "artists": []}))
        return
    if platform in ("yandex", "automatic"):
        res = search_yandex(query, cfg)
    elif platform in ("soundcloud", "youtube_music"):
        res = search_ytdlp(query, platform)
    else:
        res = search_itunes(query, target_platform=platform)
    print(json.dumps(res, ensure_ascii=False))


# ---------------------------------------------------------------------------
# Guaranteed In-App Direct Audio Stream Resolver
# ---------------------------------------------------------------------------

def resolve_yandex_audio_url(track_id: str, title: str, artist: str, cfg: dict) -> str:
    if not cfg.get("yandex_music_token"):
        return ""
    client = get_yandex_client(cfg)
    if client is None:
        return ""
    try:
        target_track = None
        if track_id and track_id.isdigit():
            tracks = client.tracks([track_id])
            if tracks:
                target_track = tracks[0]
        if target_track is None and (title or artist):
            res = client.search(f"{artist} {title}".strip(), type_="track")
            if res and res.tracks and res.tracks.results:
                target_track = res.tracks.results[0]
        if target_track is None:
            return ""
        infos = target_track.get_download_info(get_direct_links=True)
        if not infos:
            return ""
        best = sorted(infos, key=lambda x: x.bitrate_in_kbps or 0, reverse=True)[0]
        return best.get_direct_link() or ""
    except Exception:
        return ""


def resolve_ytdlp_audio_url(item: dict) -> str:
    ytdlp = find_bin("yt-dlp")
    if not ytdlp:
        return ""
    url = (item.get("url") or "").strip()
    title = (item.get("title") or "").strip()
    artist = (item.get("artist") or "").strip()
    platform = item.get("platform", "")

    targets = []
    if platform in ("soundcloud", "youtube_music") and url.startswith("http") and "/search" not in url:
        targets.append(url)
    if title or artist:
        targets.append(f"scsearch1:{artist} {title}")
        targets.append(f"ytsearch1:{artist} {title} official audio")

    fmt = "bestaudio[ext=m4a]/bestaudio[ext=mp3]/bestaudio/best"
    for target in targets:
        try:
            proc = subprocess.run(
                [ytdlp, "-f", fmt, "-g", "--no-playlist", "--no-warnings", "--socket-timeout", "5", target],
                capture_output=True,
                text=True,
                timeout=8,
            )
            lines = [l.strip() for l in proc.stdout.splitlines() if l.strip().startswith("http")]
            if lines:
                return lines[0]
        except Exception:
            continue
    return ""


def resolve_deezer_preview_url(title: str, artist: str) -> str:
    q = urllib.parse.quote(f"{artist} {title}".strip())
    try:
        data = http_get_json(f"https://api.deezer.com/search?q={q}&limit=1", timeout=5)
        items = data.get("data") or []
        if items and items[0].get("preview"):
            return items[0]["preview"]
    except Exception:
        pass
    return ""


def save_to_queue(item: dict):
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    queue = []
    if QUEUE_FILE.exists():
        try:
            queue = json.loads(QUEUE_FILE.read_text(encoding="utf-8"))
        except Exception:
            queue = []
    key = (item.get("title", "").lower(), item.get("artist", "").lower())
    queue = [x for x in queue if (x.get("title", "").lower(), x.get("artist", "").lower()) != key]
    queue.insert(0, item)
    queue = queue[:25]
    QUEUE_FILE.write_text(json.dumps(queue, ensure_ascii=False, indent=2), encoding="utf-8")


def cmd_play(payload_json: str, cfg: dict):
    item = json.loads(payload_json)
    save_to_queue(item)
    platform = item.get("platform", cfg.get("default_platform", "yandex"))
    track_id = str(item.get("id", ""))
    title = item.get("title", "")
    artist = item.get("artist", "")
    mode = cfg.get("playback_mode", "in_app")

    if mode == "in_app" and cfg.get("in_app_playback", True):
        audio_url = resolve_yandex_audio_url(track_id, title, artist, cfg)
        source_used = "yandex"

        if not audio_url:
            audio_url = resolve_ytdlp_audio_url(item)
            source_used = "yt-dlp"

        if not audio_url:
            audio_url = item.get("previewUrl") or resolve_deezer_preview_url(title, artist)
            source_used = "preview"

        if audio_url:
            log_debug(f"play OK ({source_used}): {artist} - {title}")
            print(json.dumps({
                "ok": True,
                "mode": "in_app",
                "source": source_used,
                "audioUrl": audio_url,
                "item": item,
            }, ensure_ascii=False))
            return

        log_debug(f"play FAIL: {artist} - {title}")
        print(json.dumps({
            "ok": False,
            "mode": "in_app",
            "error": "Запустите ./auth_yandex.py для прямого стрима Яндекс Музыки",
            "item": item,
        }, ensure_ascii=False))
        return

    if mode == "yandex_app" and platform == "yandex" and track_id:
        album_id = str(item.get("albumId", ""))
        url = f"yandexmusic://album/{album_id}/track/{track_id}" if album_id else f"yandexmusic://track/{track_id}"
    else:
        url = item.get("url") or build_platform_url(platform, title, artist)
    opener = shutil.which("xdg-open") or "xdg-open"
    subprocess.Popen([opener, url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    print(json.dumps({"ok": True, "mode": mode, "url": url}, ensure_ascii=False))


def cmd_queue(platform: str, cfg: dict):
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    items = []
    if QUEUE_FILE.exists():
        try:
            items = json.loads(QUEUE_FILE.read_text(encoding="utf-8"))
        except Exception:
            items = []

    if platform in ("yandex", "automatic") and cfg.get("yandex_music_token"):
        client = get_yandex_client(cfg)
        if client is not None:
            try:
                likes = client.users_likes_tracks()
                if likes and likes.tracks:
                    short_ids = [t.track_id for t in likes.tracks[:14]]
                    full_tracks = client.tracks(short_ids)
                    existing = {(x.get("title", "").lower(), x.get("artist", "").lower()) for x in items}
                    for t in full_tracks:
                        artist_names = ", ".join(a.name for a in (t.artists or []) if a.name) or "Unknown"
                        if (t.title.lower(), artist_names.lower()) in existing:
                            continue
                        album_id = t.albums[0].id if t.albums else ""
                        cover = yandex_cover_url(t.cover_uri or (t.albums[0].cover_uri if t.albums else ""))
                        items.append({
                            "id": str(t.id),
                            "albumId": str(album_id),
                            "title": t.title or "",
                            "artist": artist_names,
                            "album": t.albums[0].title if t.albums else "",
                            "cover": cover,
                            "platform": "yandex",
                            "url": f"https://music.yandex.ru/album/{album_id}/track/{t.id}" if album_id else f"https://music.yandex.ru/track/{t.id}",
                        })
            except Exception:
                pass

    print(json.dumps({"items": items[:15]}, ensure_ascii=False))


# ---------------------------------------------------------------------------
# Synced Lyrics (Yandex Music API + LRCLIB)
# ---------------------------------------------------------------------------

LRC_RE = re.compile(r"\[(\d+):(\d+(?:\.\d+)?)\]\s*(.*)")


def parse_lrc(lrc_text: str) -> list:
    lines = []
    for raw in (lrc_text or "").splitlines():
        matches = list(LRC_RE.finditer(raw))
        if not matches:
            continue
        text = matches[-1].group(3).strip()
        for m in matches:
            mins = int(m.group(1))
            secs = float(m.group(2))
            lines.append({"time": round(mins * 60 + secs, 2), "text": text})
    lines.sort(key=lambda x: x["time"])
    return lines


def fetch_yandex_lyrics(title: str, artist: str, cfg: dict):
    if not cfg.get("yandex_music_token"):
        return None
    client = get_yandex_client(cfg)
    if client is None:
        return None
    try:
        res = client.search(f"{artist} {title}", type_="track")
        if res and res.tracks and res.tracks.results:
            t = res.tracks.results[0]
            try:
                lyr = t.get_lyrics("LRC")
                if lyr and lyr.download_url:
                    req = urllib.request.Request(lyr.download_url, headers={"User-Agent": USER_AGENT})
                    with urllib.request.urlopen(req, timeout=5) as resp:
                        text = resp.read().decode("utf-8", errors="ignore")
                    parsed = parse_lrc(text)
                    if parsed:
                        return {"synced": True, "lines": parsed, "source": "Yandex Music"}
            except Exception:
                pass
    except Exception:
        pass
    return None


def cmd_lyrics(title: str, artist: str, duration: float, alt_index: int, cfg: dict):
    candidates = []

    if alt_index == 0:
        ym = fetch_yandex_lyrics(title, artist, cfg)
        if ym:
            candidates.append(ym)

    try:
        params = urllib.parse.urlencode({"track_name": title, "artist_name": artist})
        if duration and duration > 0:
            params += f"&duration={int(duration)}"
        exact = http_get_json(f"https://lrclib.net/api/get?{params}", timeout=5)
        if exact and exact.get("syncedLyrics"):
            candidates.append({"synced": True, "lines": parse_lrc(exact["syncedLyrics"]), "source": "LRCLIB"})
        elif exact and exact.get("plainLyrics"):
            plain = [{"time": -1, "text": l.strip()} for l in exact["plainLyrics"].splitlines() if l.strip()]
            candidates.append({"synced": False, "lines": plain, "source": "LRCLIB (plain)"})
    except Exception:
        pass

    try:
        q = urllib.parse.quote(f"{artist} {title}".strip())
        results = http_get_json(f"https://lrclib.net/api/search?q={q}", timeout=5)
        if isinstance(results, list):
            for r in results[:6]:
                if r.get("syncedLyrics"):
                    parsed = parse_lrc(r["syncedLyrics"])
                    if parsed:
                        candidates.append({
                            "synced": True,
                            "lines": parsed,
                            "source": f"LRCLIB ({r.get('albumName') or r.get('trackName')})",
                        })
                elif r.get("plainLyrics"):
                    plain = [{"time": -1, "text": l.strip()} for l in r["plainLyrics"].splitlines() if l.strip()]
                    if plain:
                        candidates.append({
                            "synced": False,
                            "lines": plain,
                            "source": f"LRCLIB plain ({r.get('trackName')})",
                        })
    except Exception:
        pass

    if not candidates:
        print(json.dumps({"synced": False, "lines": [], "source": "", "total": 0}))
        return

    idx = alt_index % len(candidates)
    chosen = candidates[idx]
    chosen["total"] = len(candidates)
    chosen["index"] = idx
    print(json.dumps(chosen, ensure_ascii=False))


# ---------------------------------------------------------------------------
# Rock-Solid 16:9 Music Video Resolver
# ---------------------------------------------------------------------------

def resolve_custom_video_backend(title: str, artist: str, cfg: dict) -> str:
    tpl = (cfg.get("custom_video_backend_url") or "").strip()
    if not tpl:
        return ""
    q = f"{artist} {title}".strip()
    url = (
        tpl.replace("{artist}", urllib.parse.quote(artist))
        .replace("{title}", urllib.parse.quote(title))
        .replace("{query}", urllib.parse.quote(q))
    )
    try:
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=6) as resp:
            ctype = (resp.headers.get("Content-Type") or "").lower()
            if "video/" in ctype:
                return resp.geturl()
            body = resp.read().decode("utf-8", errors="ignore").strip()
            if body.startswith("http"):
                return body.splitlines()[0].strip()
            data = json.loads(body)
            return data.get("url") or data.get("videoUrl") or data.get("stream") or ""
    except Exception:
        return ""


def resolve_itunes_music_video(title: str, artist: str) -> str:
    """
    Fastest, zero-auth, RU-accessible official 16:9 HD music videos (.m4v / .mp4)
    directly from Apple's CDN (video-ssl.itunes.apple.com) — decodes natively in QtMultimedia!
    """
    clean_title = re.sub(r"\s*[\(\[].*?[\)\]]", "", title).strip() or title
    primary_artist = re.split(r"[,&/]|feat\.|ft\.", artist, flags=re.I)[0].strip()
    queries = [
        f"{primary_artist} {clean_title}".strip(),
        clean_title,
        primary_artist,
    ]
    for q_raw in queries:
        if not q_raw:
            continue
        q = urllib.parse.quote(q_raw)
        for country in ("US", "RU"):
            try:
                data = http_get_json(
                    f"https://itunes.apple.com/search?term={q}&media=musicVideo&entity=musicVideo&country={country}&limit=5",
                    timeout=5,
                )
                results = data.get("results") or []
                for item in results:
                    purl = item.get("previewUrl") or ""
                    if purl.startswith("http"):
                        return purl
            except Exception:
                continue
    return ""


def resolve_yandex_videoshot(title: str, artist: str, cfg: dict) -> str:
    client = get_yandex_client(cfg)
    if client is None:
        return ""
    try:
        res = client.search(f"{artist} {title}".strip(), type_="track")
        if res and res.tracks and res.tracks.results:
            for t in res.tracks.results[:3]:
                vid_uri = getattr(t, "background_video_uri", None)
                if vid_uri:
                    return vid_uri if vid_uri.startswith("http") else f"https://{vid_uri}"
    except Exception:
        pass
    return ""


def resolve_piped_video(title: str, artist: str, cfg: dict) -> str:
    instances = cfg.get("piped_instances") or []
    clean_title = re.sub(r"\s*[\(\[].*?[\)\]]", "", title).strip() or title
    q = urllib.parse.quote(f"{artist} {clean_title} official music video")
    for base in instances:
        base = base.rstrip("/")
        try:
            search = http_get_json(f"{base}/search?q={q}&filter=videos", timeout=4)
            items = search.get("items") or []
            if not items:
                continue
            vid_path = items[0].get("url") or ""
            m = re.search(r"v=([A-Za-z0-9_-]{11})", vid_path)
            if not m:
                continue
            vid_id = m.group(1)
            streams = http_get_json(f"{base}/streams/{vid_id}", timeout=5)
            vstreams = streams.get("videoStreams") or []
            mp4s = [
                s for s in vstreams
                if "mp4" in (s.get("mimeType") or "").lower()
                and (s.get("height") or 0) <= 1080
                and s.get("url")
            ]
            if mp4s:
                mp4s.sort(key=lambda s: s.get("height") or 0, reverse=True)
                return mp4s[0]["url"]
        except Exception:
            continue
    return ""


def resolve_ytdlp_video(title: str, artist: str) -> str:
    ytdlp = find_bin("yt-dlp")
    if not ytdlp:
        return ""
    clean_title = re.sub(r"\s*[\(\[].*?[\)\]]", "", title).strip() or title
    fmt = "best[height<=720][ext=mp4]/best[height<=1080][ext=mp4]/best[ext=mp4]/best[height<=720]"
    for q in (f"ytsearch1:{artist} {clean_title} official music video", f"ytsearch1:{artist} {clean_title} visualizer"):
        try:
            proc = subprocess.run(
                [ytdlp, "-f", fmt, "-g", "--no-playlist", "--no-warnings", "--socket-timeout", "4", q],
                capture_output=True,
                text=True,
                timeout=7,
            )
            lines = [l.strip() for l in proc.stdout.splitlines() if l.strip().startswith("http")]
            if lines:
                return lines[0]
        except Exception:
            continue
    return ""


def cmd_video_url(title: str, artist: str, cfg: dict):
    if not cfg.get("video_wallpaper", True):
        print(json.dumps({"ok": False, "url": "", "reason": "disabled"}))
        return

    # 1. Custom external video backend
    url = resolve_custom_video_backend(title, artist, cfg)
    src = "custom"
    # 2. Apple/iTunes Official 16:9 Music Video API (fast, works in RU without VPN, native QtMultimedia MP4!)
    if not url:
        url = resolve_itunes_music_video(title, artist)
        src = "itunes_music_video"
    # 3. yt-dlp progressive MP4
    if not url:
        url = resolve_ytdlp_video(title, artist)
        src = "yt-dlp"
    # 4. External Piped API proxy
    if not url:
        url = resolve_piped_video(title, artist, cfg)
        src = "piped"
    # 5. Yandex vertical videoshot only if explicitly enabled
    if not url and cfg.get("prefer_yandex_videoshots", False):
        url = resolve_yandex_videoshot(title, artist, cfg)
        src = "yandex_videoshot"
    # 6. Local fallback video
    if not url:
        url = cfg.get("fallback_video_path", "")
        src = "local"

    log_debug(f"video_url ({src}) for '{artist} - {title}': {'FOUND' if url else 'NONE'}")
    print(json.dumps({"ok": bool(url), "url": url, "source": src}))


def main():
    cfg = load_config()
    if len(sys.argv) < 2:
        print(json.dumps({"error": "missing command"}))
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd == "search":
        platform = sys.argv[2] if len(sys.argv) > 2 else "yandex"
        query = sys.argv[3] if len(sys.argv) > 3 else ""
        cmd_search(platform, query, cfg)
    elif cmd == "play":
        payload = sys.argv[2] if len(sys.argv) > 2 else "{}"
        cmd_play(payload, cfg)
    elif cmd == "queue":
        platform = sys.argv[2] if len(sys.argv) > 2 else "yandex"
        cmd_queue(platform, cfg)
    elif cmd == "lyrics":
        title = sys.argv[2] if len(sys.argv) > 2 else ""
        artist = sys.argv[3] if len(sys.argv) > 3 else ""
        duration = float(sys.argv[4]) if len(sys.argv) > 4 and sys.argv[4] else 0.0
        alt_index = int(sys.argv[5]) if len(sys.argv) > 5 and sys.argv[5] else 0
        cmd_lyrics(title, artist, duration, alt_index, cfg)
    elif cmd in ("video_url", "video_bg"):
        title = sys.argv[2] if len(sys.argv) > 2 else ""
        artist = sys.argv[3] if len(sys.argv) > 3 else ""
        cmd_video_url(title, artist, cfg)
    elif cmd == "has_shader":
        qsb = BASE_DIR / "shaders" / "liquid_glass.frag.qsb"
        print(json.dumps({"available": qsb.exists()}))
    else:
        print(json.dumps({"error": f"unknown command: {cmd}"}))
        sys.exit(1)


if __name__ == "__main__":
    main()
