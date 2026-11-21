pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Wallpaper Scanner, Carousel & Material You Color Extraction Service (SUPER + W).
 * Scans user-added custom folders first, then standard wallpaper directories,
 * and extracts the dominant vibrant accent color for live HUD recoloring.
 */
Singleton {
    id: root

    property bool open: false
    property var wallpapers: [] // [{ path, name, folder }]
    property int currentIndex: 0
    property bool scanning: false
    property string _lastColorPath: ""

    readonly property string _extractorScript: Quickshell.shellDir + "/services/extract_color.py"
    readonly property string _venvPy: Quickshell.shellDir + "/.venv/bin/python3"

    function toggle() {
        open = !open
        if (open) {
            ShellConfig.closeDesktopMenu()
            ShellConfig.settingsOpen = false
            SystemState.quickSettingsOpen = false
            SystemState.launcherOpen = false
            ClipboardState.open = false
            NotifState.closeAllPopups()
            if (wallpapers.length === 0) scan()
            else syncIndexToCurrent()
        }
    }

    function syncIndexToCurrent() {
        const cur = ShellConfig.wallpaperPath || ""
        if (!cur) return
        for (let i = 0; i < wallpapers.length; i++) {
            if (wallpapers[i].path === cur) {
                currentIndex = i
                return
            }
        }
    }

    function selectIndex(idx) {
        if (wallpapers.length === 0) return
        const clamped = ((idx % wallpapers.length) + wallpapers.length) % wallpapers.length
        currentIndex = clamped
        const wp = wallpapers[clamped]
        if (wp && wp.path) {
            ShellConfig.wallpaperPath = wp.path
            ShellConfig.save()
            extractWallpaperColor(wp.path)
        }
    }

    function pickRandom() {
        if (wallpapers.length === 0) return
        const idx = Math.floor(Math.random() * wallpapers.length)
        selectIndex(idx)
    }

    function extractWallpaperColor(path) {
        const clean = String(path || "").trim()
        if (!clean || clean === _lastColorPath) return
        _lastColorPath = clean
        colorProc.running = false
        colorProc.command = [
            "bash", "-c",
            "PY=\"$1\"; SCRIPT=\"$2\"; IMG=\"$3\"; " +
            "if [ -x \"$PY\" ] && \"$PY\" -c 'import PIL' >/dev/null 2>&1; then exec \"$PY\" \"$SCRIPT\" \"$IMG\"; " +
            "else exec python3 \"$SCRIPT\" \"$IMG\"; fi",
            "_", _venvPy, _extractorScript, clean
        ]
        Qt.callLater(function() {
            colorProc.running = true
        })
    }

    function addCustomFolder(folderPath) {
        const clean = String(folderPath || "").trim().replace(/\/+$/, "")
        if (!clean) return
        const list = (ShellConfig.wallpaperDirs || []).slice()
        if (list.indexOf(clean) === -1) {
            list.push(clean)
            ShellConfig.wallpaperDirs = list
            ShellConfig.save()
        }
        scan()
    }

    function removeCustomFolder(folderPath) {
        const list = (ShellConfig.wallpaperDirs || []).filter(function(d) { return d !== folderPath })
        ShellConfig.wallpaperDirs = list
        ShellConfig.save()
        scan()
    }

    function browseFolderDialog() {
        if (browseProc.running) return
        browseProc.command = ["bash", "-c",
            "if command -v zenity >/dev/null 2>&1; then zenity --file-selection --directory --title='Выберите папку с обоями' 2>/dev/null; " +
            "elif command -v kdialog >/dev/null 2>&1; then kdialog --getexistingdirectory \"$HOME\" 2>/dev/null; " +
            "else echo ''; fi"
        ]
        browseProc.running = true
    }

    function scan() {
        if (scanProc.running) return
        scanning = true
        const customJson = JSON.stringify(ShellConfig.wallpaperDirs || [])
        scanProc.command = ["python3", "-c",
            "import os, sys, json\n" +
            "exts = {'.jpg','.jpeg','.png','.webp'}\n" +
            "custom = json.loads(sys.argv[1])\n" +
            "defaults = ['~/Pictures/Wallpapers','~/Wallpapers','~/Pictures','~/Изображения','~/.local/share/wallpapers','~/.config/hypr/wallpapers','/usr/share/backgrounds']\n" +
            "dirs = custom + defaults\n" +
            "seen, out = set(), []\n" +
            "for d in dirs:\n" +
            "    dp = os.path.expanduser(d)\n" +
            "    if not os.path.isdir(dp): continue\n" +
            "    for root, _, files in os.walk(dp):\n" +
            "        if 'Screenshots' in root or '.thumbs' in root: continue\n" +
            "        for fn in sorted(files):\n" +
            "            if os.path.splitext(fn)[1].lower() not in exts: continue\n" +
            "            fp = os.path.join(root, fn)\n" +
            "            if fp in seen: continue\n" +
            "            try:\n" +
            "                if os.path.getsize(fp) < 25000: continue\n" +
            "            except Exception: continue\n" +
            "            seen.add(fp)\n" +
            "            out.append({'path': fp, 'name': os.path.splitext(fn)[0], 'folder': os.path.basename(root)})\n" +
            "            if len(out) >= 120: break\n" +
            "        if len(out) >= 120: break\n" +
            "print(json.dumps(out, ensure_ascii=False))\n",
            customJson
        ]
        scanProc.running = true
    }

    Connections {
        target: ShellConfig
        function onWallpaperPathChanged() {
            if (ShellConfig.wallpaperPath !== "") {
                root.extractWallpaperColor(ShellConfig.wallpaperPath)
            }
        }
        function on_LoadedChanged() {
            if (ShellConfig._loaded && ShellConfig.wallpaperPath !== "") {
                root.extractWallpaperColor(ShellConfig.wallpaperPath)
            }
        }
    }

    Process {
        id: colorProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                const hex = line.trim()
                if (/^#[0-9a-fA-F]{6}$/.test(hex)) {
                    MusicState.wallSeedHex = hex
                }
            }
        }
    }

    Process {
        id: browseProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                const p = line.trim()
                if (p !== "") root.addCustomFolder(p)
            }
        }
    }

    Process {
        id: scanProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                const s = line.trim()
                if (!s.startsWith("[")) return
                try {
                    root.wallpapers = JSON.parse(s)
                    root.scanning = false
                    root.syncIndexToCurrent()
                    if (ShellConfig.wallpaperPath === "" && root.wallpapers.length > 0) {
                        ShellConfig.wallpaperPath = root.wallpapers[0].path
                        ShellConfig.save()
                        root.extractWallpaperColor(ShellConfig.wallpaperPath)
                    } else if (ShellConfig.wallpaperPath !== "") {
                        root.extractWallpaperColor(ShellConfig.wallpaperPath)
                    }
                } catch (e) {
                    root.scanning = false
                }
            }
        }
        onExited: root.scanning = false
    }

    Component.onCompleted: {
        if (ShellConfig.wallpaperPath !== "") {
            extractWallpaperColor(ShellConfig.wallpaperPath)
        }
        scan()
    }
}
