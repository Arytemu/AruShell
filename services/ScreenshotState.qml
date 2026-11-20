pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * DarkShadowShell-style Screenshot Service:
 * - Freezes screen at full native resolution via grim BEFORE showing overlay
 * - Queries Hyprland windows for hover-to-capture Window mode
 * - Supports Region (with loupe + handles), Window, and Full Screen modes
 * - Save (Pictures/Screenshots + clipboard), Copy only, Edit (satty/swappy)
 */
Singleton {
    id: root

    property bool active: false
    property bool capturing: false
    property string mode: "region" // "region" | "window" | "screen"
    property string frozenPath: ""
    property string targetMonitor: ""
    property real monitorScale: 1.0
    property var windows: []

    readonly property string scriptPath: Qt.resolvedUrl("screenshot.sh").toString().replace("file://", "")

    function open(initialMode) {
        if (active || capturing) return
        mode = initialMode || "region"
        capturing = true
        NotifState.closeAllPopups()
        SystemState.quickSettingsOpen = false
        SystemState.launcherOpen = false
        freezeDelay.restart()
    }

    function captureFullNow() {
        NotifState.closeAllPopups()
        SystemState.quickSettingsOpen = false
        SystemState.launcherOpen = false
        fullDelay.restart()
    }

    function commit(action, lx, ly, lw, lh) {
        if (!active || frozenPath === "") return
        const src = frozenPath
        const s = monitorScale > 0 ? monitorScale : 1.0
        const px = Math.max(0, Math.round(lx * s))
        const py = Math.max(0, Math.round(ly * s))
        const pw = lw > 0 ? Math.max(1, Math.round(lw * s)) : 0
        const ph = lh > 0 ? Math.max(1, Math.round(lh * s)) : 0

        active = false
        frozenPath = ""
        windows = []

        cropProc.command = ["bash", scriptPath, "crop", src, action || "save", String(px), String(py), String(pw), String(ph)]
        cropProc.running = true
    }

    function cancel() {
        active = false
        capturing = false
        frozenPath = ""
        windows = []
        cleanupProc.command = ["bash", scriptPath, "cleanup"]
        cleanupProc.running = true
    }

    Timer {
        id: freezeDelay
        interval: 80
        repeat: false
        onTriggered: {
            const ts = Date.now()
            const tmpPath = "/tmp/ams-shot-freeze-" + ts + ".png"
            freezeProc.command = ["bash", root.scriptPath, "freeze", "", tmpPath]
            freezeProc.running = true
        }
    }

    Timer {
        id: fullDelay
        interval: 80
        repeat: false
        onTriggered: {
            fullProc.command = ["bash", root.scriptPath, "full", ""]
            fullProc.running = true
        }
    }

    Process {
        id: freezeProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                const trimmed = line.trim()
                if (!trimmed.startsWith("{")) return
                try {
                    const data = JSON.parse(trimmed)
                    root.targetMonitor = data.monitor || ""
                    root.monitorScale = data.scale || 1.0
                    root.windows = data.windows || []
                    root.frozenPath = data.path || ""
                    root.capturing = false
                    if (root.frozenPath !== "") {
                        root.active = true
                    }
                } catch (e) {
                    root.capturing = false
                }
            }
        }
        onExited: function(code) {
            if (code !== 0) {
                root.capturing = false
            }
        }
    }

    Process {
        id: cropProc
    }

    Process {
        id: fullProc
    }

    Process {
        id: cleanupProc
    }
}
