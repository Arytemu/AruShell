import QtQuick
import QtQuick.Effects
import Quickshell.Hyprland
import "../services"

/**
 * Material You Pac-Man Workspace Switcher for Hyprland (matches user's reference 1:1):
 * - Displays workspaces 1..max(5, highest active/occupied) as edible pellets
 * - Pac-Man smoothly glides to the newly focused workspace, turns in the direction of travel,
 *   and chomps ("nyam-nyam") through the workspace dots along the way!
 */
Item {
    id: root

    readonly property int slotWidth: 26
    readonly property int sidePadding: 14
    readonly property int activeWsId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1

    // Show at least 5 workspaces, dynamically expanding if user opens workspace 6, 7, ...
    readonly property int workspaceCount: {
        let maxId = 5
        if (activeWsId > maxId) maxId = activeWsId
        const list = Hyprland.workspaces.values || []
        for (let i = 0; i < list.length; i++) {
            const wid = list[i].id
            if (wid > maxId && wid < 50) maxId = wid
        }
        return maxId
    }

    function switchWorkspace(arg) {
        if (Hyprland.usingLua) {
            Hyprland.dispatch('hl.dsp.focus({ workspace = "' + String(arg) + '" })')
        } else {
            Hyprland.dispatch("workspace " + String(arg))
        }
    }

    function isOccupied(wsId) {
        const list = Hyprland.workspaces.values || []
        for (let i = 0; i < list.length; i++) {
            const ws = list[i]
            if (ws.id === wsId) {
                if (ws.toplevels && ws.toplevels.values) {
                    return ws.toplevels.values.length > 0
                }
                return true
            }
        }
        return false
    }

    property int _prevWsId: 1
    property bool facingLeft: false

    onActiveWsIdChanged: {
        if (activeWsId !== _prevWsId) {
            facingLeft = activeWsId < _prevWsId
            _prevWsId = activeWsId
            chompAnim.restart()
        }
    }

    implicitWidth: workspaceCount * slotWidth + sidePadding * 2
    implicitHeight: 36
    width: implicitWidth
    height: implicitHeight

    // Soft M3 Shadow
    Rectangle {
        id: pillShadow
        anchors.fill: parent
        radius: 18
        color: "#000000"
        visible: false
    }

    MultiEffect {
        anchors.fill: pillShadow
        source: pillShadow
        shadowEnabled: true
        shadowColor: Qt.rgba(0.0, 0.0, 0.0, 0.48)
        shadowBlur: 0.72
        shadowVerticalOffset: 4
        autoPaddingEnabled: true
    }

    // Material You Pill Background
    Rectangle {
        anchors.fill: parent
        radius: 18
        color: MusicState.m3SurfaceContainer

        // Wheel scroll to switch workspaces
        WheelHandler {
            onWheel: function(event) {
                if (event.angleDelta.y > 0) {
                    root.switchWorkspace("e-1")
                } else if (event.angleDelta.y < 0) {
                    root.switchWorkspace("e+1")
                }
            }
        }

        // Workspace pellets (dots)
        Row {
            id: dotsRow
            anchors.centerIn: parent
            spacing: 0

            Repeater {
                model: root.workspaceCount

                delegate: Item {
                    readonly property int wsId: index + 1
                    readonly property bool occupied: root.isOccupied(wsId)
                    readonly property real slotCenterX: root.sidePadding + index * root.slotWidth + root.slotWidth / 2
                    // Dot is "eaten" while Pac-Man is right on top of it!
                    readonly property bool eaten: Math.abs((pacman.x + pacman.width / 2) - slotCenterX) < 11

                    width: root.slotWidth
                    height: root.height

                    Rectangle {
                        anchors.centerIn: parent
                        width: occupied ? 10 : 6
                        height: width
                        radius: width / 2
                        color: MusicState.m3OnSurface
                        opacity: eaten ? 0.0 : (occupied ? 0.88 : (dotMa.containsMouse ? 0.55 : 0.28))
                        scale: eaten ? 0.1 : (dotMa.containsMouse ? 1.25 : 1.0)

                        Behavior on width   { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 110 } }
                        Behavior on scale   { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                    }

                    MouseArea {
                        id: dotMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.switchWorkspace(wsId)
                    }
                }
            }
        }

        // Animated Pac-Man gliding & chomping across workspaces!
        Canvas {
            id: pacman
            width: 18
            height: 18
            anchors.verticalCenter: parent.verticalCenter
            x: root.sidePadding + Math.max(0, root.activeWsId - 1) * root.slotWidth + (root.slotWidth - width) / 2
            antialiasing: true
            z: 5

            property real mouthAngle: 36.0 // degrees half-angle of open mouth
            property color fillCol: MusicState.m3OnSurface

            Behavior on x {
                NumberAnimation { duration: 280; easing.type: Easing.InOutCubic }
            }

            onMouthAngleChanged: requestPaint()
            onFillColChanged: requestPaint()
            Component.onCompleted: requestPaint()

            Connections {
                target: root
                function onFacingLeftChanged() { pacman.requestPaint() }
            }

            // Chomping ("nyam-nyam") animation while eating workspaces
            SequentialAnimation {
                id: chompAnim
                NumberAnimation { target: pacman; property: "mouthAngle"; to: 4;  duration: 70; easing.type: Easing.InOutSine }
                NumberAnimation { target: pacman; property: "mouthAngle"; to: 44; duration: 70; easing.type: Easing.InOutSine }
                NumberAnimation { target: pacman; property: "mouthAngle"; to: 4;  duration: 70; easing.type: Easing.InOutSine }
                NumberAnimation { target: pacman; property: "mouthAngle"; to: 36; duration: 90; easing.type: Easing.OutCubic }
            }

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const cx = width / 2
                const cy = height / 2
                const r = width / 2 - 0.5
                const rad = (mouthAngle * Math.PI) / 180.0
                const dir = root.facingLeft ? Math.PI : 0.0

                ctx.fillStyle = fillCol
                ctx.beginPath()
                ctx.moveTo(cx, cy)
                ctx.arc(cx, cy, r, dir + rad, dir + 2 * Math.PI - rad, false)
                ctx.closePath()
                ctx.fill()
            }
        }
    }
}
