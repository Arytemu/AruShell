import QtQuick
import "../services"

/**
 * Material 3 Expressive Chubby Circular Wavy Gauge (for CPU / RAM / Disk):
 * - Flowing thick sinusoidal wave along the active circular arc
 * - Clean rounded circular track behind it
 */
Item {
    id: root

    property real percent: 0 // 0 .. 100
    property color activeColor: MusicState.m3Primary
    property color trackColor: MusicState.m3SurfaceContainer
    property real lineWidth: 7.5
    property real amplitude: 2.3
    property int waveCount: 10
    property bool animated: true

    implicitWidth: 88
    implicitHeight: 88

    property real smoothPct: Math.max(0, Math.min(100, percent))
    Behavior on smoothPct { M3Anim { duration: 480 } }

    property real phase: 0.0
    NumberAnimation on phase {
        from: 0.0
        to: Math.PI * 2
        duration: 2400
        loops: Animation.Infinite
        running: root.visible && root.animated && root.smoothPct > 1
    }

    function cssColor(c) {
        if (!c) return "rgba(255,255,255,1)"
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + c.a.toFixed(3) + ")"
    }

    onSmoothPctChanged: gaugeCanvas.requestPaint()
    onPhaseChanged: gaugeCanvas.requestPaint()
    onActiveColorChanged: gaugeCanvas.requestPaint()
    onTrackColorChanged: gaugeCanvas.requestPaint()
    onWidthChanged: gaugeCanvas.requestPaint()
    onHeightChanged: gaugeCanvas.requestPaint()
    onVisibleChanged: if (visible) gaugeCanvas.requestPaint()

    Canvas {
        id: gaugeCanvas
        anchors.fill: parent
        antialiasing: true
        Component.onCompleted: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const cx = width / 2
            const cy = height / 2
            const baseR = Math.min(cx, cy) - root.lineWidth / 2 - root.amplitude - 2
            if (baseR <= 6) return

            ctx.lineWidth = root.lineWidth
            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            // Full subtle circular track
            ctx.strokeStyle = root.cssColor(root.trackColor)
            ctx.beginPath()
            ctx.arc(cx, cy, baseR, 0, Math.PI * 2)
            ctx.stroke()

            // Active chubby wavy arc
            const frac = Math.max(0.0, Math.min(1.0, root.smoothPct / 100.0))
            if (frac <= 0.005) return

            const startAng = -Math.PI / 2
            const sweep = frac * Math.PI * 2
            const steps = Math.max(16, Math.round(sweep * 26))

            ctx.strokeStyle = root.cssColor(root.activeColor)
            ctx.beginPath()
            for (let i = 0; i <= steps; i++) {
                const t = i / steps
                const ang = startAng + t * sweep
                const edgeFade = frac > 0.98 ? 1.0 : Math.min(1.0, t * 8.0, (1.0 - t) * 8.0)
                const r = baseR + Math.sin(ang * root.waveCount - root.phase) * root.amplitude * edgeFade
                const x = cx + Math.cos(ang) * r
                const y = cy + Math.sin(ang) * r
                if (i === 0) ctx.moveTo(x, y)
                else ctx.lineTo(x, y)
            }
            ctx.stroke()
        }
    }

    Text {
        anchors.centerIn: parent
        text: Math.round(root.smoothPct) + "%"
        color: MusicState.m3OnSurface
        font.family: MusicState.fontUi
        font.pixelSize: 16
        font.weight: Font.Bold
    }
}
