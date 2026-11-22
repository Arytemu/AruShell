import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../services"

/**
 * Interactive 3D Earth Globe Web Search Overlay (SUPER + B):
 * - Rotating 3D wireframe + glowing dot-matrix Earth with real world continents (drag to spin!)
 * - Material 3 Search Pill below the globe
 * - Up to 6 floating result pills (3 left, 3 right) connected by animated curved telemetry lines
 * - Clicking any result opens it in the default browser via xdg-open
 */
PanelWindow {
    id: globeWin

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "arushell-globe-search"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    property real rotLon: 0.4
    property real rotLat: 0.24
    property bool dragging: false
    property real lastDragX: 0
    property real lastDragY: 0
    property real introProgress: 0.0
    property real linesProgress: 0.0

    // Fox-Chomp Launch Animation State
    property bool launching: false
    property var chosenItem: null
    property real chosenX: 0
    property real chosenY: 0
    property real chosenScale: 1.0
    property real chosenOpacity: 1.0
    property real foxProgress: 0.0
    property real foxJaw: 0.0
    property real foxScale: 0.0
    property real foxOpacity: 0.0
    property real burstProgress: 0.0

    function triggerFoxLaunch(item, startX, startY) {
        if (launching) return
        launching = true
        chosenItem = item
        chosenX = startX
        chosenY = startY
        chosenScale = 1.0
        chosenOpacity = 1.0
        foxProgress = 0.0
        foxJaw = 0.0
        foxScale = 0.0
        foxOpacity = 0.0
        burstProgress = 0.0
        foxLaunchSeq.restart()
    }

    readonly property var pageResults: {
        const all = GlobeSearchState.results || []
        const start = GlobeSearchState.page * 6
        return all.slice(start, start + 6)
    }

    Component.onCompleted: {
        introProgress = 1.0
        searchField.forceActiveFocus()
        if (GlobeSearchState.results && GlobeSearchState.results.length > 0) {
            linesProgress = 1.0
        }
    }

    Behavior on introProgress { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
    Behavior on linesProgress { NumberAnimation { duration: 520; easing.type: Easing.OutQuart } }

    Connections {
        target: GlobeSearchState
        function onResultsChanged() {
            linesProgress = 0.0
            if (GlobeSearchState.results && GlobeSearchState.results.length > 0) {
                linesDelay.restart()
            }
            connectorCanvas.requestPaint()
        }
        function onPageChanged() {
            linesProgress = 0.0
            linesDelay.restart()
        }
    }

    Timer {
        id: linesDelay
        interval: 40
        repeat: false
        onTriggered: globeWin.linesProgress = 1.0
    }

    onLinesProgressChanged: connectorCanvas.requestPaint()
    onFoxProgressChanged: foxCanvas.requestPaint()
    onFoxJawChanged: foxCanvas.requestPaint()
    onBurstProgressChanged: foxCanvas.requestPaint()

    SequentialAnimation {
        id: foxLaunchSeq

        // Phase 1: Slide chosen card to exact center while globe & other cards vanish
        ParallelAnimation {
            NumberAnimation {
                target: globeWin; property: "chosenX"
                to: Math.round((rootStage.width - 268) / 2)
                duration: 290; easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: globeWin; property: "chosenY"
                to: Math.round((rootStage.height - 58) / 2)
                duration: 290; easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: globeWin; property: "chosenScale"
                to: 1.12; duration: 290; easing.type: Easing.OutBack
            }
        }

        // Phase 2: Firefox Fox swoops in from the left with jaw open wide!
        ParallelAnimation {
            NumberAnimation { target: globeWin; property: "foxOpacity"; to: 1.0; duration: 150; easing.type: Easing.OutCubic }
            NumberAnimation { target: globeWin; property: "foxScale";   to: 1.0; duration: 240; easing.type: Easing.OutBack }
            NumberAnimation { target: globeWin; property: "foxProgress"; from: 0.0; to: 0.62; duration: 280; easing.type: Easing.OutCubic }
            NumberAnimation { target: globeWin; property: "foxJaw";     from: 0.0; to: 1.0;  duration: 240; easing.type: Easing.OutCubic }
        }

        // Phase 3: CHOMP! Fox bites down, swallows the card with fiery sparks!
        ParallelAnimation {
            NumberAnimation { target: globeWin; property: "foxProgress"; to: 1.0; duration: 190; easing.type: Easing.InCubic }
            NumberAnimation { target: globeWin; property: "foxJaw";      to: 0.0; duration: 150; easing.type: Easing.InBack }
            NumberAnimation { target: globeWin; property: "chosenScale"; to: 0.0; duration: 170; easing.type: Easing.InBack }
            NumberAnimation { target: globeWin; property: "chosenOpacity"; to: 0.0; duration: 150; easing.type: Easing.InCubic }
            NumberAnimation { target: globeWin; property: "burstProgress"; from: 0.0; to: 1.0; duration: 300; easing.type: Easing.OutCubic }
        }

        // Phase 4: Happy fox gulp pulse & fade straight into Firefox!
        ParallelAnimation {
            NumberAnimation { target: globeWin; property: "foxScale";   to: 1.28; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: globeWin; property: "foxOpacity"; to: 0.0;  duration: 220; easing.type: Easing.InCubic }
        }

        ScriptAction {
            script: {
                const u = globeWin.chosenItem ? globeWin.chosenItem.url : ""
                globeWin.launching = false
                GlobeSearchState.openUrl(u)
            }
        }
    }

    // Smooth 60fps globe rotation timer
    Timer {
        interval: 16
        running: globeWin.visible
        repeat: true
        onTriggered: {
            if (!globeWin.dragging) {
                globeWin.rotLon += GlobeSearchState.loading ? 0.022 : 0.0055
            }
            globeCanvas.requestPaint()
        }
    }

    Item {
        id: rootStage
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: GlobeSearchState.close()

        // Atmospheric translucent scrim (click outside to close)
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.02, 0.03, 0.04, 0.78 * globeWin.introProgress)
            MouseArea {
                anchors.fill: parent
                onClicked: GlobeSearchState.close()
            }
        }

        // Animated Curved Bezier Connector Lines from Globe Perimeter to 6 Result Pills
        Canvas {
            id: connectorCanvas
            anchors.fill: parent
            opacity: globeWin.launching ? 0.0 : 1.0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            z: 2

            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                const items = globeWin.pageResults
                if (!items || items.length === 0 || globeWin.linesProgress <= 0.01) return

                const cx = globeContainer.x + globeContainer.width / 2
                const cy = globeContainer.y + globeContainer.height / 2
                const r = globeContainer.width / 2 - 8

                const prim = MusicState.m3Primary
                const onS = MusicState.m3OnSurface
                const lineCol = Qt.rgba(onS.r, onS.g, onS.b, 0.55)
                const dotCol = Qt.rgba(prim.r, prim.g, prim.b, 0.95)

                // 3 left anchor angles, 3 right anchor angles
                const slots = [
                    { side: -1, ang: -2.55, row: 0 },
                    { side: -1, ang:  3.14, row: 1 },
                    { side: -1, ang:  2.55, row: 2 },
                    { side:  1, ang: -0.59, row: 0 },
                    { side:  1, ang:  0.00, row: 1 },
                    { side:  1, ang:  0.59, row: 2 }
                ]

                for (let i = 0; i < Math.min(items.length, 6); i++) {
                    const sl = slots[i]
                    const stagger = Math.max(0.0, Math.min(1.0, (globeWin.linesProgress - i * 0.06) / 0.62))
                    if (stagger <= 0.01) continue

                    const sx = cx + Math.cos(sl.ang) * (r * 0.92)
                    const sy = cy + Math.sin(sl.ang) * (r * 0.92)

                    const cardW = 248
                    const cardH = 54
                    const gapX = 96
                    const cardY = cy - 122 + sl.row * 102
                    const ex = sl.side < 0 ? (cx - r - gapX) : (cx + r + gapX)
                    const ey = cardY + cardH / 2

                    const c1x = sx + sl.side * 42
                    const c1y = sy + (sl.row - 1) * 14
                    const c2x = ex - sl.side * 44
                    const c2y = ey

                    // Sample partial cubic Bezier up to stagger
                    const steps = 28
                    const maxStep = Math.max(1, Math.floor(steps * stagger))
                    ctx.beginPath()
                    for (let s = 0; s <= maxStep; s++) {
                        const t = (s / steps)
                        const mt = 1 - t
                        const px = mt*mt*mt*sx + 3*mt*mt*t*c1x + 3*mt*t*t*c2x + t*t*t*ex
                        const py = mt*mt*mt*sy + 3*mt*mt*t*c1y + 3*mt*t*t*c2y + t*t*t*ey
                        if (s === 0) ctx.moveTo(px, py)
                        else ctx.lineTo(px, py)
                    }
                    ctx.strokeStyle = lineCol
                    ctx.lineWidth = 1.6
                    ctx.stroke()

                    // Glowing dot on globe surface
                    ctx.beginPath()
                    ctx.arc(sx, sy, 3.2, 0, Math.PI * 2)
                    ctx.fillStyle = dotCol
                    ctx.fill()

                    // Traveling tip dot
                    const tipT = maxStep / steps
                    const mtt = 1 - tipT
                    const tx = mtt*mtt*mtt*sx + 3*mtt*mtt*tipT*c1x + 3*mtt*tipT*tipT*c2x + tipT*tipT*tipT*ex
                    const ty = mtt*mtt*mtt*sy + 3*mtt*mtt*tipT*c1y + 3*mtt*tipT*tipT*c2y + tipT*tipT*tipT*ey
                    ctx.beginPath()
                    ctx.arc(tx, ty, 2.5, 0, Math.PI * 2)
                    ctx.fillStyle = Qt.rgba(onS.r, onS.g, onS.b, 0.9)
                    ctx.fill()
                }
            }
        }

        // Page Switcher Pill above Globe (shown when > 6 results)
        Rectangle {
            visible: !globeWin.launching && GlobeSearchState.totalPages > 1 && globeWin.pageResults.length > 0
            anchors {
                horizontalCenter: globeContainer.horizontalCenter
                bottom: globeContainer.top
                bottomMargin: 16
            }
            height: 30
            width: pageRow.implicitWidth + 20
            radius: 15
            color: MusicState.m3SurfaceContainer
            border.width: 1
            border.color: MusicState.m3OutlineVariant
            z: 6

            RowLayout {
                id: pageRow
                anchors.centerIn: parent
                spacing: 10

                SysIcon {
                    name: "chevron_left"
                    size: 13
                    color: MusicState.m3OnSurface
                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: GlobeSearchState.prevPage() }
                }
                Text {
                    text: (GlobeSearchState.page + 1) + " / " + GlobeSearchState.totalPages
                    color: MusicState.m3OnSurfaceVariant
                    font.family: MusicState.fontUi
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }
                SysIcon {
                    name: "chevron_right"
                    size: 13
                    color: MusicState.m3OnSurface
                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: GlobeSearchState.nextPage() }
                }
            }
        }

        // =====================================================================
        // Center 3D Wireframe / Glowing Earth Globe (Interactive — Drag to Spin!)
        // =====================================================================
        Item {
            id: globeContainer
            width: 340
            height: 340
            anchors {
                horizontalCenter: parent.horizontalCenter
                verticalCenter: parent.verticalCenter
                verticalCenterOffset: -42
            }
            scale: globeWin.launching ? 0.65 : (0.72 + 0.28 * globeWin.introProgress)
            opacity: globeWin.launching ? 0.0 : globeWin.introProgress
            Behavior on scale   { NumberAnimation { duration: 240; easing.type: Easing.InCubic } }
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            z: 4

            Canvas {
                id: globeCanvas
                anchors.fill: parent

                // Real simplified world continent coastline polylines [lat_deg, lon_deg]
                readonly property var continents: [
                    // North America
                    [[70,-162],[68,-135],[60,-135],[55,-130],[49,-124],[38,-123],[32,-117],[23,-110],[16,-95],[10,-84],[15,-83],[21,-87],[20,-97],[26,-97],[30,-89],[25,-81],[31,-81],[39,-74],[44,-66],[47,-53],[54,-56],[60,-65],[66,-80],[70,-95],[71,-130],[70,-162]],
                    // Greenland
                    [[60,-44],[66,-53],[76,-68],[82,-35],[76,-18],[68,-26],[60,-44]],
                    // South America
                    [[10,-75],[11,-63],[5,-52],[-5,-35],[-15,-39],[-23,-43],[-35,-57],[-52,-68],[-54,-71],[-42,-74],[-18,-71],[-5,-81],[4,-77],[10,-75]],
                    // Europe
                    [[36,-9],[43,-9],[44,-1],[48,-5],[51,2],[54,8],[58,6],[64,10],[70,22],[69,33],[66,42],[60,30],[54,19],[51,14],[46,14],[40,18],[38,24],[41,29],[45,29],[44,12],[40,0],[36,-5],[36,-9]],
                    // UK
                    [[50,-5],[54,-3],[58,-5],[57,-2],[52,1],[50,-5]],
                    // Africa
                    [[35,-6],[37,10],[32,15],[31,32],[22,37],[12,44],[11,51],[2,45],[-10,40],[-26,33],[-34,25],[-34,18],[-22,14],[-6,12],[4,9],[5,-4],[10,-15],[21,-17],[32,-9],[35,-6]],
                    // Madagascar
                    [[-12,49],[-18,49],[-25,47],[-25,44],[-16,44],[-12,49]],
                    // Asia
                    [[41,29],[46,39],[55,60],[68,70],[73,100],[71,135],[66,170],[60,164],[52,141],[43,132],[35,129],[38,121],[31,122],[22,114],[16,108],[10,105],[1,104],[10,98],[22,91],[16,80],[8,77],[22,69],[25,60],[30,48],[26,56],[13,45],[20,40],[31,35],[37,27],[41,29]],
                    // Japan
                    [[31,131],[35,137],[39,141],[43,145],[44,142],[38,139],[34,132],[31,131]],
                    // Indonesia / SE islands
                    [[5,96],[-6,106],[-8,115],[-7,108],[1,100],[5,96]],
                    [[-1,109],[5,117],[1,118],[-3,115],[-1,109]],
                    // Australia
                    [[-12,131],[-12,136],[-15,141],[-11,142],[-20,149],[-28,153],[-37,150],[-38,141],[-32,133],[-34,115],[-22,114],[-16,123],[-12,131]],
                    // New Zealand
                    [[-35,173],[-41,175],[-46,168],[-43,170],[-38,175],[-35,173]]
                ]

                function project(latDeg, lonDeg, cx, cy, R) {
                    const lat = latDeg * Math.PI / 180.0
                    const lon = lonDeg * Math.PI / 180.0 + globeWin.rotLon
                    const cosLat = Math.cos(lat)
                    const x0 = cosLat * Math.sin(lon)
                    const y0 = Math.sin(lat)
                    const z0 = cosLat * Math.cos(lon)

                    // Tilt by rotLat
                    const cosT = Math.cos(globeWin.rotLat)
                    const sinT = Math.sin(globeWin.rotLat)
                    const y1 = y0 * cosT - z0 * sinT
                    const z1 = y0 * sinT + z0 * cosT
                    return { x: cx + x0 * R, y: cy - y1 * R, z: z1 }
                }

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    const cx = width / 2
                    const cy = height / 2
                    const R = Math.min(width, height) * 0.44

                    const prim = MusicState.m3Primary
                    const pCont = MusicState.m3PrimaryContainer
                    const sCont = MusicState.m3SurfaceContainer
                    const sLow = MusicState.m3SurfaceContainerLowest
                    const tert = MusicState.m3Tertiary
                    const onS = MusicState.m3OnSurface

                    // Outer Material You atmospheric halo glow
                    const halo = ctx.createRadialGradient(cx, cy, R * 0.72, cx, cy, R * 1.18)
                    halo.addColorStop(0.0, Qt.rgba(prim.r, prim.g, prim.b, 0.0))
                    halo.addColorStop(0.74, Qt.rgba(prim.r, prim.g, prim.b, 0.22))
                    halo.addColorStop(1.0, Qt.rgba(prim.r, prim.g, prim.b, 0.0))
                    ctx.fillStyle = halo
                    ctx.beginPath()
                    ctx.arc(cx, cy, R * 1.18, 0, Math.PI * 2)
                    ctx.fill()

                    // Dynamic Material You sphere interior (tinted directly by live HUD palette!)
                    const sphereGrad = ctx.createRadialGradient(cx - R * 0.28, cy - R * 0.28, R * 0.08, cx, cy, R)
                    sphereGrad.addColorStop(0.0, Qt.rgba(pCont.r, pCont.g, pCont.b, 0.95))
                    sphereGrad.addColorStop(0.55, Qt.rgba(sCont.r, sCont.g, sCont.b, 0.96))
                    sphereGrad.addColorStop(0.88, Qt.rgba(sLow.r, sLow.g, sLow.b, 0.98))
                    sphereGrad.addColorStop(1.0, Qt.rgba(prim.r * 0.48, prim.g * 0.48, prim.b * 0.48, 0.95))
                    ctx.fillStyle = sphereGrad
                    ctx.beginPath()
                    ctx.arc(cx, cy, R, 0, Math.PI * 2)
                    ctx.fill()

                    // Subtle HUD-tinted latitude / longitude graticule
                    ctx.strokeStyle = Qt.rgba(prim.r, prim.g, prim.b, 0.16)
                    ctx.lineWidth = 0.8
                    for (let lat = -60; lat <= 60; lat += 30) {
                        ctx.beginPath()
                        let pen = false
                        for (let lon = -180; lon <= 180; lon += 10) {
                            const p = project(lat, lon, cx, cy, R)
                            if (p.z > 0) {
                                if (!pen) { ctx.moveTo(p.x, p.y); pen = true }
                                else ctx.lineTo(p.x, p.y)
                            } else {
                                pen = false
                            }
                        }
                        ctx.stroke()
                    }
                    for (let lon = 0; lon < 360; lon += 30) {
                        ctx.beginPath()
                        let pen = false
                        for (let lat = -85; lat <= 85; lat += 10) {
                            const p = project(lat, lon, cx, cy, R)
                            if (p.z > 0) {
                                if (!pen) { ctx.moveTo(p.x, p.y); pen = true }
                                else ctx.lineTo(p.x, p.y)
                            } else {
                                pen = false
                            }
                        }
                        ctx.stroke()
                    }

                    // Glowing continent coastlines + vertex city-lights
                    const conts = continents
                    for (let c = 0; c < conts.length; c++) {
                        const poly = conts[c]
                        // Subtle back-hemisphere ghost outline
                        ctx.beginPath()
                        let backPen = false
                        for (let i = 0; i < poly.length; i++) {
                            const p = project(poly[i][0], poly[i][1], cx, cy, R)
                            if (p.z <= 0) {
                                if (!backPen) { ctx.moveTo(p.x, p.y); backPen = true }
                                else ctx.lineTo(p.x, p.y)
                            } else {
                                backPen = false
                            }
                        }
                        ctx.strokeStyle = Qt.rgba(onS.r, onS.g, onS.b, 0.10)
                        ctx.lineWidth = 0.9
                        ctx.stroke()

                        // Crisp front-hemisphere glowing coastline
                        ctx.beginPath()
                        let frontPen = false
                        for (let i = 0; i < poly.length; i++) {
                            const p = project(poly[i][0], poly[i][1], cx, cy, R)
                            if (p.z > -0.04) {
                                if (!frontPen) { ctx.moveTo(p.x, p.y); frontPen = true }
                                else ctx.lineTo(p.x, p.y)
                            } else {
                                frontPen = false
                            }
                        }
                        ctx.strokeStyle = Qt.rgba(prim.r, prim.g, prim.b, 0.94)
                        ctx.lineWidth = 1.65
                        ctx.stroke()

                        // Glowing Material You tertiary city-light dots along visible coastline vertices
                        for (let i = 0; i < poly.length; i += 2) {
                            const p = project(poly[i][0], poly[i][1], cx, cy, R)
                            if (p.z > 0.12) {
                                ctx.beginPath()
                                ctx.arc(p.x, p.y, 1.7, 0, Math.PI * 2)
                                ctx.fillStyle = Qt.rgba(tert.r, tert.g, tert.b, 0.65 + p.z * 0.35)
                                ctx.fill()
                            }
                        }
                    }

                    // Crisp HUD-tinted atmospheric rim ring
                    ctx.beginPath()
                    ctx.arc(cx, cy, R, 0, Math.PI * 2)
                    ctx.strokeStyle = Qt.rgba(prim.r, prim.g, prim.b, 0.58)
                    ctx.lineWidth = 1.6
                    ctx.stroke()
                }
            }

            // Interactive drag-to-spin on the 3D Globe!
            MouseArea {
                anchors.fill: parent
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                onPressed: function(mouse) {
                    globeWin.dragging = true
                    globeWin.lastDragX = mouse.x
                    globeWin.lastDragY = mouse.y
                }
                onPositionChanged: function(mouse) {
                    if (!globeWin.dragging) return
                    const dx = mouse.x - globeWin.lastDragX
                    const dy = mouse.y - globeWin.lastDragY
                    globeWin.rotLon += dx * 0.0085
                    globeWin.rotLat = Math.max(-1.1, Math.min(1.1, globeWin.rotLat + dy * 0.0065))
                    globeWin.lastDragX = mouse.x
                    globeWin.lastDragY = mouse.y
                }
                onReleased: globeWin.dragging = false
                onCanceled: globeWin.dragging = false
            }
        }

        // =====================================================================
        // 6 Floating Material 3 Web Result Pills (3 Left, 3 Right)
        // =====================================================================
        Repeater {
            model: globeWin.pageResults

            delegate: Rectangle {
                required property var modelData
                required property int index

                readonly property bool isLeft: index < 3
                readonly property int rowIdx: index % 3
                readonly property real cx: globeContainer.x + globeContainer.width / 2
                readonly property real cy: globeContainer.y + globeContainer.height / 2
                readonly property real r: globeContainer.width / 2 - 8
                readonly property real gapX: 96
                readonly property real reveal: Math.max(0.0, Math.min(1.0, (globeWin.linesProgress - index * 0.06 - 0.18) / 0.45))

                width: 248
                height: 54
                x: isLeft ? (cx - r - gapX - width) : (cx + r + gapX)
                y: cy - 122 + rowIdx * 102
                z: 6

                radius: MusicState.shapeLg
                color: cardMa.containsMouse ? MusicState.m3SecondaryContainer : MusicState.m3SurfaceContainer
                border.width: 1
                border.color: cardMa.containsMouse ? MusicState.m3Primary : MusicState.m3OutlineVariant
                opacity: globeWin.launching ? 0.0 : reveal
                scale: (0.86 + 0.14 * reveal) * (cardMa.pressed ? 0.96 : (cardMa.containsMouse ? 1.03 : 1.0))

                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on scale { M3Anim { duration: 180 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        Layout.alignment: Qt.AlignVCenter
                        radius: 10
                        color: MusicState.m3SurfaceContainerHigh

                        Image {
                            id: favImg
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            source: modelData.favicon || ""
                            asynchronous: true
                            smooth: true
                            visible: status === Image.Ready
                        }

                        SysIcon {
                            anchors.centerIn: parent
                            visible: favImg.status !== Image.Ready
                            name: "language"
                            size: 16
                            color: MusicState.m3Primary
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: modelData.title || modelData.url || ""
                            color: cardMa.containsMouse ? MusicState.m3OnSecondaryContainer : MusicState.m3OnSurface
                            font.family: MusicState.fontUi
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.domain || modelData.url || ""
                            color: cardMa.containsMouse ? MusicState.m3OnSecondaryContainer : MusicState.m3OnSurfaceVariant
                            opacity: 0.85
                            font.family: MusicState.fontUi
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                    }
                }

                MouseArea {
                    id: cardMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: globeWin.triggerFoxLaunch(modelData, parent.x, parent.y)
                }
            }
        }

        // =====================================================================
        // Bottom Material 3 Floating Search Pill
        // =====================================================================
        Rectangle {
            id: searchBar
            width: 380
            height: 46
            radius: 23
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: globeContainer.bottom
                topMargin: 36
            }
            color: MusicState.m3SurfaceContainerHigh
            border.width: 1
            border.color: searchField.activeFocus ? MusicState.m3Outline : MusicState.m3OutlineVariant
            opacity: globeWin.launching ? 0.0 : globeWin.introProgress
            scale: globeWin.launching ? 0.88 : (0.92 + 0.08 * globeWin.introProgress)
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on scale   { NumberAnimation { duration: 200; easing.type: Easing.InCubic } }
            z: 8

            MouseArea { anchors.fill: parent }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 10
                spacing: 10

                SysIcon {
                    name: "search"
                    size: 16
                    color: GlobeSearchState.loading ? MusicState.m3Primary : MusicState.m3OnSurfaceVariant
                    Layout.alignment: Qt.AlignVCenter
                }

                TextInput {
                    id: searchField
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: GlobeSearchState.query
                    color: MusicState.m3OnSurface
                    selectionColor: MusicState.m3PrimaryContainer
                    selectedTextColor: MusicState.m3OnPrimaryContainer
                    font.family: MusicState.fontUi
                    font.pixelSize: 13
                    clip: true

                    Keys.onEscapePressed: GlobeSearchState.close()
                    Keys.onReturnPressed: GlobeSearchState.search(text)
                    Keys.onEnterPressed: GlobeSearchState.search(text)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: searchField.text.length === 0
                        text: "Поиск в интернете (Enter)..."
                        color: MusicState.m3OnSurfaceVariant
                        opacity: 0.68
                        font.family: MusicState.fontUi
                        font.pixelSize: 13
                    }
                }

                // Loading / Submit / Clear Pill Button
                Rectangle {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignVCenter
                    radius: 15
                    color: goMa.containsMouse ? MusicState.m3PrimaryContainer : MusicState.m3SurfaceContainerHighest
                    Behavior on color { ColorAnimation { duration: 140 } }

                    SysIcon {
                        anchors.centerIn: parent
                        name: GlobeSearchState.loading ? "refresh" : (searchField.text.length > 0 ? "chevron_right" : "language")
                        size: 14
                        color: goMa.containsMouse ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface
                        rotation: GlobeSearchState.loading ? 360 : 0
                        NumberAnimation on rotation {
                            running: GlobeSearchState.loading
                            from: 0; to: 360; duration: 900; loops: Animation.Infinite
                        }
                    }

                    MouseArea {
                        id: goMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (searchField.text.trim() !== "") GlobeSearchState.search(searchField.text)
                            else searchField.forceActiveFocus()
                        }
                    }
                }
            }
        }

        // =====================================================================
        // Chosen Result Card (glides to center before getting chomped by Fox!)
        // =====================================================================
        Rectangle {
            visible: globeWin.launching && globeWin.chosenItem !== null && globeWin.chosenOpacity > 0.01
            x: globeWin.chosenX
            y: globeWin.chosenY
            width: 268
            height: 58
            radius: MusicState.shapeLg
            color: MusicState.m3SecondaryContainer
            border.width: 1.5
            border.color: MusicState.m3Primary
            scale: globeWin.chosenScale
            opacity: globeWin.chosenOpacity
            z: 14

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    Layout.alignment: Qt.AlignVCenter
                    radius: 10
                    color: MusicState.m3SurfaceContainerHigh

                    Image {
                        id: chosenFav
                        anchors.centerIn: parent
                        width: 20; height: 20
                        source: globeWin.chosenItem ? (globeWin.chosenItem.favicon || "") : ""
                        asynchronous: true; smooth: true
                        visible: status === Image.Ready
                    }
                    SysIcon {
                        anchors.centerIn: parent
                        visible: chosenFav.status !== Image.Ready
                        name: "language"; size: 16; color: MusicState.m3Primary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: globeWin.chosenItem ? (globeWin.chosenItem.title || "") : ""
                        color: MusicState.m3OnSecondaryContainer
                        font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.Bold
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: globeWin.chosenItem ? (globeWin.chosenItem.domain || "") : ""
                        color: MusicState.m3OnSecondaryContainer; opacity: 0.85
                        font.family: MusicState.fontUi; font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // =====================================================================
        // Animated Fiery Firefox Fox Chomp & Spark Burst Canvas!
        // =====================================================================
        Canvas {
            id: foxCanvas
            anchors.fill: parent
            visible: globeWin.launching && (globeWin.foxOpacity > 0.01 || globeWin.burstProgress > 0.01)
            opacity: globeWin.foxOpacity
            z: 16

            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                if (!globeWin.launching) return

                const cx = width / 2
                const cy = height / 2

                // Fiery orange/purple Firefox spark burst on bite
                if (globeWin.burstProgress > 0.01) {
                    const bp = globeWin.burstProgress
                    const sparks = 16
                    for (let i = 0; i < sparks; i++) {
                        const ang = (i / sparks) * Math.PI * 2 + bp * 0.6
                        const dist = 24 + bp * 155
                        const sx = cx + Math.cos(ang) * dist
                        const sy = cy + Math.sin(ang) * dist
                        const sr = Math.max(1.0, (1.0 - bp) * (i % 2 === 0 ? 7.0 : 4.5))
                        ctx.beginPath()
                        ctx.arc(sx, sy, sr, 0, Math.PI * 2)
                        ctx.fillStyle = i % 3 === 0
                            ? Qt.rgba(1.0, 0.72, 0.12, 1.0 - bp)
                            : (i % 3 === 1 ? Qt.rgba(1.0, 0.34, 0.12, 1.0 - bp) : Qt.rgba(0.62, 0.35, 1.0, 1.0 - bp))
                        ctx.fill()
                    }
                }

                // Fox slides from left side (cx - 210) straight onto center (cx) to chomp the card!
                const fx = (cx - 210) + globeWin.foxProgress * 210
                const fy = cy
                const sc = Math.max(0.05, globeWin.foxScale)

                ctx.save()
                ctx.translate(fx, fy)
                ctx.scale(sc, sc)

                // Glowing Firefox aura behind the fox
                const aura = ctx.createRadialGradient(0, 0, 12, 0, 0, 88)
                aura.addColorStop(0.0, "rgba(255, 140, 20, 0.42)")
                aura.addColorStop(0.6, "rgba(255, 62, 48, 0.18)")
                aura.addColorStop(1.0, "rgba(144, 89, 255, 0.0)")
                ctx.fillStyle = aura
                ctx.beginPath()
                ctx.arc(0, 0, 88, 0, Math.PI * 2)
                ctx.fill()

                // Fiery sweeping tail (behind head, curling up on left)
                const tailGrad = ctx.createLinearGradient(-76, -34, 10, 42)
                tailGrad.addColorStop(0.0, "#FFD43B")
                tailGrad.addColorStop(0.45, "#FF7A00")
                tailGrad.addColorStop(1.0, "#E02850")
                ctx.fillStyle = tailGrad
                ctx.beginPath()
                ctx.moveTo(-22, 12)
                ctx.bezierCurveTo(-86, 42, -92, -32, -46, -48)
                ctx.bezierCurveTo(-56, -18, -42, 4, -14, -4)
                ctx.closePath()
                ctx.fill()

                // Tail bright tip
                ctx.fillStyle = "#FFF1B8"
                ctx.beginPath()
                ctx.moveTo(-58, -40)
                ctx.quadraticCurveTo(-48, -56, -36, -44)
                ctx.quadraticCurveTo(-48, -32, -58, -40)
                ctx.fill()

                // Upper Head + Pointed Fox Ears (tilts up when opening mouth!)
                const jaw = globeWin.foxJaw
                ctx.save()
                ctx.rotate(-jaw * 0.34)

                // Back Ear
                ctx.fillStyle = "#D93829"
                ctx.beginPath()
                ctx.moveTo(-18, -24)
                ctx.lineTo(-4, -64)
                ctx.lineTo(14, -26)
                ctx.closePath()
                ctx.fill()

                // Front Ear
                ctx.fillStyle = "#FF6B1A"
                ctx.beginPath()
                ctx.moveTo(-36, -16)
                ctx.lineTo(-28, -62)
                ctx.lineTo(-4, -26)
                ctx.closePath()
                ctx.fill()

                // Inner Ear highlight
                ctx.fillStyle = "#FFE1A8"
                ctx.beginPath()
                ctx.moveTo(-30, -22)
                ctx.lineTo(-26, -49)
                ctx.lineTo(-12, -26)
                ctx.closePath()
                ctx.fill()

                // Upper Cranium & Snout
                const headGrad = ctx.createLinearGradient(-44, -36, 56, 12)
                headGrad.addColorStop(0.0, "#FF4E2A")
                headGrad.addColorStop(0.55, "#FF8A1E")
                headGrad.addColorStop(1.0, "#FFB830")
                ctx.fillStyle = headGrad
                ctx.beginPath()
                ctx.moveTo(-42, 6)
                ctx.quadraticCurveTo(-40, -34, 4, -32)
                ctx.lineTo(58, -4)
                ctx.lineTo(44, 8)
                ctx.lineTo(-26, 10)
                ctx.closePath()
                ctx.fill()

                // Sharp upper fangs when mouth is open
                if (jaw > 0.15) {
                    ctx.fillStyle = "#FFFFFF"
                    ctx.beginPath()
                    ctx.moveTo(30, 7); ctx.lineTo(35, 19); ctx.lineTo(40, 7)
                    ctx.moveTo(14, 8); ctx.lineTo(18, 17); ctx.lineTo(22, 8)
                    ctx.fill()
                }

                // Cute dark nose tip
                ctx.fillStyle = "#1B1226"
                ctx.beginPath()
                ctx.arc(56, -4, 5.5, 0, Math.PI * 2)
                ctx.fill()

                // Expressive fierce/happy fox eye
                ctx.fillStyle = "#1B1226"
                ctx.beginPath()
                ctx.ellipse(10, -14, 5.5, jaw > 0.3 ? 6.5 : 4.2, -0.15, 0, Math.PI * 2)
                ctx.fill()
                ctx.fillStyle = "#FFFFFF"
                ctx.beginPath()
                ctx.arc(12, -16, 2.0, 0, Math.PI * 2)
                ctx.fill()

                ctx.restore()

                // Lower Jaw + White Cheek (drops down on chomp!)
                ctx.save()
                ctx.rotate(jaw * 0.44)

                ctx.fillStyle = "#FFF4E6"
                ctx.beginPath()
                ctx.moveTo(-36, 4)
                ctx.lineTo(46, 6)
                ctx.quadraticCurveTo(22, 34, -18, 28)
                ctx.quadraticCurveTo(-36, 22, -36, 4)
                ctx.closePath()
                ctx.fill()

                // Lower fang
                if (jaw > 0.15) {
                    ctx.fillStyle = "#FFFFFF"
                    ctx.beginPath()
                    ctx.moveTo(26, 7); ctx.lineTo(31, -3); ctx.lineTo(36, 7)
                    ctx.fill()
                }

                ctx.restore()
                ctx.restore()
            }
        }
    }
}
