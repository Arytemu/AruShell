import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../services"

/**
 * Compact Auto-Hiding Material You App + Media Dock:
 * [ Pin ] [ App Icons in original colors + running dot ] | [ Cover + Title/Artist ] [ Prev ] [ Play/Pause ] [ Next ]
 * Uses standard system symbolic icons (no custom icon SVGs).
 */
Item {
    id: root
    implicitWidth: dockRow.implicitWidth + 24
    implicitHeight: 68
    width: implicitWidth
    height: implicitHeight

    function sysIcon(names) {
        for (let i = 0; i < names.length; i++) {
            const p = Quickshell.iconPath(names[i], true)
            if (p && p !== "") return p
        }
        return ""
    }

    // Combine pinned dock_apps + currently running Wayland toplevels (skip empty/quickshell ghost entries)
    readonly property var dockModel: {
        const result = []
        const seen = {}
        const runningList = ToplevelManager.toplevels.values || []

        function findRunning(appId) {
            const needle = (appId || "").toLowerCase()
            for (let i = 0; i < runningList.length; i++) {
                const t = runningList[i]
                const tid = (t.appId || "").toLowerCase()
                if (!tid) continue
                if (tid === needle || tid.indexOf(needle) !== -1 || needle.indexOf(tid) !== -1) {
                    return t
                }
            }
            return null
        }

        const pinned = MusicState.dockApps || []
        for (let i = 0; i < pinned.length; i++) {
            const id = pinned[i]
            const key = id.toLowerCase()
            seen[key] = true
            const entry = DesktopEntries.heuristicLookup(id)
            const iconName = entry ? entry.icon : id
            const iconUrl = Quickshell.iconPath(iconName || "", true)
            const tl = findRunning(id)
            result.push({
                appId: id,
                entry: entry,
                iconUrl: iconUrl || Quickshell.iconPath("application-x-executable", true),
                toplevel: tl,
                running: tl !== null
            })
        }

        for (let i = 0; i < runningList.length; i++) {
            const tl = runningList[i]
            const tid = (tl.appId || "").trim()
            if (!tid) continue
            const key = tid.toLowerCase()
            if (key.indexOf("quickshell") !== -1 || key.indexOf("ambient-music") !== -1) continue

            let already = false
            for (const k in seen) {
                if (k === key || k.indexOf(key) !== -1 || key.indexOf(k) !== -1) {
                    already = true
                    break
                }
            }
            if (already) continue

            const entry = DesktopEntries.heuristicLookup(tid)
            const iconName = entry ? entry.icon : tid
            const iconUrl = Quickshell.iconPath(iconName || "", true)
            // Skip invisible/utility windows with no desktop entry and no system icon
            if (!entry && (!iconUrl || iconUrl === "")) continue

            seen[key] = true
            result.push({
                appId: tid,
                entry: entry,
                iconUrl: iconUrl || Quickshell.iconPath("application-x-executable", true),
                toplevel: tl,
                running: true
            })
        }
        return result
    }

    // Soft M3 Elevation Shadow
    Rectangle {
        id: dockShadow
        anchors.fill: parent
        radius: 26
        color: "#000000"
        visible: false
    }

    MultiEffect {
        anchors.fill: dockShadow
        source: dockShadow
        shadowEnabled: true
        shadowColor: Qt.rgba(0.0, 0.0, 0.0, 0.52)
        shadowBlur: 0.85
        shadowVerticalOffset: 10
        autoPaddingEnabled: true
    }

    // Material You Tonal Dock Pill
    Rectangle {
        anchors.fill: parent
        radius: 26
        color: MusicState.m3SurfaceContainer

        RowLayout {
            id: dockRow
            anchors.centerIn: parent
            spacing: 8

            // 1. Left Pin Button (standard system pin icon)
            Rectangle {
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                Layout.alignment: Qt.AlignVCenter
                radius: 21
                color: MusicState.dockPinned
                    ? MusicState.m3PrimaryContainer
                    : (pinMa.containsMouse ? MusicState.m3SurfaceContainerHighest : MusicState.m3SurfaceContainerHigh)
                Behavior on color { ColorAnimation { duration: 150 } }

                IconImage {
                    id: pinIcon
                    anchors.centerIn: parent
                    implicitSize: 18
                    source: root.sysIcon(["window-pin-symbolic", "view-pin-symbolic", "pin-symbolic", "window-pin"])
                    rotation: MusicState.dockPinned ? 0 : 40
                    Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    visible: false
                }

                MultiEffect {
                    anchors.fill: pinIcon
                    source: pinIcon
                    colorization: 1.0
                    colorizationColor: MusicState.dockPinned ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface
                    opacity: MusicState.dockPinned ? 1.0 : 0.78
                }

                MouseArea {
                    id: pinMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: MusicState.dockPinned = !MusicState.dockPinned
                }
            }

            // 2. App Icons (strictly ORIGINAL colors — NO colorization!)
            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 6

                Repeater {
                    model: root.dockModel

                    delegate: Item {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 52
                        Layout.alignment: Qt.AlignVCenter

                        Item {
                            width: 38
                            height: 38
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 4
                            scale: appMa.pressed ? 0.90 : (appMa.containsMouse ? 1.12 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

                            IconImage {
                                anchors.fill: parent
                                implicitSize: 38
                                mipmap: true
                                asynchronous: true
                                source: modelData.iconUrl
                            }
                        }

                        Rectangle {
                            visible: modelData.running
                            width: modelData.toplevel && modelData.toplevel.activated ? 12 : 5
                            height: 4
                            radius: 2
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 2
                            color: modelData.toplevel && modelData.toplevel.activated
                                ? MusicState.m3Primary
                                : MusicState.m3OnSurfaceVariant
                            Behavior on width { NumberAnimation { duration: 160 } }
                        }

                        MouseArea {
                            id: appMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.toplevel) {
                                    modelData.toplevel.activate()
                                } else if (modelData.entry) {
                                    modelData.entry.execute()
                                } else {
                                    Quickshell.execDetached([modelData.appId])
                                }
                            }
                        }
                    }
                }
            }

            // 3. Subtle Vertical Divider
            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 34
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 2
                Layout.rightMargin: 2
                color: MusicState.m3OutlineVariant
            }

            // 4. Compact Media Section: [ Cover + Title/Artist ] [ Prev ] [ Play/Pause ] [ Next ]
            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 8

                // Cover art (click opens Platform Menu)
                Rectangle {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    Layout.alignment: Qt.AlignVCenter
                    radius: 12
                    color: MusicState.m3SurfaceContainerHigh
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: MusicState.artUrl
                    sourceSize: Qt.size(96, 96)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }

                    IconImage {
                        anchors.centerIn: parent
                        visible: !MusicState.hasTrack || MusicState.artUrl === ""
                        implicitSize: 22
                        source: root.sysIcon(["audio-x-generic-symbolic", "multimedia-player-symbolic"])
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MusicState.raiseActivePlayer()
                    }
                }

                // Track Title & Artist (click opens Music Search)
                Item {
                    Layout.preferredWidth: 136
                    Layout.preferredHeight: 40
                    Layout.alignment: Qt.AlignVCenter

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: MusicState.hasTrack ? MusicState.trackTitle : "Not Playing"
                            color: MusicState.m3OnSurface
                            font.family: MusicState.fontUi
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: MusicState.hasTrack ? MusicState.trackArtist : MusicState.currentPlatformObj.name
                            color: MusicState.m3OnSurfaceVariant
                            font.family: MusicState.fontUi
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            MusicState.platformMenuOpen = false
                            MusicState.searchOpen = !MusicState.searchOpen
                        }
                    }
                }

                // Previous Track Button (default system icon)
                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    Layout.alignment: Qt.AlignVCenter
                    radius: 18
                    color: prevMa.containsMouse ? MusicState.m3SurfaceContainerHighest : MusicState.m3SurfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 140 } }

                    IconImage {
                        id: prevIcon
                        anchors.centerIn: parent
                        implicitSize: 16
                        source: root.sysIcon(["media-skip-backward-symbolic", "go-previous-symbolic", "media-skip-backward"])
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: prevIcon
                        source: prevIcon
                        colorization: 1.0
                        colorizationColor: MusicState.m3OnSurface
                    }

                    MouseArea {
                        id: prevMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MusicState.prevTrack()
                    }
                }

                // Play / Pause Button (default system icon)
                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    Layout.alignment: Qt.AlignVCenter
                    radius: MusicState.isPlaying ? 14 : 20
                    color: playMa.containsMouse ? MusicState.m3Primary : MusicState.m3SurfaceContainerHigh
                    Behavior on color  { ColorAnimation { duration: 150 } }
                    Behavior on radius { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

                    IconImage {
                        id: playIcon
                        anchors.centerIn: parent
                        implicitSize: 18
                        source: MusicState.isPlaying
                            ? root.sysIcon(["media-playback-pause-symbolic", "media-playback-pause"])
                            : root.sysIcon(["media-playback-start-symbolic", "media-playback-start"])
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: playIcon
                        source: playIcon
                        colorization: 1.0
                        colorizationColor: playMa.containsMouse ? MusicState.m3OnPrimary : MusicState.m3OnSurface
                    }

                    MouseArea {
                        id: playMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MusicState.togglePlay()
                    }
                }

                // Next Track Button (default system icon)
                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    Layout.alignment: Qt.AlignVCenter
                    radius: 18
                    color: nextMa.containsMouse ? MusicState.m3SurfaceContainerHighest : MusicState.m3SurfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 140 } }

                    IconImage {
                        id: nextIcon
                        anchors.centerIn: parent
                        implicitSize: 16
                        source: root.sysIcon(["media-skip-forward-symbolic", "go-next-symbolic", "media-skip-forward"])
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: nextIcon
                        source: nextIcon
                        colorization: 1.0
                        colorizationColor: MusicState.m3OnSurface
                    }

                    MouseArea {
                        id: nextMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MusicState.nextTrack()
                    }
                }
            }
        }
    }
}
