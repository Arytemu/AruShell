import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../services"

/**
 * Top-Right Bar Cluster with modern Material/Lucide SysIcon & M3Anim curves:
 * [ Expandable System Tray ] [ System Controls Pill (Wi-Fi / BT / Vol / Bat) ] [ Notification Bell ]
 */
Row {
    id: root
    height: 38
    spacing: 8

    property var parentPanel: null
    property bool trayExpanded: false

    readonly property var trayItems: SystemTray.items.values || []

    // 1. Expandable System Tray Pill
    Rectangle {
        height: 36
        width: trayExpanded
            ? (36 + (root.trayItems.length > 0 ? root.trayItems.length * 28 + 10 : 0))
            : (root.trayItems.length > 0 ? 52 : 36)
        y: (root.height - height) / 2
        radius: 18
        color: MusicState.m3SurfaceContainer
        clip: true

        Behavior on width { M3Anim { duration: 360 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 6

            // Expand / Collapse Chevron
            Item {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                Layout.alignment: Qt.AlignVCenter

                SysIcon {
                    anchors.centerIn: parent
                    name: "chevron_left"
                    size: 16
                    color: MusicState.m3OnSurface
                    rotation: root.trayExpanded ? 180 : 0
                    Behavior on rotation { M3Anim { duration: 320 } }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.trayExpanded = !root.trayExpanded
                }
            }

            // Collapsed count badge
            Text {
                visible: !root.trayExpanded && root.trayItems.length > 0
                text: String(root.trayItems.length)
                color: MusicState.m3OnSurfaceVariant
                font.family: MusicState.fontUi
                font.pixelSize: 11
                font.weight: Font.Bold
                Layout.alignment: Qt.AlignVCenter

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.trayExpanded = true
                }
            }

            // Expanded Tray Icons (strictly ORIGINAL colors!)
            RowLayout {
                visible: opacity > 0.01
                opacity: root.trayExpanded ? 1.0 : 0.0
                Layout.alignment: Qt.AlignVCenter
                spacing: 6

                Behavior on opacity { M3Anim { duration: 240 } }

                Repeater {
                    model: root.trayItems

                    delegate: Item {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        Layout.alignment: Qt.AlignVCenter

                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 18
                            mipmap: true
                            asynchronous: true
                            source: modelData.icon || ""
                            scale: tMa.containsMouse ? 1.15 : 1.0
                            Behavior on scale { M3Anim { duration: 180 } }
                        }

                        MouseArea {
                            id: tMa
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function(mouse) {
                                if (mouse.button === Qt.RightButton || modelData.onlyMenu) {
                                    if (modelData.hasMenu && root.parentPanel) {
                                        const pt = mapToItem(null, width / 2, height + 6)
                                        modelData.display(root.parentPanel, pt.x, pt.y)
                                    }
                                } else {
                                    modelData.activate()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // 1.5. Compact Keyboard Layout Pill (RU / EN)
    Rectangle {
        height: 36
        width: kbdTxt.implicitWidth + 20
        y: (root.height - height) / 2
        radius: 18
        color: kbdMa.containsMouse ? MusicState.m3SurfaceContainerHigh : MusicState.m3SurfaceContainer
        Behavior on color { ColorAnimation { duration: 180 } }

        Text {
            id: kbdTxt
            anchors.centerIn: parent
            text: SystemState.kbdLayout
            color: MusicState.m3OnSurface
            font.family: MusicState.fontUi
            font.pixelSize: 11
            font.weight: Font.Bold
        }

        MouseArea {
            id: kbdMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: SystemState.switchKeyboardLayout()
        }
    }

    // 2. Modern System Settings Pill (Wi-Fi + Bluetooth + Volume + optional Battery)
    Rectangle {
        id: sysPill
        height: 36
        width: sysRow.implicitWidth + 24
        y: (root.height - height) / 2
        radius: 18
        color: SystemState.quickSettingsOpen
            ? MusicState.m3PrimaryContainer
            : (sysMa.containsMouse ? MusicState.m3SurfaceContainerHigh : MusicState.m3SurfaceContainer)
        Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutCubic } }

        readonly property color fgCol: SystemState.quickSettingsOpen
            ? MusicState.m3OnPrimaryContainer
            : MusicState.m3OnSurface

        RowLayout {
            id: sysRow
            anchors.centerIn: parent
            spacing: 10

            SysIcon {
                name: SystemState.ethernetConnected ? "ethernet" : (SystemState.wifiEnabled ? "wifi" : "wifi_off")
                size: 16
                color: sysPill.fgCol
                opacity: (SystemState.wifiEnabled || SystemState.ethernetConnected) ? 1.0 : 0.45
                Layout.alignment: Qt.AlignVCenter
            }

            SysIcon {
                name: SystemState.btEnabled ? "bluetooth" : "bluetooth_off"
                size: 16
                color: sysPill.fgCol
                opacity: SystemState.btEnabled ? 1.0 : 0.45
                Layout.alignment: Qt.AlignVCenter
            }

            SysIcon {
                name: (SystemState.muted || SystemState.volume === 0)
                    ? "volume_mute"
                    : (SystemState.volume < 45 ? "volume_low" : "volume_high")
                size: 16
                color: sysPill.fgCol
                Layout.alignment: Qt.AlignVCenter
            }

            RowLayout {
                visible: SystemState.hasBattery
                Layout.alignment: Qt.AlignVCenter
                spacing: 4

                SysIcon {
                    name: SystemState.batteryCharging ? "battery_charging" : "battery"
                    size: 16
                    color: sysPill.fgCol
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: SystemState.batteryPercent + "%"
                    color: sysPill.fgCol
                    font.family: MusicState.fontUi
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }

        WheelHandler {
            onWheel: function(event) {
                SystemState.adjustVolume(event.angleDelta.y > 0 ? 5 : -5)
            }
        }

        MouseArea {
            id: sysMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: SystemState.toggleQuickSettings()
        }
    }

    // 3. Material 3 Expressive Notification Bell (morphs into Cookie8 when unread > 0!)
    Item {
        width: 38
        height: 38
        y: (root.height - height) / 2

        M3Shape {
            anchors.fill: parent
            shape: ShellConfig.notifShape
            morphFactor: 1.0
            fillColor: NotifState.centerOpen
                ? MusicState.m3PrimaryContainer
                : (bellMa.containsMouse ? MusicState.m3SurfaceContainerHigh : MusicState.m3SurfaceContainer)
        }

        SysIcon {
            anchors.centerIn: parent
            name: NotifState.dndEnabled ? "bell_off" : "bell"
            size: 17
            color: NotifState.centerOpen ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface
        }

        Rectangle {
            visible: NotifState.unreadCount > 0 && !NotifState.dndEnabled
            width: 8
            height: 8
            radius: 4
            anchors { top: parent.top; right: parent.right; topMargin: 6; rightMargin: 6 }
            color: MusicState.m3Primary
        }

        MouseArea {
            id: bellMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                SystemState.quickSettingsOpen = false
                SystemState.launcherOpen = false
                NotifState.toggleCenter()
            }
        }
    }
}
