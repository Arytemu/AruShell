import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import "../services"

/**
 * Material You (M3 Expressive) Album Card:
 * - Tonal surface container dynamically tinted by album art
 * - Soft M3 elevation shadow, zero harsh white borders
 * - Tonal M3 "Other lyrics" pill button underneath
 */
Column {
    id: root
    spacing: 14
    width: 282

    Item {
        id: cardContainer
        width: parent.width
        height: 344
        scale: cardHover.containsMouse ? 1.02 : 1.0
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

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                // Rounded Album Art
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
                }

                // Track Title & Artist (or Material 3 Status Pill)
                Column {
                    width: parent.width
                    spacing: 3

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: MusicState.hasTrack ? MusicState.trackTitle : "Not Playing"
                        color: MusicState.m3OnSurface
                        font.family: MusicState.fontUi
                        font.pixelSize: 15
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
                        font.family: MusicState.fontUi
                        font.pixelSize: 12
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
            }

            MouseArea {
                id: cardHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: MusicState.togglePlay()
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
