pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Clipboard History Service powered by cliphist + wl-copy.
 * Triggered via SUPER + V or Quick Settings.
 */
Singleton {
    id: root

    property bool open: false
    property var items: []
    property bool hasCliphist: true

    function toggle() {
        open = !open
        if (open) {
            SystemState.quickSettingsOpen = false
            SystemState.launcherOpen = false
            NotifState.closeAllPopups()
            refresh()
        }
    }

    function refresh() {
        if (listProc.running) return
        listProc.command = ["bash", "-c", "if command -v cliphist >/dev/null 2>&1; then cliphist list | head -n 40 | python3 -c 'import sys,json; out=[]; [out.append({\"id\":p[0],\"text\":p[1].strip(),\"isImage\":\"binary data\" in p[1].lower()}) for l in sys.stdin if \"\\t\" in l for p in [l.split(\"\\t\",1)]]; print(json.dumps(out,ensure_ascii=False))'; else echo '{\"missing\":true}'; fi"]
        listProc.running = true
    }

    function copyItem(itemId) {
        if (!itemId) return
        Quickshell.execDetached(["bash", "-c", "printf '%s\\t\\n' " + JSON.stringify(String(itemId)) + " | cliphist decode | wl-copy"])
        open = false
    }

    function deleteItem(itemId) {
        if (!itemId) return
        Quickshell.execDetached(["bash", "-c", "printf '%s\\t\\n' " + JSON.stringify(String(itemId)) + " | cliphist delete"])
        delayedRefresh.restart()
    }

    function clearAll() {
        Quickshell.execDetached(["bash", "-c", "cliphist wipe"])
        items = []
    }

    Timer {
        id: delayedRefresh
        interval: 250
        repeat: false
        onTriggered: root.refresh()
    }

    Process {
        id: listProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                const s = line.trim()
                if (s.startsWith("{")) {
                    root.hasCliphist = false
                    root.items = []
                    return
                }
                if (!s.startsWith("[")) return
                try {
                    root.hasCliphist = true
                    root.items = JSON.parse(s)
                } catch (e) {}
            }
        }
    }
}
