import QtQuick
import "../services"

/**
 * Material 3 Expressive Shape Primitives (Android 16 / Pixel MaterialShapes):
 * - "ghost"    : Rounded arch top + 3 smooth scalloped waves at bottom (App Launcher)
 * - "gem"      : Soft pillowy rotated diamond / cushion (Notification Bell)
 * - "cookie6"  : Soft plump 6-lobe pillowy cookie (Weather)
 * - "cookie8"  : Soft plump 8-lobe pillowy cookie (Calendar today)
 * - "cookie12" : Soft plump 12-lobe pillowy cookie (Play/Pause)
 * - "clover4"  : 4-leaf soft clover
 * - "squircle" : Superellipse (n = 4.0) smooth M3 squircle
 */
Item {
    id: root

    property string shape: "cookie6"
    property color fillColor: MusicState.m3Primary
    property color strokeColor: "transparent"
    property real strokeWidth: 0
    property real morphFactor: 1.0 // 0.0 = circle, 1.0 = full expressive shape
    property bool spin: false
    property int spinDuration: 18000

    Behavior on morphFactor { M3Anim { duration: 360 } }
    Behavior on fillColor   { ColorAnimation { duration: 220 } }

    function cssColor(c) {
        if (!c) return "rgba(255,255,255,1)"
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + c.a.toFixed(3) + ")"
    }

    onShapeChanged: shapeCanvas.requestPaint()
    onFillColorChanged: shapeCanvas.requestPaint()
    onStrokeColorChanged: shapeCanvas.requestPaint()
    onMorphFactorChanged: shapeCanvas.requestPaint()
    onWidthChanged: shapeCanvas.requestPaint()
    onHeightChanged: shapeCanvas.requestPaint()
    onVisibleChanged: if (visible) shapeCanvas.requestPaint()

    Canvas {
        id: shapeCanvas
        anchors.fill: parent
        antialiasing: true
        renderStrategy: Canvas.Threaded
        Component.onCompleted: requestPaint()

        NumberAnimation on rotation {
            from: 0
            to: 360
            duration: root.spinDuration
            loops: Animation.Infinite
            running: root.visible && root.spin && root.morphFactor > 0.05
        }

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width
            const h = height
            if (w <= 2 || h <= 2) return

            const cx = w / 2
            const cy = h / 2
            const pad = Math.max(1.0, root.strokeWidth)
            const maxR = Math.min(cx, cy) - pad
            const m = Math.max(0.0, Math.min(1.0, root.morphFactor))
            const steps = 128

            ctx.beginPath()

            if (root.shape === "ghost") {
                const left = cx - maxR * 0.88
                const right = cx + maxR * 0.88
                const top = cy - maxR * 0.94
                const bottom = cy + maxR * 0.92
                const domeR = (right - left) / 2
                const domeCy = top + domeR
                const waveBaseY = bottom - maxR * 0.18
                const waveAmp = maxR * 0.14 * m

                ctx.arc(cx, domeCy, domeR, Math.PI, 0, false)
                ctx.lineTo(right, waveBaseY)
                const wSteps = 48
                for (let i = 0; i <= wSteps; i++) {
                    const t = i / wSteps
                    const x = right - t * (right - left)
                    const y = waveBaseY + Math.pow(Math.abs(Math.sin(t * Math.PI * 3)), 0.85) * waveAmp * 1.35
                    ctx.lineTo(x, y)
                }
                ctx.lineTo(left, domeCy)
            } else if (root.shape === "gem") {
                // Soft pillowy Material 3 Expressive Gem / Rotated Cushion (45 deg superellipse)
                const n = 2.0 + 1.15 * m
                const rot = Math.PI / 4
                const cr = Math.cos(rot)
                const sr = Math.sin(rot)
                for (let i = 0; i <= steps; i++) {
                    const t = (i / steps) * Math.PI * 2
                    const ct = Math.cos(t)
                    const st = Math.sin(t)
                    const ux = Math.sign(ct) * Math.pow(Math.abs(ct), 2.0 / n) * maxR * 0.96
                    const uy = Math.sign(st) * Math.pow(Math.abs(st), 2.0 / n) * maxR * 0.96
                    const x = cx + ux * cr - uy * sr
                    const y = cy + ux * sr + uy * cr
                    if (i === 0) ctx.moveTo(x, y)
                    else ctx.lineTo(x, y)
                }
            } else if (root.shape === "squircle") {
                const n = 2.0 + 2.2 * m
                for (let i = 0; i <= steps; i++) {
                    const t = (i / steps) * Math.PI * 2
                    const ct = Math.cos(t)
                    const st = Math.sin(t)
                    const x = cx + Math.sign(ct) * Math.pow(Math.abs(ct), 2.0 / n) * maxR
                    const y = cy + Math.sign(st) * Math.pow(Math.abs(st), 2.0 / n) * maxR
                    if (i === 0) ctx.moveTo(x, y)
                    else ctx.lineTo(x, y)
                }
            } else {
                // Soft, pillowy M3 Expressive Cookies (broad rounded lobes, gentle valleys!)
                let lobes = 12
                let depth = 0.068
                if (root.shape === "cookie6") {
                    lobes = 6
                    depth = 0.082
                } else if (root.shape === "cookie8") {
                    lobes = 8
                    depth = 0.075
                } else if (root.shape === "clover4") {
                    lobes = 4
                    depth = 0.14
                } else if (root.shape === "sunny") {
                    lobes = 10
                    depth = 0.085
                }
                const d = depth * m
                const baseR = maxR / (1.0 + d)
                for (let i = 0; i <= steps; i++) {
                    const t = (i / steps) * Math.PI * 2
                    // Raised pillowy wave: fuller rounded peaks, never sharp valleys
                    const wave = Math.pow(0.5 + 0.5 * Math.cos(lobes * t), 0.78) * 2.0 - 1.0
                    const r = baseR * (1.0 + d * wave)
                    const x = cx + Math.cos(t) * r
                    const y = cy + Math.sin(t) * r
                    if (i === 0) ctx.moveTo(x, y)
                    else ctx.lineTo(x, y)
                }
            }

            ctx.closePath()
            ctx.fillStyle = root.cssColor(root.fillColor)
            ctx.fill()

            if (root.strokeWidth > 0 && root.strokeColor.a > 0.01) {
                ctx.lineWidth = root.strokeWidth
                ctx.strokeStyle = root.cssColor(root.strokeColor)
                ctx.stroke()
            }
        }
    }
}
