import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import "../services"

/**
 * Material You Music Search Sheet (with integrated search bar & platform switcher pill):
 * Pops up smoothly above the dock when clicking track title or the 9-dots button.
 */
Item {
    id: root
    width: 650
    height: 404

    visible: opacity > 0.01
    opacity: MusicState.searchOpen ? 1.0 : 0.0
    scale: MusicState.searchOpen ? 1.0 : 0.95
    transformOrigin: Item.Bottom

    Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
    Behavior on scale   { NumberAnimation { duration: 210; easing.type: Easing.OutCubic } }

    Connections {
        target: MusicState
        function onSearchOpenChanged() {
            if (MusicState.searchOpen) searchInput.forceActiveFocus()
            else searchInput.focus = false
        }
    }

    Rectangle {
        id: searchShadow
        anchors.fill: parent
        radius: 28
        color: "#000000"
        visible: false
    }

    MultiEffect {
        anchors.fill: searchShadow
        source: searchShadow
        shadowEnabled: true
        shadowColor: Qt.rgba(0.0, 0.0, 0.0, 0.52)
        shadowBlur: 0.90
        shadowVerticalOffset: 12
        autoPaddingEnabled: true
    }

    Rectangle {
        anchors.fill: parent
        radius: 28
        color: MusicState.m3SurfaceContainer

        Column {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            // Integrated Material 3 Search Bar + Platform Selector Pill
            Rectangle {
                width: parent.width
                height: 44
                radius: 22
                color: MusicState.m3SurfaceContainerHigh

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 10
                    spacing: 10

                    IconImage {
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        Layout.alignment: Qt.AlignVCenter
                        implicitSize: 16
                        source: Quickshell.iconPath("system-search-symbolic", true) || Quickshell.iconPath("edit-find-symbolic", true)
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        color: MusicState.m3OnSurface
                        selectionColor: MusicState.m3Primary
                        font.family: MusicState.fontUi
                        font.pixelSize: 14
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        text: MusicState.searchQuery

                        onTextEdited: MusicState.runSearch(text)
                        Keys.onEscapePressed: MusicState.searchOpen = false
                        Keys.onReturnPressed: {
                            if (MusicState.searchTracks.length > 0) {
                                MusicState.playItem(MusicState.searchTracks[0])
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: searchInput.text.length === 0
                            text: "Поиск треков в " + MusicState.currentPlatformObj.name + "..."
                            color: MusicState.m3OnSurfaceVariant
                            font.family: MusicState.fontUi
                            font.pixelSize: 13
                        }
                    }

                    // Platform switcher chip inside search bar
                    Rectangle {
                        Layout.preferredHeight: 28
                        Layout.preferredWidth: platChipRow.implicitWidth + 16
                        Layout.alignment: Qt.AlignVCenter
                        radius: 14
                        color: MusicState.m3PrimaryContainer

                        RowLayout {
                            id: platChipRow
                            anchors.centerIn: parent
                            spacing: 6

                            Image {
                                source: MusicState.currentPlatformObj.icon
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                Layout.alignment: Qt.AlignVCenter
                                sourceSize: Qt.size(32, 32)
                                smooth: true
                            }

                            Text {
                                text: MusicState.currentPlatformObj.name
                                color: MusicState.m3OnPrimaryContainer
                                font.family: MusicState.fontUi
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                MusicState.searchOpen = false
                                MusicState.platformMenuOpen = true
                            }
                        }
                    }
                }
            }

            RowLayout {
                width: parent.width
                spacing: 10

                Text {
                    text: "Top Results"
                    color: MusicState.m3OnSurface
                    font.family: MusicState.fontUi
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                Text {
                    visible: MusicState.searchLoading
                    text: "Поиск..."
                    color: MusicState.m3OnSurfaceVariant
                    font.family: MusicState.fontUi
                    font.pixelSize: 12
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            // Top Results Horizontal Cards
            Item {
                width: parent.width
                height: 162

                ListView {
                    id: tracksRow
                    anchors.fill: parent
                    orientation: ListView.Horizontal
                    spacing: 12
                    clip: true
                    model: MusicState.searchTracks

                    delegate: Rectangle {
                        width: 124
                        height: 162
                        radius: 18
                        color: trackMouse.containsMouse ? MusicState.m3PrimaryContainer : MusicState.m3SurfaceContainerHigh

                        Behavior on color { ColorAnimation { duration: 140 } }

                        Column {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            Rectangle {
                                width: 108
                                height: 108
                                radius: 13
                                color: MusicState.m3SurfaceContainer
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: modelData.cover || ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                            }

                            Text {
                                width: parent.width
                                text: modelData.title || ""
                                color: trackMouse.containsMouse ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface
                                font.family: MusicState.fontUi
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: modelData.artist || ""
                                color: trackMouse.containsMouse ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurfaceVariant
                                font.family: MusicState.fontUi
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: trackMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: MusicState.playItem(modelData)
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: tracksRow.count === 0 && !MusicState.searchLoading
                    text: MusicState.searchQuery.trim().length < 2
                        ? "Введите название трека или исполнителя..."
                        : "Ничего не найдено"
                    color: MusicState.m3OnSurfaceVariant
                    font.family: MusicState.fontUi
                    font.pixelSize: 13
                }
            }

            // Artists Row
            Column {
                width: parent.width
                spacing: 8
                visible: MusicState.searchArtists.length > 0

                Text {
                    text: "Artists"
                    color: MusicState.m3OnSurface
                    font.family: MusicState.fontUi
                    font.pixelSize: 14
                    font.weight: Font.Bold
                }

                ListView {
                    width: parent.width
                    height: 82
                    orientation: ListView.Horizontal
                    spacing: 14
                    clip: true
                    model: MusicState.searchArtists

                    delegate: Column {
                        width: 82
                        spacing: 5

                        Rectangle {
                            width: 58
                            height: 58
                            radius: 29
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: MusicState.m3SurfaceContainerHigh
                            clip: true
                            scale: artistMouse.containsMouse ? 1.07 : 1.0
                            Behavior on scale { NumberAnimation { duration: 140 } }

                            Image {
                                anchors.fill: parent
                                source: modelData.cover || ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }

                            MouseArea {
                                id: artistMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: MusicState.playItem({
                                    title: modelData.name,
                                    artist: modelData.name,
                                    cover: modelData.cover || "",
                                    platform: modelData.platform || MusicState.selectedPlatform,
                                    url: modelData.url || ""
                                })
                            }
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData.name || ""
                            color: MusicState.m3OnSurface
                            font.family: MusicState.fontUi
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
