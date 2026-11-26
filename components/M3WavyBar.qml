import QtQuick
import "../services"

/**
 * Material 3 Expressive Chubby Wavy Progress Bar / Slider:
 * - Thick, rounded flowing sine wave for the filled portion
 * - Clean rounded track for the remaining portion with M3 Expressive thumb pill
 * - Supports interactive click & drag scrubbing
 */
Item {
    id: root

    property real value: 0.0 // 0.0 .. 1.0
    property color activeColor: MusicState.m3Primary
    property color trackColor: MusicState.m3SurfaceContainerHighest
    property real lineWidth: 5.5
    property real amplitude: 3.6
    property real wavelength: 22.0
    property bool animated: true
    property bool interactive: true
    property bool showThumb: true

    signal moved(real ratio)

    implicitHeight: 22
    height: implicitHeight

    property real smoothVal: Math.max(0.0, Math.min(1.0, value))
    Behavior on smoothVal {
        enabled: !scrubMa.pressed
        M3Anim { duration: 220 }
    }

    property real waveAmp: animated ? amplitude : 1.4
    Behavior on waveAmp { M3Anim { duration: 260 } }

    property real phase: 0.0
    NumberAnimation on phase {
        from: 0.0
        to: Math.PI * 2
        duration: 1300
        loops: Animation.Infinite
        running: root.visible && root.animated && root.smoothVal > 0.01
    }

    function cssColor(c) {
        if (!c) return "rgba(255,255,255,1)"
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + c.a.toFixed(3) + ")"
    }

    property double _lastWavePaint: 0
    function _paintThrottled() {
        if (!visible) return
        const now = Date.now()
        if (now - _lastWavePaint >= 32) {
            _lastWavePaint = now
            waveCanvas.requestPaint()
        }
    }
    onSmoothValChanged: waveCanvas.requestPaint()
    onPhaseChanged: _paintThrottled()
    onWaveAmpChanged: _paintThrottled()
    onActiveColorChanged: _paintThrottled()
    onTrackColorChanged: _paintThrottled()
    onWidthChanged: waveCanvas.requestPaint()
    onHeightChanged: waveCanvas.requestPaint()
    onVisibleChanged: if (visible) waveCanvas.requestPaint()

    Canvas {
        id: waveCanvas
        anchors.fill: parent
        antialiasing: true
        renderStrategy: Canvas.Threaded
        Component.onCompleted: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width
            const h = height
            if (w <= 4 || h <= 4) return

            const cy = h / 2
            const pad = root.lineWidth / 2 + 2
            const usable = Math.max(1, w - pad * 2)
            const ratio = Math.max(0.0, Math.min(1.0, root.smoothVal))
            const fillEnd = pad + usable * ratio
            const gap = root.showThumb ? 7 : 5

            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            ctx.lineWidth = root.lineWidth

            // 1. Unfilled rounded track (with expressive gap after wave)
            const trackStart = ratio > 0.01 ? Math.min(w - pad, fillEnd + gap) : pad
            if (trackStart < w - pad - 1) {
                ctx.strokeStyle = root.cssColor(root.trackColor)
                ctx.beginPath()
                ctx.moveTo(trackStart, cy)
                ctx.lineTo(w - pad, cy)
                ctx.stroke()
            }

            // 2. Chubby animated sine wave for filled portion
            if (ratio > 0.005) {
                const waveEnd = root.showThumb ? Math.max(pad, fillEnd - 4) : fillEnd
                ctx.strokeStyle = root.cssColor(root.activeColor)
                ctx.beginPath()
                const step = 2.5
                const k = (Math.PI * 2) / Math.max(10, root.wavelength)
                let first = true
                for (let x = pad; x <= waveEnd; x += step) {
                    const edgeFade = Math.min(1.0, (x - pad) / 8.0, (waveEnd - x) / 6.0)
                    const amp = root.waveAmp * Math.max(0.0, edgeFade)
                    const y = cy + Math.sin((x - pad) * k - root.phase) * amp
                    if (first) {
                        ctx.moveTo(x, y)
                        first = false
                    } else {
                        ctx.lineTo(x, y)
                    }
                }
                ctx.lineTo(waveEnd, cy)
                ctx.stroke()
            }

            // 3. M3 Expressive Vertical Pill Thumb
            if (root.showThumb) {
                const thumbH = Math.min(h - 4, root.lineWidth * 2.5)
                ctx.strokeStyle = root.cssColor(root.activeColor)
                ctx.lineWidth = 4.2
                ctx.beginPath()
                ctx.moveTo(fillEnd, cy - thumbH / 2 + 2)
                ctx.lineTo(fillEnd, cy + thumbH / 2 - 2)
                ctx.stroke()
            }
        }
    }

    MouseArea {
        id: scrubMa
        anchors.fill: parent
        anchors.topMargin: -4
        anchors.bottomMargin: -4
        enabled: root.interactive
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor

        function emitAt(mx) {
            const ratio = Math.max(0.0, Math.min(1.0, mx / Math.max(1, width)))
            root.moved(ratio)
        }

        onPressed: function(mouse) { emitAt(mouse.x) }
        onPositionChanged: function(mouse) { if (pressed) emitAt(mouse.x) }
    }
}
