import QtQuick
import Quickshell.Io
import "../services"

/**
 * Rock-Solid Bottom-Anchored Cava Audio Visualizer for Desktop Layer:
 * - Strictly anchored to the bottom edge of the screen (zero vertical jumping!)
 * - Zero CPU/GPU cost when disabled, paused, or minimized to Dynamic Island
 * - Smooth sliders in Settings: Full-Width/Centered, Bar Count (16..96), Height (40..220), Spacing (0..12), Style
 */
Item {
    id: root
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: maxBarHeight

    readonly property bool activeVis: ShellConfig.audioVisualizer && MusicState.hasTrack && MusicState.isPlaying && !MusicState.stageMinimizedToIsland
    readonly property int barCount: Math.max(16, Math.min(96, ShellConfig.visBars))
    readonly property int maxBarHeight: Math.max(40, Math.min(220, ShellConfig.visHeight))
    readonly property int barSpacing: Math.max(0, Math.min(12, ShellConfig.visSpacing))
    readonly property bool fullWidth: ShellConfig.visFullWidth
    readonly property bool mirrorStyle: ShellConfig.visStyle === "mirror"

    property var bars: []

    function resetBars() {
        const arr = []
        for (let i = 0; i < barCount; i++) arr.push(0)
        bars = arr
    }

    Component.onCompleted: resetBars()
    onBarCountChanged: {
        resetBars()
        if (cavaProc.running) {
            cavaProc.running = false
            restartTimer.restart()
        }
    }

    Timer {
        id: restartTimer
        interval: 140
        repeat: false
        onTriggered: if (root.activeVis) cavaProc.running = true
    }

    opacity: activeVis ? 0.92 : 0.0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: 360; easing.type: Easing.InOutCubic } }

    Process {
        id: cavaProc
        running: root.activeVis
        command: [
            "bash", "-c",
            "if ! command -v cava >/dev/null 2>&1; then exit 0; fi; " +
            "CFG=$(mktemp /tmp/arushell_cava.XXXXXX); trap 'rm -f \"$CFG\"' EXIT; " +
            "printf '[general]\\nframerate = 30\\nbars = " + root.barCount + "\\nautosens = 1\\n[output]\\nmethod = raw\\nraw_target = /dev/stdout\\ndata_format = ascii\\nascii_max_range = 100\\n[smoothing]\\nintegral = 70\\nmonstercat = 1\\n' > \"$CFG\"; " +
            "exec cava -p \"$CFG\" 2>/dev/null"
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                const parts = line.trim().split(";")
                if (parts.length < 8) return
                const n = root.barCount
                const arr = []
                for (let i = 0; i < n; i++) {
                    const v = parseInt(parts[i] || "0", 10)
                    arr.push(isNaN(v) ? 0 : Math.max(0, Math.min(100, v)))
                }
                root.bars = arr
            }
        }
    }

    Row {
        id: barRow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 0
        height: root.maxBarHeight
        spacing: root.barSpacing

        readonly property real availableW: root.fullWidth ? Math.max(320, root.width - 16) : Math.min(root.width - 64, 560)
        readonly property real barW: Math.max(2, (availableW - (root.barCount - 1) * root.barSpacing) / root.barCount)

        Repeater {
            model: root.barCount
            delegate: Item {
                id: barSlot
                required property int index
                width: barRow.barW
                height: root.maxBarHeight

                readonly property real level: (root.bars[index] || 0) / 100.0
                property real barScale: Math.max(0.035, level)
                Behavior on barScale { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }

                Rectangle {
                    anchors.fill: parent
                    topLeftRadius: Math.min(width / 2, 5)
                    topRightRadius: Math.min(width / 2, 5)
                    bottomLeftRadius: root.mirrorStyle ? Math.min(width / 2, 5) : 0
                    bottomRightRadius: root.mirrorStyle ? Math.min(width / 2, 5) : 0
                    color: MusicState.m3Primary
                    opacity: 0.28 + barSlot.level * 0.66
                    transform: Scale {
                        origin.x: barSlot.width / 2
                        origin.y: root.mirrorStyle ? (barSlot.height / 2) : barSlot.height
                        yScale: barSlot.barScale
                    }
                }
            }
        }
    }
}
