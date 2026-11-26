import QtQuick
import QtQuick.Effects
import Quickshell.Hyprland
import "../services"

/**
 * Material You Pac-Man Workspace Switcher for Hyprland:
 * - Displays workspaces 1..max(5, highest active/occupied) as edible pellets
 * - Workspaces with an urgent window (e.g. browser opening a link on another workspace)
 *   glow & pulse bright red until Pac-Man glides over and eats them!
 * - Pac-Man smoothly glides to the newly focused workspace, turns in the direction of travel,
 *   and chomps ("nyam-nyam") through the workspace dots along the way!
 */
Item {
    id: root

    readonly property int slotWidth: 26
    readonly property int sidePadding: 14
    readonly property int activeWsId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1

    // Tracks workspace IDs that received a Hyprland `urgent` event while unfocused
    property var urgentWsIds: ({})

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

    function isUrgent(wsId) {
        if (wsId === activeWsId) return false
        if (urgentWsIds && urgentWsIds[String(wsId)] === true) return true
        const list = Hyprland.workspaces.values || []
        for (let i = 0; i < list.length; i++) {
            const ws = list[i]
            if (ws.id !== wsId) continue
            if (ws.urgent === true) return true
            if (ws.toplevels && ws.toplevels.values) {
                const tls = ws.toplevels.values
                for (let j = 0; j < tls.length; j++) {
                    if (tls[j] && tls[j].urgent === true) return true
                }
            }
        }
        return false
    }

    function _markUrgentWs(wsId) {
        if (!wsId || wsId <= 0 || wsId === activeWsId) return
        const next = Object.assign({}, urgentWsIds)
        next[String(wsId)] = true
        urgentWsIds = next
    }

    function _clearUrgentWs(wsId) {
        const k = String(wsId)
        if (!urgentWsIds || !urgentWsIds[k]) return
        const next = Object.assign({}, urgentWsIds)
        delete next[k]
        urgentWsIds = next
    }

    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (!ev || ev.name !== "urgent") return
            const rawAddr = String(ev.data || "").trim().toLowerCase().replace(/^0x/, "")
            if (!rawAddr) return
            // Find which workspace owns this urgent window address
            const list = Hyprland.workspaces.values || []
            for (let i = 0; i < list.length; i++) {
                const ws = list[i]
                if (!ws || !ws.toplevels || !ws.toplevels.values) continue
                const tls = ws.toplevels.values
                for (let j = 0; j < tls.length; j++) {
                    const tl = tls[j]
                    if (!tl) continue
                    const addr = String(tl.address || "").trim().toLowerCase().replace(/^0x/, "")
                    if (addr === rawAddr) {
                        root._markUrgentWs(ws.id)
                        return
                    }
                }
            }
        }
    }

    property int _prevWsId: 1
    property bool facingLeft: false

    onActiveWsIdChanged: {
        _clearUrgentWs(activeWsId)
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

    // Material You Pill Background (1-to-1 match with Dynamic Island & TopBar pills, no shadow darkening border!)
    Rectangle {
        anchors.fill: parent
        radius: 18
        color: MusicState.m3SurfaceContainer
        border.width: 1
        border.color: MusicState.m3OutlineVariant

        // Wheel scroll to switch workspaces

        // Workspace pellets (dots)
        Row {
            id: dotsRow
            anchors.centerIn: parent
            spacing: 0

            Repeater {
                model: root.workspaceCount

                delegate: Item {
                    required property int index
                    readonly property int wsId: index + 1
                    readonly property bool occupied: root.isOccupied(wsId)
                    readonly property bool urgent: root.isUrgent(wsId)
                    readonly property real slotCenterX: root.sidePadding + index * root.slotWidth + root.slotWidth / 2
                    // Dot is "eaten" while Pac-Man is right on top of it!
                    readonly property bool eaten: Math.abs((pacman.x + pacman.width / 2) - slotCenterX) < 11

                    width: root.slotWidth
                    height: root.height

                    // Soft pulsing red halo for urgent workspace (e.g. browser opened link)
                    Rectangle {
                        id: urgentGlow
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        radius: 9
                        color: MusicState.m3Error
                        visible: urgent && !eaten
                        opacity: 0.32
                        scale: 1.0

                        SequentialAnimation {
                            running: root.visible && urgent && !eaten
                            loops: Animation.Infinite
                            ParallelAnimation {
                                NumberAnimation { target: urgentGlow; property: "scale"; from: 0.9; to: 1.45; duration: 750; easing.type: Easing.OutCubic }
                                NumberAnimation { target: urgentGlow; property: "opacity"; from: 0.48; to: 0.06; duration: 750; easing.type: Easing.OutCubic }
                            }
                            PropertyAction { target: urgentGlow; property: "scale"; value: 0.9 }
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: urgent ? 11 : (occupied ? 10 : 6)
                        height: width
                        radius: width / 2
                        color: urgent ? MusicState.m3Error : MusicState.m3OnSurface
                        opacity: eaten ? 0.0 : (urgent ? 1.0 : (occupied ? 0.88 : (dotMa.containsMouse ? 0.55 : 0.28)))
                        scale: eaten ? 0.1 : (dotMa.containsMouse ? 1.25 : 1.0)

                        Behavior on color   { ColorAnimation  { duration: 180 } }
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

                ctx.fillStyle = "rgba(" + Math.round(fillCol.r * 255) + "," + Math.round(fillCol.g * 255) + "," + Math.round(fillCol.b * 255) + "," + fillCol.a.toFixed(3) + ")"
                ctx.beginPath()
                ctx.moveTo(cx, cy)
                ctx.arc(cx, cy, r, dir + rad, dir + 2 * Math.PI - rad, false)
                ctx.closePath()
                ctx.fill()
            }
        }
    }
}
