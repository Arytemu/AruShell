import QtQuick
import QtQuick.Layouts
import Quickshell
import "../services"

/**
 * Right-Click Desktop Management Context Menu (Material You):
 * - Toggle Widget Drag / Edit Mode
 * - Reset Widget Positions
 * - Show / Hide Clock & Music Stage
 * - Pin / Unpin Bottom Dock
 * - Screenshot, Shell Settings, Reload Shell
 */
Item {
    id: root
    anchors.fill: parent
    visible: ShellConfig.desktopMenuOpen || menuCard.opacity > 0.01

    // Click anywhere outside to close context menu
    MouseArea {
        anchors.fill: parent
        enabled: ShellConfig.desktopMenuOpen
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                ShellConfig.openDesktopMenu(mouse.x, mouse.y)
            } else {
                ShellConfig.closeDesktopMenu()
            }
        }
    }

    Rectangle {
        id: menuCard
        width: 248
        height: menuCol.implicitHeight + 16
        radius: 22
        color: MusicState.m3SurfaceContainer

        x: Math.max(12, Math.min(root.width - width - 12, ShellConfig.desktopMenuX))
        y: Math.max(56, Math.min(root.height - height - 16, ShellConfig.desktopMenuY))

        opacity: ShellConfig.desktopMenuOpen ? 1.0 : 0.0
        scale: ShellConfig.desktopMenuOpen ? 1.0 : 0.92
        transformOrigin: Item.TopLeft

        Behavior on opacity { M3Anim { duration: 180 } }
        Behavior on scale   { M3Anim { duration: 240 } }

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: menuCol
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 8
            }
            spacing: 2

            Repeater {
                model: [
                    { id: "edit",       icon: "move",       label: ShellConfig.editMode ? "Завершить перенос виджетов" : "Перемещать виджеты", active: ShellConfig.editMode },
                    { id: "reset",      icon: "refresh",    label: "Сбросить позиции виджетов", active: false },
                    { id: "sep1",       sep: true },
                    { id: "clock",      icon: "eye",        label: ShellConfig.clockVisible ? "Скрыть часы" : "Показать часы", active: false },
                    { id: "stage",      icon: "eye",        label: ShellConfig.stageVisible ? "Скрыть обложку и текст" : "Показать обложку и текст", active: false },
                    { id: "dock",       icon: "sliders",    label: ShellConfig.dockPinned ? "Открепить нижний док" : "Закрепить нижний док", active: ShellConfig.dockPinned },
                    { id: "sep2",       sep: true },
                    { id: "wallpaper",  icon: "palette",    label: "Выбрать обои (Win+W)", active: false },
                    { id: "screenshot", icon: "screenshot", label: "Сделать скриншот", active: false },
                    { id: "settings",   icon: "settings",   label: "Настройки шелла", active: false },
                    { id: "reload",     icon: "reboot",     label: "Перезагрузить шелл", active: false }
                ]

                delegate: Item {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: modelData.sep ? 9 : 36

                    Rectangle {
                        visible: !!modelData.sep
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        height: 1
                        color: MusicState.m3SurfaceContainerHighest
                    }

                    Rectangle {
                        visible: !modelData.sep
                        anchors.fill: parent
                        radius: 14
                        color: modelData.active
                            ? MusicState.m3PrimaryContainer
                            : (mItemMa.containsMouse ? MusicState.m3SurfaceContainerHigh : "transparent")
                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            SysIcon {
                                name: modelData.icon || "apps"
                                size: 15
                                color: modelData.active ? MusicState.m3OnPrimaryContainer : MusicState.m3Primary
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.label || ""
                                color: modelData.active ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface
                                font.family: MusicState.fontUi
                                font.pixelSize: 12
                                font.weight: modelData.active ? Font.Bold : Font.Medium
                                elide: Text.ElideRight
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        MouseArea {
                            id: mItemMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const act = modelData.id
                                ShellConfig.closeDesktopMenu()
                                if (act === "edit") {
                                    ShellConfig.editMode = !ShellConfig.editMode
                                } else if (act === "reset") {
                                    ShellConfig.resetWidgetPositions()
                                } else if (act === "clock") {
                                    ShellConfig.clockVisible = !ShellConfig.clockVisible
                                    ShellConfig.save()
                                } else if (act === "stage") {
                                    ShellConfig.stageVisible = !ShellConfig.stageVisible
                                    ShellConfig.save()
                                } else if (act === "dock") {
                                    ShellConfig.dockPinned = !ShellConfig.dockPinned
                                    ShellConfig.save()
                                } else if (act === "wallpaper") {
                                    WallpaperState.toggle()
                                } else if (act === "screenshot") {
                                    ScreenshotState.open("region")
                                } else if (act === "settings") {
                                    ShellConfig.openSettings()
                                } else if (act === "reload") {
                                    Quickshell.reload(true)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
