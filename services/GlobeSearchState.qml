pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Interactive 3D Globe Web Search State (bound to SUPER + B).
 */
Singleton {
    id: root

    property bool open: false
    property bool loading: false
    property string query: ""
    property var results: []
    property int page: 0
    property int searchSeq: 0

    readonly property string searchScript: Qt.resolvedUrl("websearch.py").toString().replace("file://", "")
    readonly property int totalPages: Math.max(1, Math.ceil((results ? results.length : 0) / 6))

    function toggle() {
        if (open) {
            close()
        } else {
            NotifState.closeAllPopups()
            SystemState.quickSettingsOpen = false
            SystemState.langMenuOpen = false
            SystemState.launcherOpen = false
            ClipboardState.open = false
            open = true
        }
    }

    function close() {
        open = false
    }

    function clearResults() {
        query = ""
        results = []
        page = 0
        loading = false
    }

    function nextPage() {
        if (totalPages > 1) page = (page + 1) % totalPages
    }

    function prevPage() {
        if (totalPages > 1) page = (page - 1 + totalPages) % totalPages
    }

    function search(q) {
        const s = String(q || "").trim()
        query = s
        if (s === "") {
            results = []
            page = 0
            loading = false
            return
        }
        loading = true
        page = 0
        results = []
        searchSeq += 1
        if (searchProc.running) searchProc.running = false
        searchProc.command = ["python3", searchScript, s]
        searchProc.running = true
    }

    function openUrl(url) {
        const u = String(url || "").trim()
        if (!u) return
        close()
        Quickshell.execDetached([
            "bash", "-c",
            'SIG="${HYPRLAND_INSTANCE_SIGNATURE:-}"; if [ -z "$SIG" ] || [ ! -S "/run/user/$(id -u)/hypr/$SIG/.socket.sock" ]; then SIG="$(ls -t "/run/user/$(id -u)/hypr" 2>/dev/null | head -n 1)"; fi; export HYPRLAND_INSTANCE_SIGNATURE="$SIG"; BIN="$(command -v firefox || command -v zen-browser || command -v xdg-open)"; if [ -n "$BIN" ]; then if command -v hyprctl >/dev/null 2>&1 && [ -n "$SIG" ]; then hyprctl dispatch exec "$BIN \"$1\"" >/dev/null 2>&1; elif command -v systemd-run >/dev/null 2>&1; then systemd-run --user --scope -- "$BIN" "$1" >/dev/null 2>&1 & else setsid -f "$BIN" "$1" >/dev/null 2>&1; fi; fi',
            "_", u
        ])
    }

    Process {
        id: searchProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                const s = line.trim()
                if (!s.startsWith("[")) return
                try {
                    const arr = JSON.parse(s)
                    root.results = Array.isArray(arr) ? arr : []
                    root.page = 0
                } catch (e) {
                    root.results = []
                }
                root.loading = false
            }
        }
        onExited: function() {
            root.loading = false
        }
    }
}
