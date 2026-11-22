import QtQuick
import QtQuick.Layouts
import "../services"

/**
 * Material Design 3 Keyboard Layout Dropdown Menu (opened from the merged top-bar globe icon).
 */
Item {
    id: root
    width: 220
    height: Math.max(110, Math.round(col.implicitHeight + 24))

    visible: opacity > 0.01
    opacity: SystemState.langMenuOpen ? 1.0 : 0.0
    scale: SystemState.langMenuOpen ? 1.0 : 0.94
    y: SystemState.langMenuOpen ? 0 : -10
    transformOrigin: Item.TopRight

    Behavior on opacity { M3Anim { duration: 220 } }
    Behavior on scale   { M3Anim { duration: 300 } }
    Behavior on y       { M3Anim { duration: 300 } }

    Rectangle {
        anchors.fill: parent
        radius: MusicState.shapeXl
        color: MusicState.m3SurfaceContainer
        border.width: 1
        border.color: MusicState.m3OutlineVariant

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: col
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 12
            }
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                Layout.rightMargin: 6
                Layout.bottomMargin: 2
                spacing: 8

                SysIcon {
                    name: "language"
                    size: 15
                    color: MusicState.m3Primary
                }

                Text {
                    Layout.fillWidth: true
                    text: "Раскладка"
                    color: MusicState.m3OnSurface
                    font.family: MusicState.fontUi
                    font.pixelSize: MusicState.typeTitleSm
                    font.weight: Font.Bold
                }

                Text {
                    text: SystemState.kbdLayout
                    color: MusicState.m3OnSurfaceVariant
                    font.family: MusicState.fontUi
                    font.pixelSize: MusicState.typeLabelMd
                    font.weight: Font.Bold
                }
            }

            Repeater {
                model: SystemState.kbdLayouts

                delegate: Rectangle {
                    required property var modelData
                    readonly property bool isActive: SystemState.kbdLayout === modelData.code

                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    radius: MusicState.shapeMd
                    color: isActive
                        ? MusicState.m3SecondaryContainer
                        : (langItemMa.containsMouse ? MusicState.m3SurfaceContainerHigh : "transparent")
                    Behavior on color { ColorAnimation { duration: 140 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        Text {
                            Layout.fillWidth: true
                            text: modelData.name
                            color: isActive ? MusicState.m3OnSecondaryContainer : MusicState.m3OnSurface
                            font.family: MusicState.fontUi
                            font.pixelSize: 12
                            font.weight: isActive ? Font.Bold : Font.Medium
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 20
                            radius: 10
                            color: isActive ? MusicState.m3Primary : MusicState.m3SurfaceContainerHighest

                            Text {
                                anchors.centerIn: parent
                                text: modelData.code
                                color: isActive ? MusicState.m3OnPrimary : MusicState.m3OnSurfaceVariant
                                font.family: MusicState.fontUi
                                font.pixelSize: 10
                                font.weight: Font.Bold
                            }
                        }
                    }

                    MouseArea {
                        id: langItemMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SystemState.setKeyboardLayout(modelData.index, modelData.code)
                    }
                }
            }
        }
    }
}
