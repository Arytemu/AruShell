import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../services"

/**
 * Smooth Material You Notification Center dropdown panel.
 * Clicking any notification invokes its default action and focuses the app window.
 */
Item {
    id: root
    width: 360
    height: 410

    visible: opacity > 0.01
    opacity: NotifState.centerOpen ? 1.0 : 0.0
    scale: NotifState.centerOpen ? 1.0 : 0.95
    y: NotifState.centerOpen ? 0 : -10
    transformOrigin: Item.TopRight

    Behavior on opacity { M3Anim { duration: NotifState.centerOpen ? 260 : 160 } }
    Behavior on scale   { M3Anim { duration: NotifState.centerOpen ? 340 : 180 } }
    Behavior on y       { M3Anim { duration: NotifState.centerOpen ? 340 : 180 } }

    Rectangle {
        anchors.fill: parent
        radius: MusicState.shapeXl
        color: MusicState.m3SurfaceContainer
        border.width: 1
        border.color: MusicState.m3OutlineVariant

        // Absorb clicks on panel background so they don't fall through to TopBar backdrop dismiss
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Уведомления"
                    color: MusicState.m3OnSurface
                    font.family: MusicState.fontUi
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: dndLabel.implicitWidth + 18
                    Layout.alignment: Qt.AlignVCenter
                    radius: 14
                    color: NotifState.dndEnabled ? MusicState.m3TertiaryContainer : MusicState.m3SurfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 160 } }

                    Text {
                        id: dndLabel
                        anchors.centerIn: parent
                        text: NotifState.dndEnabled ? "DND вкл" : "DND"
                        color: NotifState.dndEnabled ? MusicState.m3OnTertiaryContainer : MusicState.m3OnSurfaceVariant
                        font.family: MusicState.fontUi
                        font.pixelSize: 11
                        font.weight: Font.SemiBold
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NotifState.dndEnabled = !NotifState.dndEnabled
                    }
                }

                Rectangle {
                    visible: NotifState.history.length > 0
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: clearLabel.implicitWidth + 18
                    Layout.alignment: Qt.AlignVCenter
                    radius: 14
                    color: clearMa.containsMouse ? MusicState.m3ErrorContainer : MusicState.m3SurfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 160 } }

                    Text {
                        id: clearLabel
                        anchors.centerIn: parent
                        text: "Очистить"
                        color: clearMa.containsMouse ? MusicState.m3OnErrorContainer : MusicState.m3OnSurface
                        font.family: MusicState.fontUi
                        font.pixelSize: 11
                        font.weight: Font.SemiBold
                    }

                    MouseArea {
                        id: clearMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NotifState.clearAll()
                    }
                }
            }

            ListView {
                id: notifList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 8
                model: NotifState.history

                delegate: Rectangle {
                    id: notifCard
                    readonly property int cardIndex: index
                    readonly property var cardData: modelData
                    width: Math.max(0, notifList.width || 0)
                    height: cardCol.implicitHeight + 20
                    radius: 18
                    color: cardMa.containsMouse ? MusicState.m3SurfaceContainerHighest : MusicState.m3SurfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 160 } }

                    // Full-card click activates notification default action & focuses the app!
                    MouseArea {
                        id: cardMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NotifState.activateEntry(modelData, index)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34
                            Layout.alignment: Qt.AlignTop
                            radius: 10
                            color: MusicState.m3SurfaceContainer
                            clip: true

                            IconImage {
                                visible: modelData.appIcon !== ""
                                anchors.centerIn: parent
                                implicitSize: 22
                                source: modelData.appIcon ? Quickshell.iconPath(modelData.appIcon, true) : ""
                            }

                            SysIcon {
                                visible: modelData.appIcon === ""
                                anchors.centerIn: parent
                                name: "bell"
                                size: 17
                                color: MusicState.m3Primary
                            }
                        }

                        ColumnLayout {
                            id: cardCol
                            Layout.fillWidth: true
                            spacing: 3

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.appName || "Система"
                                    color: MusicState.m3Primary
                                    font.family: MusicState.fontUi
                                    font.pixelSize: 11
                                    font.weight: Font.SemiBold
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    readonly property bool appMuted: NotifState.isAppMuted(modelData.appName)
                                    Layout.preferredHeight: 22
                                    Layout.preferredWidth: mute1Txt.implicitWidth + 12
                                    radius: 11
                                    z: 5
                                    color: appMuted ? MusicState.m3TertiaryContainer : MusicState.m3SurfaceContainer
                                    Text {
                                        id: mute1Txt
                                        anchors.centerIn: parent
                                        text: parent.appMuted ? "Мут ×" : "1ч"
                                        color: parent.appMuted ? MusicState.m3OnTertiaryContainer : MusicState.m3OnSurfaceVariant
                                        font.family: MusicState.fontUi; font.pixelSize: 10; font.weight: Font.Bold
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (NotifState.isAppMuted(modelData.appName)) NotifState.unmuteApp(modelData.appName)
                                            else NotifState.muteApp(modelData.appName, 1)
                                        }
                                    }
                                }

                                Rectangle {
                                    visible: !NotifState.isAppMuted(modelData.appName)
                                    Layout.preferredHeight: 22
                                    Layout.preferredWidth: mute4Txt.implicitWidth + 12
                                    radius: 11
                                    z: 5
                                    color: MusicState.m3SurfaceContainer
                                    Text {
                                        id: mute4Txt
                                        anchors.centerIn: parent
                                        text: "4ч"
                                        color: MusicState.m3OnSurfaceVariant
                                        font.family: MusicState.fontUi; font.pixelSize: 10; font.weight: Font.Bold
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: NotifState.muteApp(modelData.appName, 4)
                                    }
                                }

                                Text {
                                    text: modelData.time || ""
                                    color: MusicState.m3OnSurfaceVariant
                                    font.family: MusicState.fontUi
                                    font.pixelSize: 10
                                }

                                // Dismiss button (above card MouseArea)
                                Item {
                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: 20
                                    z: 5

                                    SysIcon {
                                        anchors.centerIn: parent
                                        name: "close"
                                        size: 13
                                        color: closeMa.containsMouse ? MusicState.m3OnSurface : MusicState.m3OnSurfaceVariant
                                    }

                                    MouseArea {
                                        id: closeMa
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: NotifState.dismissAt(index)
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: modelData.summary || ""
                                color: MusicState.m3OnSurface
                                font.family: MusicState.fontUi
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: modelData.body || ""
                                color: MusicState.m3OnSurfaceVariant
                                font.family: MusicState.fontUi
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                            }

                            // Clickable Notification Action Buttons (e.g., Open / Reply)
                            Flow {
                                Layout.fillWidth: true
                                Layout.topMargin: 4
                                spacing: 6
                                visible: actionRepeater.count > 0
                                z: 5

                                Repeater {
                                    id: actionRepeater
                                    model: {
                                        const list = modelData.actions || []
                                        const out = []
                                        for (let i = 0; i < list.length; i++) {
                                            if (list[i] && list[i].identifier !== "default" && list[i].text) {
                                                out.push(list[i])
                                            }
                                        }
                                        return out
                                    }

                                    delegate: Rectangle {
                                        height: 24
                                        width: actTxt.implicitWidth + 16
                                        radius: 12
                                        color: actMa.containsMouse ? MusicState.m3Primary : MusicState.m3PrimaryContainer
                                        Behavior on color { ColorAnimation { duration: 140 } }

                                        Text {
                                            id: actTxt
                                            anchors.centerIn: parent
                                            text: modelData.text
                                            color: actMa.containsMouse ? MusicState.m3OnPrimary : MusicState.m3OnPrimaryContainer
                                            font.family: MusicState.fontUi
                                            font.pixelSize: 11
                                            font.weight: Font.SemiBold
                                        }

                                        MouseArea {
                                            id: actMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: NotifState.invokeAction(notifCard.cardData, modelData, notifCard.cardIndex)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: notifList.count === 0
                    text: "Нет новых уведомлений"
                    color: MusicState.m3OnSurfaceVariant
                    font.family: MusicState.fontUi
                    font.pixelSize: 13
                }
            }
        }
    }
}
