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
    readonly property string clipScript: Qt.resolvedUrl("clip_preview.py").toString().replace("file://", "")

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
        listProc.command = ["python3", root.clipScript]
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
