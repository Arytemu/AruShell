import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../services"

/**
 * DarkShadowShell-style Material 3 Screenshot Overlay:
 * - Full-resolution frozen screen backdrop (menus & hover states preserved)
 * - Region mode: drag box, move inside, resize via 4 corners, real-px badge, circular magnifying loupe
 * - Window mode: hover Hyprland windows with outline + app name pill, click to save
 * - Screen mode: full monitor capture
 * - Floating M3 bottom toolbar + full keyboard shortcuts (Enter, Ctrl+C, E, Esc, 1/2/3 or R/W/S)
 */
PanelWindow {
    id: shotWin

    screen: {
        const list = Quickshell.screens
        for (let i = 0; i < list.length; i++) {
            if (list[i].name === ScreenshotState.targetMonitor) return list[i]
        }
        return list.length > 0 ? list[0] : null
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "arushell-screenshot"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // Selection state (logical coordinates on this screen)
    property bool hasSelection: false
    property real selX: 0
    property real selY: 0
    property real selW: 0
    property real selH: 0

    // Drag / interaction state
    property string dragMode: "" // "draw" | "move" | "tl" | "tr" | "bl" | "br"
    property real anchorX: 0
    property real anchorY: 0
    property real origX: 0
    property real origY: 0
    property real origW: 0
    property real origH: 0

    // Pointer position for loupe & window hover
    property real pointerX: width / 2
    property real pointerY: height / 2
    property var hoveredWin: null

    readonly property bool showLoupe: ScreenshotState.mode === "region" && dragMode !== "" && dragMode !== "move"

    // Active bright cutout rectangle (either region selection or hovered window)
    readonly property bool hasCutout: (ScreenshotState.mode === "region" && hasSelection && selW > 2 && selH > 2)
                                   || (ScreenshotState.mode === "window" && hoveredWin !== null)
    readonly property real cutX: ScreenshotState.mode === "window" && hoveredWin ? Math.max(0, hoveredWin.x) : selX
    readonly property real cutY: ScreenshotState.mode === "window" && hoveredWin ? Math.max(0, hoveredWin.y) : selY
    readonly property real cutW: ScreenshotState.mode === "window" && hoveredWin ? Math.min(width - cutX, hoveredWin.w) : selW
    readonly property real cutH: ScreenshotState.mode === "window" && hoveredWin ? Math.min(height - cutY, hoveredWin.h) : selH

    function updateHoveredWindow(mx, my) {
        if (ScreenshotState.mode !== "window") {
            hoveredWin = null
            return
        }
        const wins = ScreenshotState.windows || []
        for (let i = 0; i < wins.length; i++) {
            const w = wins[i]
            if (mx >= w.x && mx <= w.x + w.w && my >= w.y && my <= w.y + w.h) {
                hoveredWin = w
                return
            }
        }
        hoveredWin = null
    }

    function triggerAction(action) {
        if (ScreenshotState.mode === "screen") {
            ScreenshotState.commit(action, 0, 0, 0, 0)
        } else if (ScreenshotState.mode === "window") {
            if (hoveredWin) {
                ScreenshotState.commit(action, hoveredWin.x, hoveredWin.y, hoveredWin.w, hoveredWin.h)
            } else {
                ScreenshotState.commit(action, 0, 0, 0, 0)
            }
        } else {
            if (hasSelection && selW >= 4 && selH >= 4) {
                ScreenshotState.commit(action, selX, selY, selW, selH)
            } else {
                ScreenshotState.commit(action, 0, 0, 0, 0)
            }
        }
    }

    Item {
        id: rootItem
        anchors.fill: parent
        focus: true

        Component.onCompleted: forceActiveFocus()

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                ScreenshotState.cancel()
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                shotWin.triggerAction("save")
                event.accepted = true
            } else if (event.key === Qt.Key_C && (event.modifiers & Qt.ControlModifier)) {
                shotWin.triggerAction("copy")
                event.accepted = true
            } else if (event.key === Qt.Key_E) {
                shotWin.triggerAction("edit")
                event.accepted = true
            } else if (event.key === Qt.Key_1 || event.key === Qt.Key_R) {
                ScreenshotState.mode = "region"
                event.accepted = true
            } else if (event.key === Qt.Key_2 || event.key === Qt.Key_W) {
                ScreenshotState.mode = "window"
                shotWin.updateHoveredWindow(shotWin.pointerX, shotWin.pointerY)
                event.accepted = true
            } else if (event.key === Qt.Key_3 || event.key === Qt.Key_S) {
                ScreenshotState.mode = "screen"
                event.accepted = true
            }
        }

        // 1. Frozen Full-Resolution Screen Capture
        Image {
            id: frozenImg
            anchors.fill: parent
            source: ScreenshotState.frozenPath ? ("file://" + ScreenshotState.frozenPath) : ""
            cache: false
            smooth: false
            fillMode: Image.Stretch
        }

        // 2. Dimmed Scrim (4 rectangles around cutout, or full scrim when no cutout, clear in Screen mode)
        Rectangle {
            visible: ScreenshotState.mode !== "screen" && !shotWin.hasCutout
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.48)
        }

        // Top scrim
        Rectangle {
            visible: ScreenshotState.mode !== "screen" && shotWin.hasCutout
            x: 0; y: 0
            width: parent.width
            height: Math.max(0, shotWin.cutY)
            color: Qt.rgba(0, 0, 0, 0.48)
        }
        // Bottom scrim
        Rectangle {
            visible: ScreenshotState.mode !== "screen" && shotWin.hasCutout
            x: 0; y: shotWin.cutY + shotWin.cutH
            width: parent.width
            height: Math.max(0, parent.height - (shotWin.cutY + shotWin.cutH))
            color: Qt.rgba(0, 0, 0, 0.48)
        }
        // Left scrim
        Rectangle {
            visible: ScreenshotState.mode !== "screen" && shotWin.hasCutout
            x: 0; y: shotWin.cutY
            width: Math.max(0, shotWin.cutX)
            height: shotWin.cutH
            color: Qt.rgba(0, 0, 0, 0.48)
        }
        // Right scrim
        Rectangle {
            visible: ScreenshotState.mode !== "screen" && shotWin.hasCutout
            x: shotWin.cutX + shotWin.cutW; y: shotWin.cutY
            width: Math.max(0, parent.width - (shotWin.cutX + shotWin.cutW))
            height: shotWin.cutH
            color: Qt.rgba(0, 0, 0, 0.48)
        }

        // Full-Screen mode subtle M3 border indicator
        Rectangle {
            visible: ScreenshotState.mode === "screen"
            anchors.fill: parent
            anchors.margins: 4
            radius: 12
            color: "transparent"
            border.width: 3
            border.color: MusicState.m3Primary
        }

        // 3. Main Interactive Canvas MouseArea (Draw / Move / Window Pick / Screen Click / Right-Click Cancel)
        MouseArea {
            id: canvasMa
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: ScreenshotState.mode === "region"
                ? (shotWin.dragMode === "move" ? Qt.ClosedHandCursor : Qt.CrossCursor)
                : Qt.PointingHandCursor

            onPressed: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                    ScreenshotState.cancel()
                    return
                }
                shotWin.pointerX = mouse.x
                shotWin.pointerY = mouse.y

                if (ScreenshotState.mode === "screen") {
                    shotWin.triggerAction("save")
                    return
                }
                if (ScreenshotState.mode === "window") {
                    shotWin.updateHoveredWindow(mouse.x, mouse.y)
                    if (shotWin.hoveredWin) {
                        shotWin.triggerAction("save")
                    }
                    return
                }

                // Region mode: check if pressing inside existing selection to move it
                if (shotWin.hasSelection
                    && mouse.x >= shotWin.selX + 10 && mouse.x <= shotWin.selX + shotWin.selW - 10
                    && mouse.y >= shotWin.selY + 10 && mouse.y <= shotWin.selY + shotWin.selH - 10) {
                    shotWin.dragMode = "move"
                    shotWin.anchorX = mouse.x
                    shotWin.anchorY = mouse.y
                    shotWin.origX = shotWin.selX
                    shotWin.origY = shotWin.selY
                    return
                }

                // Start drawing new selection box
                shotWin.dragMode = "draw"
                shotWin.hasSelection = true
                shotWin.anchorX = mouse.x
                shotWin.anchorY = mouse.y
                shotWin.selX = mouse.x
                shotWin.selY = mouse.y
                shotWin.selW = 0
                shotWin.selH = 0
            }

            onPositionChanged: function(mouse) {
                shotWin.pointerX = mouse.x
                shotWin.pointerY = mouse.y

                if (ScreenshotState.mode === "window") {
                    shotWin.updateHoveredWindow(mouse.x, mouse.y)
                    return
                }

                if (shotWin.dragMode === "draw") {
                    const x1 = Math.max(0, Math.min(shotWin.width, shotWin.anchorX))
                    const y1 = Math.max(0, Math.min(shotWin.height, shotWin.anchorY))
                    const x2 = Math.max(0, Math.min(shotWin.width, mouse.x))
                    const y2 = Math.max(0, Math.min(shotWin.height, mouse.y))
                    shotWin.selX = Math.min(x1, x2)
                    shotWin.selY = Math.min(y1, y2)
                    shotWin.selW = Math.abs(x2 - x1)
                    shotWin.selH = Math.abs(y2 - y1)
                } else if (shotWin.dragMode === "move") {
                    const dx = mouse.x - shotWin.anchorX
                    const dy = mouse.y - shotWin.anchorY
                    shotWin.selX = Math.max(0, Math.min(shotWin.width - shotWin.selW, shotWin.origX + dx))
                    shotWin.selY = Math.max(0, Math.min(shotWin.height - shotWin.selH, shotWin.origY + dy))
                }
            }

            onReleased: function(mouse) {
                if (shotWin.dragMode === "draw" && (shotWin.selW < 6 || shotWin.selH < 6)) {
                    shotWin.hasSelection = false
                }
                shotWin.dragMode = ""
            }

            onDoubleClicked: function(mouse) {
                if (ScreenshotState.mode === "region" && shotWin.hasSelection
                    && mouse.x >= shotWin.selX && mouse.x <= shotWin.selX + shotWin.selW
                    && mouse.y >= shotWin.selY && mouse.y <= shotWin.selY + shotWin.selH) {
                    shotWin.triggerAction("save")
                }
            }
        }

        // 4. Selection / Window Outline Frame + Corner Resize Handles
        Rectangle {
            id: cutFrame
            visible: shotWin.hasCutout && ScreenshotState.mode !== "screen"
            x: shotWin.cutX
            y: shotWin.cutY
            width: shotWin.cutW
            height: shotWin.cutH
            color: "transparent"
            border.width: 2
            border.color: MusicState.m3Primary
            radius: ScreenshotState.mode === "window" ? 10 : 2
            z: 5

            // Floating Dimension Pill (Region) or App Name Pill (Window) above box
            Rectangle {
                anchors.bottom: parent.top
                anchors.bottomMargin: 8
                anchors.left: parent.left
                visible: parent.y > 38
                height: 28
                width: badgeTxt.implicitWidth + 20
                radius: 14
                color: MusicState.m3SurfaceContainer

                Text {
                    id: badgeTxt
                    anchors.centerIn: parent
                    text: ScreenshotState.mode === "window" && shotWin.hoveredWin
                        ? (shotWin.hoveredWin.app + (shotWin.hoveredWin.title ? " · " + shotWin.hoveredWin.title.slice(0, 32) : ""))
                        : (Math.round(shotWin.selW * ScreenshotState.monitorScale) + " × " + Math.round(shotWin.selH * ScreenshotState.monitorScale) + " px")
                    color: MusicState.m3OnSurface
                    font.family: MusicState.fontUi
                    font.pixelSize: 12
                    font.weight: Font.Bold
                }
            }

            // 4 Interactive M3 Corner Resize Handles (Region mode only)
            Repeater {
                model: ScreenshotState.mode === "region" ? ["tl", "tr", "bl", "br"] : []

                delegate: Rectangle {
                    required property string modelData
                    width: 14
                    height: 14
                    radius: 7
                    color: MusicState.m3Primary
                    border.width: 2
                    border.color: "#FFFFFF"
                    x: (modelData === "tl" || modelData === "bl") ? -7 : (cutFrame.width - 7)
                    y: (modelData === "tl" || modelData === "tr") ? -7 : (cutFrame.height - 7)
                    z: 10

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: (modelData === "tl" || modelData === "br") ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor

                        onPressed: function(mouse) {
                            const pt = mapToItem(rootItem, mouse.x, mouse.y)
                            shotWin.dragMode = modelData
                            shotWin.anchorX = pt.x
                            shotWin.anchorY = pt.y
                            shotWin.origX = shotWin.selX
                            shotWin.origY = shotWin.selY
                            shotWin.origW = shotWin.selW
                            shotWin.origH = shotWin.selH
                        }

                        onPositionChanged: function(mouse) {
                            const pt = mapToItem(rootItem, mouse.x, mouse.y)
                            shotWin.pointerX = pt.x
                            shotWin.pointerY = pt.y
                            const dx = pt.x - shotWin.anchorX
                            const dy = pt.y - shotWin.anchorY

                            let nx = shotWin.origX
                            let ny = shotWin.origY
                            let nw = shotWin.origW
                            let nh = shotWin.origH

                            if (modelData === "tl") {
                                nx = Math.min(shotWin.origX + shotWin.origW - 16, Math.max(0, shotWin.origX + dx))
                                ny = Math.min(shotWin.origY + shotWin.origH - 16, Math.max(0, shotWin.origY + dy))
                                nw = shotWin.origW - (nx - shotWin.origX)
                                nh = shotWin.origH - (ny - shotWin.origY)
                            } else if (modelData === "tr") {
                                ny = Math.min(shotWin.origY + shotWin.origH - 16, Math.max(0, shotWin.origY + dy))
                                nw = Math.max(16, Math.min(shotWin.width - shotWin.origX, shotWin.origW + dx))
                                nh = shotWin.origH - (ny - shotWin.origY)
                            } else if (modelData === "bl") {
                                nx = Math.min(shotWin.origX + shotWin.origW - 16, Math.max(0, shotWin.origX + dx))
                                nw = shotWin.origW - (nx - shotWin.origX)
                                nh = Math.max(16, Math.min(shotWin.height - shotWin.origY, shotWin.origH + dy))
                            } else if (modelData === "br") {
                                nw = Math.max(16, Math.min(shotWin.width - shotWin.origX, shotWin.origW + dx))
                                nh = Math.max(16, Math.min(shotWin.height - shotWin.origY, shotWin.origH + dy))
                            }

                            shotWin.selX = nx
                            shotWin.selY = ny
                            shotWin.selW = nw
                            shotWin.selH = nh
                        }

                        onReleased: shotWin.dragMode = ""
                    }
                }
            }
        }

        // 5. Rounded Magnifying Loupe (2.5x zoom around pointer while dragging/resizing)
        Rectangle {
            id: loupe
            visible: shotWin.showLoupe
            width: 116
            height: 116
            radius: 58
            z: 20
            color: MusicState.m3SurfaceContainer
            border.width: 2.5
            border.color: MusicState.m3Primary
            clip: true

            x: (shotWin.pointerX + 24 + width < shotWin.width) ? (shotWin.pointerX + 24) : (shotWin.pointerX - width - 24)
            y: (shotWin.pointerY - height - 24 > 12) ? (shotWin.pointerY - height - 24) : (shotWin.pointerY + 24)

            readonly property real zoom: 2.5

            Image {
                source: frozenImg.source
                cache: false
                smooth: false
                width: shotWin.width * loupe.zoom
                height: shotWin.height * loupe.zoom
                x: (loupe.width / 2) - (shotWin.pointerX * loupe.zoom)
                y: (loupe.height / 2) - (shotWin.pointerY * loupe.zoom)
            }

            // Precision crosshair
            Rectangle {
                anchors.centerIn: parent
                width: 16; height: 1.5
                color: MusicState.m3Primary
            }
            Rectangle {
                anchors.centerIn: parent
                width: 1.5; height: 16
                color: MusicState.m3Primary
            }

            // Coordinates chip at bottom of loupe
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 6
                height: 18
                width: coordTxt.implicitWidth + 10
                radius: 9
                color: Qt.rgba(0, 0, 0, 0.72)

                Text {
                    id: coordTxt
                    anchors.centerIn: parent
                    text: Math.round(shotWin.pointerX * ScreenshotState.monitorScale) + "," + Math.round(shotWin.pointerY * ScreenshotState.monitorScale)
                    color: "#FFFFFF"
                    font.family: MusicState.fontUi
                    font.pixelSize: 10
                    font.weight: Font.Bold
                }
            }
        }

        // 6. DarkShadowShell Floating Material 3 Bottom Toolbar
        Rectangle {
            id: toolbar
            anchors {
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
                bottomMargin: 28
            }
            height: 54
            width: barRow.implicitWidth + 20
            radius: 27
            color: MusicState.m3SurfaceContainer
            z: 30

            // Absorb clicks so toolbar doesn't start drawing a box behind it
            MouseArea { anchors.fill: parent }

            RowLayout {
                id: barRow
                anchors.centerIn: parent
                spacing: 8

                // Mode Segmented Switcher (Область | Окно | Экран)
                Rectangle {
                    Layout.preferredHeight: 38
                    Layout.preferredWidth: modeRow.implicitWidth + 6
                    radius: 19
                    color: MusicState.m3SurfaceContainerHigh

                    Row {
                        id: modeRow
                        anchors.centerIn: parent
                        spacing: 2

                        Repeater {
                            model: [
                                { id: "region", label: "Область", key: "1" },
                                { id: "window", label: "Окно",    key: "2" },
                                { id: "screen", label: "Экран",   key: "3" }
                            ]

                            delegate: Rectangle {
                                readonly property bool isSel: ScreenshotState.mode === modelData.id
                                height: 32
                                width: mLbl.implicitWidth + 22
                                radius: 16
                                color: isSel ? MusicState.m3PrimaryContainer : (mMa.containsMouse ? MusicState.m3SurfaceContainerHighest : "transparent")
                                Behavior on color { ColorAnimation { duration: 160 } }

                                Text {
                                    id: mLbl
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: isSel ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurfaceVariant
                                    font.family: MusicState.fontUi
                                    font.pixelSize: 12
                                    font.weight: isSel ? Font.Bold : Font.Medium
                                }

                                MouseArea {
                                    id: mMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ScreenshotState.mode = modelData.id
                                }
                            }
                        }
                    }
                }

                // Divider
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 24
                    color: MusicState.m3OutlineVariant
                }

                // Save + Copy (Primary M3 Pill)
                Rectangle {
                    Layout.preferredHeight: 38
                    Layout.preferredWidth: saveLbl.implicitWidth + 24
                    radius: 19
                    color: saveMa.containsMouse ? Qt.lighter(MusicState.m3Primary, 1.08) : MusicState.m3Primary

                    Text {
                        id: saveLbl
                        anchors.centerIn: parent
                        text: "Сохранить"
                        color: MusicState.m3OnPrimary
                        font.family: MusicState.fontUi
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        id: saveMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: shotWin.triggerAction("save")
                    }
                }

                // Copy Only (Ctrl+C)
                Rectangle {
                    Layout.preferredHeight: 38
                    Layout.preferredWidth: copyLbl.implicitWidth + 20
                    radius: 19
                    color: copyMa.containsMouse ? MusicState.m3SurfaceContainerHighest : MusicState.m3SurfaceContainerHigh

                    Text {
                        id: copyLbl
                        anchors.centerIn: parent
                        text: "Копировать"
                        color: MusicState.m3OnSurface
                        font.family: MusicState.fontUi
                        font.pixelSize: 12
                        font.weight: Font.SemiBold
                    }

                    MouseArea {
                        id: copyMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: shotWin.triggerAction("copy")
                    }
                }

                // Edit in satty/swappy (E)
                Rectangle {
                    Layout.preferredHeight: 38
                    Layout.preferredWidth: editLbl.implicitWidth + 20
                    radius: 19
                    color: editMa.containsMouse ? MusicState.m3SurfaceContainerHighest : MusicState.m3SurfaceContainerHigh

                    Text {
                        id: editLbl
                        anchors.centerIn: parent
                        text: "Редактор"
                        color: MusicState.m3OnSurface
                        font.family: MusicState.fontUi
                        font.pixelSize: 12
                        font.weight: Font.SemiBold
                    }

                    MouseArea {
                        id: editMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: shotWin.triggerAction("edit")
                    }
                }

                // Cancel (Esc)
                Rectangle {
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    radius: 19
                    color: escMa.containsMouse ? "#B3261E" : MusicState.m3SurfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 150 } }

                    SysIcon {
                        anchors.centerIn: parent
                        name: "close"
                        size: 16
                        color: MusicState.m3OnSurface
                    }

                    MouseArea {
                        id: escMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ScreenshotState.cancel()
                    }
                }
            }
        }
    }
}
