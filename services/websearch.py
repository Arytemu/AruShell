#!/usr/bin/env python3
import html
import json
import re
import sys
import urllib.parse
import urllib.request

UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"

def clean_ddg_url(href: str) -> str:
    href = html.unescape(href or "").strip()
    if "uddg=" in href:
        qs = urllib.parse.parse_qs(urllib.parse.urlparse(href).query)
        if "uddg" in qs and qs["uddg"]:
            return qs["uddg"][0]
    if href.startswith("//"):
        return "https:" + href
    return href

def domain_of(url: str) -> str:
    try:
        host = urllib.parse.urlparse(url).netloc.lower()
        return host[4:] if host.startswith("www.") else host
    except Exception:
        return ""

def make_item(title: str, url: str) -> dict:
    dom = domain_of(url)
    return {
        "title": html.unescape(re.sub(r"\s+", " ", title or "")).strip(),
        "url": url,
        "domain": dom,
        "favicon": f"https://www.google.com/s2/favicons?domain={urllib.parse.quote(dom)}&sz=64" if dom else "",
    }

def search_ddg(query: str, limit: int = 12) -> list:
    url = "https://html.duckduckgo.com/html/?q=" + urllib.parse.quote_plus(query)
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept-Language": "ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7"})
    with urllib.request.urlopen(req, timeout=6) as resp:
        body = resp.read().decode("utf-8", errors="ignore")
    results = []
    seen = set()
    for m in re.finditer(r'<a[^>]+class="[^"]*result__a[^"]*"[^>]+href="([^"]+)"[^>]*>(.*?)</a>', body, re.S):
        href = clean_ddg_url(m.group(1))
        title = re.sub(r"<[^>]+>", "", m.group(2))
        if not href.startswith("http") or href in seen:
            continue
        seen.add(href)
        results.append(make_item(title, href))
        if len(results) >= limit:
            break
    return results

def search_wiki(query: str, lang: str = "ru", limit: int = 6) -> list:
    url = f"https://{lang}.wikipedia.org/w/api.php?action=opensearch&search={urllib.parse.quote_plus(query)}&limit={limit}&format=json"
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=5) as resp:
        data = json.loads(resp.read().decode("utf-8", errors="ignore"))
    titles = data[1] if len(data) > 1 else []
    urls = data[3] if len(data) > 3 else []
    out = []
    for t, u in zip(titles, urls):
        if u and u.startswith("http"):
            out.append(make_item(f"{t} — Wikipedia", u))
    return out

def main():
    query = " ".join(sys.argv[1:]).strip()
    if not query:
        print("[]")
        return
    results = []
    try:
        results = search_ddg(query, 12)
    except Exception:
        results = []

    if len(results) < 4:
        seen = {r["url"] for r in results}
        for lang in ("ru", "en"):
            try:
                for item in search_wiki(query, lang, 6):
                    if item["url"] not in seen:
                        seen.add(item["url"])
                        results.append(item)
            except Exception:
                pass

    if not results:
        q = urllib.parse.quote_plus(query)
        results = [
            make_item(f"Google: {query}", f"https://www.google.com/search?q={q}"),
            make_item(f"DuckDuckGo: {query}", f"https://duckduckgo.com/?q={q}"),
            make_item(f"YouTube: {query}", f"https://www.youtube.com/results?search_query={q}"),
            make_item(f"GitHub: {query}", f"https://github.com/search?q={q}"),
            make_item(f"Wikipedia: {query}", f"https://ru.wikipedia.org/w/index.php?search={q}"),
            make_item(f"Reddit: {query}", f"https://www.reddit.com/search/?q={q}"),
        ]

    print(json.dumps(results[:12], ensure_ascii=False))

if __name__ == "__main__":
    main()
