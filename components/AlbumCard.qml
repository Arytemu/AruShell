import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import "../services"

/**
 * Material You (M3 Expressive) Album Card:
 * - Tonal surface container dynamically tinted by album art / wallpaper
 * - Genre-adaptive typography (Rap / Rock / Electronic / Soul / Pop)
 * - Built-in Prev / Play-Pause / Next controls right on the desktop card
 * - Tonal M3 "Other lyrics" pill button underneath
 */
Column {
    id: root
    spacing: 12
    width: 286

    Item {
        id: cardContainer
        width: parent.width
        height: 392
        scale: cardHover.containsMouse ? 1.015 : 1.0
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        // Soft M3 Elevation Shadow
        Rectangle {
            id: cardShadow
            anchors.fill: parent
            radius: 28
            color: "#000000"
            visible: false
        }

        MultiEffect {
            anchors.fill: cardShadow
            source: cardShadow
            shadowEnabled: true
            shadowColor: Qt.rgba(0.0, 0.0, 0.0, 0.50)
            shadowBlur: 0.90
            shadowVerticalOffset: 14
            shadowHorizontalOffset: 0
            autoPaddingEnabled: true
        }

        // Material 3 Tonal Card Surface
        Rectangle {
            anchors.fill: parent
            radius: 28
            color: MusicState.m3SurfaceContainer

            MouseArea {
                id: cardHover
                anchors.fill: parent
                hoverEnabled: true
            }

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 11

                // Rounded Album Art (click toggles play/pause)
                Item {
                    width: parent.width
                    height: parent.width

                    Rectangle {
                        id: artMask
                        anchors.fill: parent
                        radius: 20
                        color: "#FFFFFF"
                        visible: false
                        layer.enabled: true
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 20
                        color: MusicState.m3SurfaceContainerHigh
                    }

                    Image {
                        id: coverImg
                    sourceSize: Qt.size(512, 512)
                        anchors.fill: parent
                        source: MusicState.artUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: coverImg
                        visible: coverImg.status === Image.Ready
                        maskEnabled: true
                        maskSource: artMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                    }

                    Image {
                        anchors.centerIn: parent
                        visible: coverImg.status !== Image.Ready
                        source: MusicState.currentPlatformObj.icon
                        width: 64
                        height: 64
                        sourceSize: Qt.size(128, 128)
                        smooth: true
                        opacity: 0.9
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MusicState.togglePlay()
                    }

                    // Minimize-to-Dynamic-Island Button (top-right corner of cover)
                    Rectangle {
                        id: minIslandBtn
                        anchors {
                            top: parent.top
                            right: parent.right
                            topMargin: 10
                            rightMargin: 10
                        }
                        width: 30
                        height: 30
                        radius: 15
                        z: 6
                        color: minIslandMa.containsMouse
                            ? MusicState.m3PrimaryContainer
                            : Qt.rgba(MusicState.m3SurfaceContainer.r, MusicState.m3SurfaceContainer.g, MusicState.m3SurfaceContainer.b, 0.80)
                        border.width: 1
                        border.color: minIslandMa.containsMouse ? MusicState.m3Primary : MusicState.m3OutlineVariant
                        scale: minIslandMa.pressed ? 0.90 : (minIslandMa.containsMouse ? 1.06 : 1.0)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on scale { M3Anim { duration: 180 } }

                        SysIcon {
                            anchors.centerIn: parent
                            name: "chevron_left"
                            size: 14
                            rotation: 90
                            color: minIslandMa.containsMouse ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface
                        }

                        MouseArea {
                            id: minIslandMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: MusicState.stageMinimizedToIsland = true
                        }
                    }
                }

                // Track Title & Artist (Genre-adaptive typography with smooth morph!)
                Column {
                    width: parent.width
                    spacing: 2
                    opacity: MusicState.moodFontOpacity
                    scale: MusicState.moodFontScale

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: MusicState.hasTrack ? MusicState.trackTitle : "Not Playing"
                        color: MusicState.m3OnSurface
                        font.family: MusicState.trackMoodFont
                        font.italic: MusicState.trackMoodItalic
                        font.letterSpacing: MusicState.trackMoodSpacing
                        font.pixelSize: MusicState.trackGenre === "rap" ? 20 : 15
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        visible: MusicState.statusBannerText === ""
                        text: MusicState.hasTrack
                            ? (MusicState.trackArtist + (MusicState.trackAlbum ? " · " + MusicState.trackAlbum : ""))
                            : ("Ready on " + MusicState.currentPlatformObj.name)
                        color: MusicState.m3OnSurfaceVariant
                        font.family: MusicState.trackMoodFont
                        font.italic: MusicState.trackMoodItalic
                        font.pixelSize: MusicState.trackGenre === "rap" ? 14 : 12
                        elide: Text.ElideRight
                    }

                    // M3 Tonal Status Pill when launching a track
                    Rectangle {
                        visible: MusicState.statusBannerText !== ""
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 24
                        width: statusRow.implicitWidth + 18
                        radius: 12
                        color: MusicState.m3PrimaryContainer

                        RowLayout {
                            id: statusRow
                            anchors.centerIn: parent
                            spacing: 6

                            Image {
                                visible: MusicState.statusBannerIcon !== ""
                                source: MusicState.statusBannerIcon
                                Layout.preferredWidth: 14
                                Layout.preferredHeight: 14
                                Layout.alignment: Qt.AlignVCenter
                                sourceSize: Qt.size(28, 28)
                                smooth: true
                            }

                            Text {
                                text: MusicState.statusBannerText
                                color: MusicState.m3OnPrimaryContainer
                                font.family: MusicState.fontUi
                                font.pixelSize: 11
                                font.weight: Font.SemiBold
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                    }
                }

                // Expressive Prev / Play-Pause / Next Controls Row
                RowLayout {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 14

                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: prevBtnMa.containsMouse ? 12 : 18
                        color: prevBtnMa.containsMouse ? MusicState.m3PrimaryContainer : MusicState.m3SurfaceContainerHigh
                        Behavior on radius { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        Behavior on color  { ColorAnimation  { duration: 140 } }

                        SysIcon {
                            anchors.centerIn: parent
                            name: "skip_prev"
                            size: 17
                            color: prevBtnMa.containsMouse ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface
                        }

                        MouseArea {
                            id: prevBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: MusicState.prevTrack()
                        }
                    }

                    Item {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44

                        M3Shape {
                            anchors.fill: parent
                            shape: "cookie12"
                            fillColor: MusicState.m3Primary
                            morphFactor: MusicState.isPlaying ? 1.0 : 0.0
                            spin: MusicState.isPlaying
                            spinDuration: 14000
                        }

                        SysIcon {
                            anchors.centerIn: parent
                            name: MusicState.isPlaying ? "pause" : "play"
                            size: 19
                            color: MusicState.m3OnPrimary
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: MusicState.togglePlay()
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: nextBtnMa.containsMouse ? 12 : 18
                        color: nextBtnMa.containsMouse ? MusicState.m3PrimaryContainer : MusicState.m3SurfaceContainerHigh
                        Behavior on radius { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        Behavior on color  { ColorAnimation  { duration: 140 } }

                        SysIcon {
                            anchors.centerIn: parent
                            name: "skip_next"
                            size: 17
                            color: nextBtnMa.containsMouse ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface
                        }

                        MouseArea {
                            id: nextBtnMa
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

    // Material 3 Tonal Button: "Other lyrics"
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: MusicState.hasTrack
        height: 36
        width: otherLyricsRow.implicitWidth + 32
        radius: 18
        color: otherMouse.containsMouse ? MusicState.m3PrimaryContainer : MusicState.m3SurfaceContainerHigh

        Behavior on color { ColorAnimation { duration: 150 } }

        RowLayout {
            id: otherLyricsRow
            anchors.centerIn: parent
            spacing: 8

            IconImage {
                Layout.preferredWidth: 14
                Layout.preferredHeight: 14
                Layout.alignment: Qt.AlignVCenter
                implicitSize: 14
                source: Quickshell.iconPath("system-search-symbolic", true) || Quickshell.iconPath("edit-find-symbolic", true)
            }

            Text {
                text: MusicState.lyricsTotalVariants > 1
                    ? ("Other lyrics (" + (MusicState.lyricsAltIndex % MusicState.lyricsTotalVariants + 1) + "/" + MusicState.lyricsTotalVariants + ")")
                    : "Other lyrics"
                color: otherMouse.containsMouse ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface
                font.family: MusicState.fontUi
                font.pixelSize: 12
                font.weight: Font.SemiBold
                verticalAlignment: Text.AlignVCenter
                Layout.alignment: Qt.AlignVCenter
            }
        }

        MouseArea {
            id: otherMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: MusicState.nextLyricsVariant()
        }
    }
}
