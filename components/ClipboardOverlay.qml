import QtQuick
import QtQuick.Layouts
import "../services"

/**
 * Material You Clipboard History Overlay (cliphist, bound to SUPER + V).
 */
Item {
    id: root
    width: 420
    height: 440

    visible: opacity > 0.01
    opacity: ClipboardState.open ? 1.0 : 0.0
    scale: ClipboardState.open ? 1.0 : 0.94
    y: ClipboardState.open ? 0 : -12
    transformOrigin: Item.Top

    Behavior on opacity { M3Anim { duration: 240 } }
    Behavior on scale   { M3Anim { duration: 340 } }
    Behavior on y       { M3Anim { duration: 340 } }

    property string query: ""

    readonly property var filteredItems: {
        const list = ClipboardState.items || []
        const q = query.trim().toLowerCase()
        if (q === "") return list
        const out = []
        for (let i = 0; i < list.length; i++) {
            if (String(list[i].text || "").toLowerCase().indexOf(q) !== -1) {
                out.push(list[i])
            }
        }
        return out
    }

    Connections {
        target: ClipboardState
        function onOpenChanged() {
            if (ClipboardState.open) {
                root.query = ""
                clipSearch.text = ""
                focusT.restart()
            } else {
                clipSearch.focus = false
            }
        }
    }

    Timer {
        id: focusT
        interval: 40
        repeat: false
        onTriggered: clipSearch.forceActiveFocus()
    }

    Rectangle {
        anchors.fill: parent
        radius: MusicState.shapeXl
        border.width: 1
        border.color: MusicState.m3OutlineVariant
        color: MusicState.m3SurfaceContainer

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                SysIcon {
                    name: "clipboard"
                    size: 17
                    color: MusicState.m3Primary
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: "Буфер обмена"
                    color: MusicState.m3OnSurface
                    font.family: MusicState.fontUi
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }

                Rectangle {
                    visible: ClipboardState.items.length > 0
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: clrAllTxt.implicitWidth + 18
                    radius: 14
                    color: clrAllMa.containsMouse ? MusicState.m3SurfaceContainerHighest : MusicState.m3SurfaceContainerHigh

                    Text {
                        id: clrAllTxt
                        anchors.centerIn: parent
                        text: "Очистить"
                        color: MusicState.m3OnSurface
                        font.family: MusicState.fontUi
                        font.pixelSize: 11
                        font.weight: Font.SemiBold
                    }

                    MouseArea {
                        id: clrAllMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ClipboardState.clearAll()
                    }
                }
            }

            // Search bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: 19
                color: MusicState.m3SurfaceContainerHigh

                TextInput {
                    id: clipSearch
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    color: MusicState.m3OnSurface
                    font.family: MusicState.fontUi
                    font.pixelSize: 12
                    clip: true

                    onTextChanged: root.query = text
                    Keys.onEscapePressed: ClipboardState.open = false

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Поиск по истории..."
                        color: MusicState.m3OnSurfaceVariant
                        font.family: MusicState.fontUi
                        font.pixelSize: 12
                        visible: clipSearch.text === ""
                    }
                }
            }

            // Items List
            ListView {
                id: clipList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: root.filteredItems

                delegate: Rectangle {
                    required property var modelData
                    width: clipList.width
                    height: Math.max(46, clipTxt.implicitHeight + 18)
                    radius: 16
                    color: cRowMa.containsMouse ? MusicState.m3SurfaceContainerHighest : MusicState.m3SurfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 140 } }

                    MouseArea {
                        id: cRowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ClipboardState.copyItem(modelData.id)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        spacing: 10

                        Text {
                            id: clipTxt
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: modelData.isImage ? "Изображение (скриншот / картинка)" : (modelData.text || "")
                            color: modelData.isImage ? MusicState.m3Primary : MusicState.m3OnSurface
                            font.family: MusicState.fontUi
                            font.pixelSize: 12
                            font.weight: modelData.isImage ? Font.SemiBold : Font.Normal
                            wrapMode: Text.WrapAnywhere
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        Item {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            Layout.alignment: Qt.AlignVCenter
                            z: 5

                            SysIcon {
                                anchors.centerIn: parent
                                name: "trash"
                                size: 13
                                color: delMa.containsMouse ? "#F2B8B5" : MusicState.m3OnSurfaceVariant
                            }

                            MouseArea {
                                id: delMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ClipboardState.deleteItem(modelData.id)
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 32
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    visible: clipList.count === 0
                    text: ClipboardState.hasCliphist
                        ? "История буфера обмена пуста"
                        : "Установите cliphist:\nsudo pacman -S cliphist wl-clipboard"
                    color: MusicState.m3OnSurfaceVariant
                    font.family: MusicState.fontUi
                    font.pixelSize: 12
                }
            }
        }
    }
}
