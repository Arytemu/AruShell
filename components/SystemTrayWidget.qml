import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../services"

/**
 * Unified Top-Right Material 3 Pill Cluster:
 * [ (Tray expanding left) | (Language Globe -> dropdown) | (Wi-Fi/BT/Vol/Bat -> QuickSettings) ]  [ Notification Bell ]
 */
Row {
    id: root
    height: 36
    spacing: 8

    property var parentPanel: null
    property bool trayExpanded: false

    readonly property var trayItems: SystemTray.items.values || []

    // 1. Unified Material 3 Control Pill (Tray + Language Globe + System Controls)
    Rectangle {
        id: unifiedPill
        height: 36
        width: Math.round(unifiedRow.implicitWidth + 10)
        y: (root.height - height) / 2
        radius: 18
        color: MusicState.m3SurfaceContainer
        border.width: 1
        border.color: (SystemState.quickSettingsOpen || SystemState.langMenuOpen)
            ? MusicState.m3Primary
            : MusicState.m3OutlineVariant
        clip: true

        // Outer pill tracks unifiedRow synchronously; ONLY the tray width animates,
        // and unifiedRow is right-anchored so Language & System Controls stay 100% locked!
        Behavior on border.color { ColorAnimation { duration: 180 } }

        RowLayout {
            id: unifiedRow
            anchors {
                right: parent.right
                rightMargin: 5
                verticalCenter: parent.verticalCenter
            }
            height: 36
            spacing: 2

            // --- Segment A: System Tray (expands smoothly to the left, zero jitter) ---
            Item {
                Layout.preferredHeight: 30
                Layout.preferredWidth: trayExpanded
                    ? (28 + (root.trayItems.length > 0 ? root.trayItems.length * 26 + 8 : 0))
                    : (root.trayItems.length > 0 ? 44 : 28)
                Layout.alignment: Qt.AlignVCenter
                clip: true

                Behavior on Layout.preferredWidth { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 4
                    spacing: 5

                    // Expand / Collapse Chevron
                    Item {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        Layout.alignment: Qt.AlignVCenter

                        SysIcon {
                            anchors.centerIn: parent
                            name: "chevron_left"
                            size: 15
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

                    // Expanded Tray Icons (strictly ORIGINAL untouched colors!)
                    RowLayout {
                        visible: opacity > 0.01
                        opacity: root.trayExpanded ? 1.0 : 0.0
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 4

                        Behavior on opacity { M3Anim { duration: 220 } }

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

            // Subtle M3 vertical divider
            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 16
                Layout.alignment: Qt.AlignVCenter
                color: MusicState.m3OutlineVariant
            }

            // --- Segment B: Language Globe Icon (opens LanguageMenu dropdown) ---
            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 28
                Layout.alignment: Qt.AlignVCenter
                radius: 14
                color: SystemState.langMenuOpen
                    ? MusicState.m3SecondaryContainer
                    : (langMa.containsMouse ? MusicState.m3SurfaceContainerHigh : "transparent")
                Behavior on color { ColorAnimation { duration: 160 } }

                SysIcon {
                    anchors.centerIn: parent
                    name: "language"
                    size: 16
                    color: SystemState.langMenuOpen
                        ? MusicState.m3OnSecondaryContainer
                        : MusicState.m3OnSurface
                }

                MouseArea {
                    id: langMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SystemState.toggleLangMenu()
                }
            }

            // Subtle M3 vertical divider
            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 16
                Layout.alignment: Qt.AlignVCenter
                color: MusicState.m3OutlineVariant
            }

            // --- Segment C: System Controls (opens QuickSettings dropdown) ---
            Rectangle {
                id: sysSeg
                Layout.preferredHeight: 28
                Layout.preferredWidth: Math.max(36, Math.round(sysRow.implicitWidth + Math.max(14, ShellConfig.pillPadding - 6)))
                Layout.alignment: Qt.AlignVCenter
                radius: 14
                color: SystemState.quickSettingsOpen
                    ? MusicState.m3PrimaryContainer
                    : (sysMa.containsMouse ? MusicState.m3SurfaceContainerHigh : "transparent")
                Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }

                readonly property color fgCol: SystemState.quickSettingsOpen
                    ? MusicState.m3OnPrimaryContainer
                    : MusicState.m3OnSurface

                RowLayout {
                    id: sysRow
                    anchors.centerIn: parent
                    spacing: ShellConfig.pillSpacing

                    SysIcon {
                        visible: ShellConfig.hasPillItem("wifi")
                        name: SystemState.ethernetConnected ? "ethernet" : (SystemState.wifiEnabled ? "wifi" : "wifi_off")
                        size: ShellConfig.pillIconSize
                        color: sysSeg.fgCol
                        opacity: (SystemState.wifiEnabled || SystemState.ethernetConnected) ? 1.0 : 0.55
                        Layout.alignment: Qt.AlignVCenter
                    }

                    SysIcon {
                        visible: ShellConfig.hasPillItem("bt")
                        name: SystemState.btEnabled ? "bluetooth" : "bluetooth_off"
                        size: ShellConfig.pillIconSize
                        color: sysSeg.fgCol
                        opacity: SystemState.btEnabled ? 1.0 : 0.45
                        Layout.alignment: Qt.AlignVCenter
                    }

                    SysIcon {
                        visible: ShellConfig.hasPillItem("volume")
                        name: (SystemState.muted || SystemState.volume === 0)
                            ? "volume_mute"
                            : (SystemState.volume < 45 ? "volume_low" : "volume_high")
                        size: ShellConfig.pillIconSize
                        color: sysSeg.fgCol
                        Layout.alignment: Qt.AlignVCenter
                    }

                    SysIcon {
                        visible: ShellConfig.hasPillItem("nightLight")
                        name: "moon"
                        size: Math.max(12, ShellConfig.pillIconSize - 1)
                        color: sysSeg.fgCol
                        opacity: SystemState.nightLight ? 1.0 : 0.42
                        Layout.alignment: Qt.AlignVCenter
                    }

                    SysIcon {
                        visible: ShellConfig.hasPillItem("gameMode")
                        name: "apps"
                        size: Math.max(12, ShellConfig.pillIconSize - 1)
                        color: SystemState.gameMode ? MusicState.m3Primary : sysSeg.fgCol
                        opacity: SystemState.gameMode ? 1.0 : 0.42
                        Layout.alignment: Qt.AlignVCenter
                    }

                    RowLayout {
                        visible: ShellConfig.hasPillItem("battery") && SystemState.hasBattery
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 4

                        SysIcon {
                            name: SystemState.batteryCharging ? "battery_charging" : "battery"
                            size: ShellConfig.pillIconSize
                            color: sysSeg.fgCol
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: SystemState.batteryPercent + "%"
                            color: sysSeg.fgCol
                            font.family: MusicState.fontUi
                            font.pixelSize: Math.max(10, ShellConfig.pillIconSize - 4)
                            font.weight: Font.Bold
                            Layout.alignment: Qt.AlignVCenter
                        }
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
        }
    }

    // 2. Material 3 Expressive Notification Bell (unified 36x36 height + matching outlineVariant border)
    Item {
        width: 36
        height: 36
        y: 0

        M3Shape {
            anchors.fill: parent
            shape: ShellConfig.notifShape
            morphFactor: 1.0
            fillColor: NotifState.centerOpen
                ? MusicState.m3PrimaryContainer
                : (bellMa.containsMouse ? MusicState.m3SurfaceContainerHigh : MusicState.m3SurfaceContainer)
            strokeWidth: 1.1
            strokeColor: NotifState.centerOpen ? MusicState.m3Primary : MusicState.m3OutlineVariant
        }

        SysIcon {
            anchors.centerIn: parent
            name: NotifState.dndEnabled ? "bell_off" : "bell"
            size: 15
            color: NotifState.centerOpen ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface
        }

        Rectangle {
            visible: NotifState.unreadCount > 0 && !NotifState.dndEnabled
            width: 8
            height: 8
            radius: 4
            color: MusicState.m3Error
            anchors {
                top: parent.top
                right: parent.right
                topMargin: 5
                rightMargin: 5
            }
        }

        MouseArea {
            id: bellMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                SystemState.quickSettingsOpen = false
                SystemState.langMenuOpen = false
                SystemState.launcherOpen = false
                ClipboardState.open = false
                NotifState.toggleCenter()
            }
        }
    }
}
