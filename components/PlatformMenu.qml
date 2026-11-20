import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import "../services"

/**
 * Material You Platform Switcher Menu:
 * - M3 Surface Container card with soft elevation shadow, zero borders
 * - Active platform uses M3 Primary Container tonal pill
 */
Item {
    id: root
    width: 262
    height: menuCol.implicitHeight + 16

    visible: opacity > 0.01
    opacity: MusicState.platformMenuOpen ? 1.0 : 0.0
    scale: MusicState.platformMenuOpen ? 1.0 : 0.93
    transformOrigin: Item.BottomLeft

    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Behavior on scale   { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

    Rectangle {
        id: menuShadow
        anchors.fill: parent
        radius: 24
        color: "#000000"
        visible: false
    }

    MultiEffect {
        anchors.fill: menuShadow
        source: menuShadow
        shadowEnabled: true
        shadowColor: Qt.rgba(0.0, 0.0, 0.0, 0.50)
        shadowBlur: 0.85
        shadowVerticalOffset: 10
        autoPaddingEnabled: true
    }

    Rectangle {
        anchors.fill: parent
        radius: 24
        color: MusicState.m3SurfaceContainer

        Column {
            id: menuCol
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 8
            }
            spacing: 4

            Repeater {
                model: MusicState.platforms

                delegate: Column {
                    width: menuCol.width
                    spacing: 4

                    Rectangle {
                        visible: modelData.id === "automatic"
                        width: parent.width - 20
                        height: 1
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: MusicState.m3OutlineVariant
                    }

                    Rectangle {
                        id: platItem
                        width: parent.width
                        height: 40
                        radius: 14

                        readonly property bool isSelected: MusicState.selectedPlatform === modelData.id

                        color: isSelected
                            ? MusicState.m3PrimaryContainer
                            : (itemMouse.containsMouse ? MusicState.m3SurfaceContainerHigh : "transparent")

                        Behavior on color { ColorAnimation { duration: 130 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 12
                            spacing: 10

                            Image {
                                source: modelData.icon
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                Layout.alignment: Qt.AlignVCenter
                                sourceSize: Qt.size(48, 48)
                                smooth: true
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: modelData.name
                                color: platItem.isSelected ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface
                                font.family: MusicState.fontUi
                                font.pixelSize: 13
                                font.weight: platItem.isSelected ? Font.Bold : Font.Medium
                                elide: Text.ElideRight
                            }

                            IconImage {
                                visible: platItem.isSelected
                                Layout.preferredWidth: 15
                                Layout.preferredHeight: 15
                                Layout.alignment: Qt.AlignVCenter
                                implicitSize: 15
                                source: Quickshell.iconPath("object-select-symbolic", true) || Quickshell.iconPath("emblem-ok-symbolic", true)
                            }
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: MusicState.selectPlatform(modelData.id)
                        }
                    }
                }
            }
        }
    }
}
