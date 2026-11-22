import QtQuick
import QtQuick.Layouts
import "../services"

/**
 * Material You Quick Settings Control Center:
 * - Main view: Wi-Fi & Bluetooth tiles (with submenu arrows), Night Light (hyprsunset), Power Profile / DND
 * - Chubby M3WavyBar Volume (with Audio Output switcher button) & Brightness sliders
 * - Bottom row: Screenshot, Clipboard, Battery, Lock / Suspend / Reboot / Power Off
 * - Expandable submenus: Wi-Fi networks, Bluetooth paired devices, Audio output sinks
 */
Item {
    id: root
    width: SystemState.quickSettingsSubmenu === "edit" ? Math.max(350, ShellConfig.qsWidth) : ShellConfig.qsWidth
    Behavior on width { M3Anim { duration: 260 } }
    readonly property int targetHeight: SystemState.quickSettingsSubmenu === ""
        ? Math.max(120, Math.round(mainCol.implicitHeight + 32))
        : (SystemState.quickSettingsSubmenu === "edit" ? 480 : 368)
    height: targetHeight
    Behavior on height { M3Anim { duration: 280 } }

    visible: opacity > 0.01
    opacity: SystemState.quickSettingsOpen ? 1.0 : 0.0
    scale: SystemState.quickSettingsOpen ? 1.0 : 0.94
    y: SystemState.quickSettingsOpen ? 0 : -12
    transformOrigin: Item.TopRight

    Behavior on opacity { M3Anim { duration: 260 } }
    Behavior on scale   { M3Anim { duration: 360 } }
    Behavior on y       { M3Anim { duration: 360 } }

    Rectangle {
        anchors.fill: parent
        radius: MusicState.shapeXl
        color: MusicState.m3SurfaceContainer
        border.width: 1
        border.color: MusicState.m3OutlineVariant

        // Absorb background clicks
        MouseArea { anchors.fill: parent }

        // =====================================================================
        // MAIN QUICK SETTINGS VIEW
        // =====================================================================
        ColumnLayout {
            id: mainCol
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 16
            }
            spacing: ShellConfig.qsSpacing
            visible: SystemState.quickSettingsSubmenu === ""

            // 0. Compact Header with Customize ("Изменить") Button
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Быстрые настройки"
                    color: MusicState.m3OnSurface
                    font.family: MusicState.fontUi; font.pixelSize: MusicState.typeTitleSm; font.weight: Font.Bold
                }

                Rectangle {
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: editPillRow.implicitWidth + 18
                    radius: 14
                    color: editPillMa.containsMouse ? MusicState.m3SecondaryContainer : MusicState.m3SurfaceContainerHigh
                    border.width: 1
                    border.color: MusicState.m3OutlineVariant
                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        id: editPillRow
                        anchors.centerIn: parent
                        spacing: 5
                        SysIcon { name: "edit"; size: 12; color: editPillMa.containsMouse ? MusicState.m3OnSecondaryContainer : MusicState.m3OnSurface }
                        Text { text: "Изменить"; color: editPillMa.containsMouse ? MusicState.m3OnSecondaryContainer : MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: MusicState.typeLabelMd; font.weight: Font.SemiBold }
                    }

                    MouseArea {
                        id: editPillMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SystemState.openSubmenu("edit")
                    }
                }
            }

            // 1. 2x2 Material You Tiles
            GridLayout {
                visible: ShellConfig.hasQsItem("wifi") || ShellConfig.hasQsItem("bt") || ShellConfig.hasQsItem("nightLight") || ShellConfig.hasQsItem("powerProfile")
                Layout.fillWidth: true
                columns: 2
                columnSpacing: ShellConfig.qsSpacing
                rowSpacing: ShellConfig.qsSpacing

                // Wi-Fi Tile (split: click body toggles, click arrow opens Wi-Fi list)
                Rectangle {
                    visible: ShellConfig.hasQsItem("wifi")
                    Layout.fillWidth: true
                    Layout.columnSpan: ShellConfig.isQsWide("wifi") ? 2 : 1
                    Layout.preferredHeight: ShellConfig.qsTileHeight
                    radius: (SystemState.wifiEnabled || SystemState.ethernetConnected) ? MusicState.shapeLg : Math.round(ShellConfig.qsTileHeight / 2)
                    Behavior on radius { M3Anim { duration: 280 } }
                    color: (SystemState.wifiEnabled || SystemState.ethernetConnected)
                        ? MusicState.m3PrimaryContainer
                        : MusicState.m3SurfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 200 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 8

                        SysIcon {
                            name: SystemState.ethernetConnected ? "ethernet" : (SystemState.wifiEnabled ? "wifi" : "wifi_off")
                            size: 18
                            color: (SystemState.wifiEnabled || SystemState.ethernetConnected) ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface
                            Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 1
                            Text {
                                Layout.fillWidth: true
                                text: SystemState.ethernetConnected ? "Ethernet" : "Wi-Fi"
                                color: (SystemState.wifiEnabled || SystemState.ethernetConnected) ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface
                                font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.Bold
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: SystemState.ethernetConnected ? "Подключено" : (SystemState.wifiEnabled ? (SystemState.wifiSsid || "Включён") : "Выкл")
                                color: (SystemState.wifiEnabled || SystemState.ethernetConnected) ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurfaceVariant
                                opacity: 0.85
                                font.family: MusicState.fontUi; font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }

                        // Submenu arrow button
                        Rectangle {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 36
                            radius: 13
                            color: wifiSubMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                            z: 5
                            SysIcon {
                                anchors.centerIn: parent
                                name: "chevron_right"
                                size: 14
                                color: (SystemState.wifiEnabled || SystemState.ethernetConnected) ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurfaceVariant
                            }
                            MouseArea {
                                id: wifiSubMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: SystemState.openSubmenu("wifi")
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.rightMargin: 34
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SystemState.toggleWifi()
                    }
                }

                // Bluetooth Tile (split: click body toggles, click arrow opens BT list)
                Rectangle {
                    visible: ShellConfig.hasQsItem("bt")
                    Layout.fillWidth: true
                    Layout.columnSpan: ShellConfig.isQsWide("bt") ? 2 : 1
                    Layout.preferredHeight: ShellConfig.qsTileHeight
                    radius: SystemState.btEnabled ? 15 : 29
                    Behavior on radius { M3Anim { duration: 280 } }
                    color: SystemState.btEnabled ? MusicState.m3PrimaryContainer : MusicState.m3SurfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 200 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 8

                        SysIcon {
                            name: SystemState.btEnabled ? "bluetooth" : "bluetooth_off"
                            size: 18
                            color: SystemState.btEnabled ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface
                            Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 1
                            Text {
                                Layout.fillWidth: true
                                text: "Bluetooth"
                                color: SystemState.btEnabled ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface
                                font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.Bold
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: SystemState.btEnabled ? (SystemState.btDevice || "Включён") : "Выкл"
                                color: SystemState.btEnabled ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurfaceVariant
                                opacity: 0.85
                                font.family: MusicState.fontUi; font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 36
                            radius: 13
                            color: btSubMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                            z: 5
                            SysIcon {
                                anchors.centerIn: parent
                                name: "chevron_right"
                                size: 14
                                color: SystemState.btEnabled ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurfaceVariant
                            }
                            MouseArea {
                                id: btSubMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: SystemState.openSubmenu("bt")
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.rightMargin: 34
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SystemState.toggleBluetooth()
                    }
                }

                // Night Light Tile (hyprsunset)
                Rectangle {
                    visible: ShellConfig.hasQsItem("nightLight")
                    Layout.fillWidth: true
                    Layout.columnSpan: ShellConfig.isQsWide("nightLight") ? 2 : 1
                    Layout.preferredHeight: ShellConfig.qsTileHeight
                    radius: SystemState.nightLight ? MusicState.shapeLg : Math.round(ShellConfig.qsTileHeight / 2)
                    Behavior on radius { M3Anim { duration: 280 } }
                    color: SystemState.nightLight ? MusicState.m3SecondaryContainer : MusicState.m3SurfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 200 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        SysIcon {
                            name: "nightlight"
                            size: 17
                            color: SystemState.nightLight ? MusicState.m3OnSecondaryContainer : MusicState.m3OnSurface
                            Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                Layout.fillWidth: true
                                text: "Ночной свет"
                                color: SystemState.nightLight ? MusicState.m3OnSecondaryContainer : MusicState.m3OnSurface
                                font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.Bold
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: SystemState.nightLight ? "4200K · Вкл" : "Выкл"
                                color: SystemState.nightLight ? MusicState.m3OnSecondaryContainer : MusicState.m3OnSurfaceVariant
                                opacity: 0.85
                                font.family: MusicState.fontUi; font.pixelSize: 10
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SystemState.toggleNightLight()
                    }
                }

                // Power Profile (or DND fallback if powerprofilesctl isn't installed)
                Rectangle {
                    id: profTile
                    visible: ShellConfig.hasQsItem("powerProfile")
                    Layout.fillWidth: true
                    Layout.columnSpan: ShellConfig.isQsWide("powerProfile") ? 2 : 1
                    Layout.preferredHeight: ShellConfig.qsTileHeight
                    radius: isActive ? MusicState.shapeLg : Math.round(ShellConfig.qsTileHeight / 2)
                    Behavior on radius { M3Anim { duration: 280 } }
                    readonly property bool hasProf: SystemState.powerProfile !== ""
                    readonly property bool isActive: hasProf ? (SystemState.powerProfile === "performance") : NotifState.dndEnabled
                    color: isActive ? MusicState.m3SecondaryContainer : MusicState.m3SurfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 200 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        SysIcon {
                            name: profTile.hasProf ? "performance" : (NotifState.dndEnabled ? "bell_off" : "bell")
                            size: 17
                            color: profTile.isActive ? MusicState.m3OnSecondaryContainer : MusicState.m3OnSurface
                            Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                Layout.fillWidth: true
                                text: profTile.hasProf ? "Питание" : "Не беспокоить"
                                color: profTile.isActive ? MusicState.m3OnSecondaryContainer : MusicState.m3OnSurface
                                font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.Bold
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: profTile.hasProf
                                    ? (SystemState.powerProfile === "performance" ? "Максимум" : (SystemState.powerProfile === "power-saver" ? "Экономия" : "Баланс"))
                                    : (NotifState.dndEnabled ? "Вкл" : "Выкл")
                                color: profTile.isActive ? MusicState.m3OnSecondaryContainer : MusicState.m3OnSurfaceVariant
                                opacity: 0.85
                                font.family: MusicState.fontUi; font.pixelSize: 10
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (SystemState.powerProfile !== "") SystemState.cyclePowerProfile()
                            else NotifState.dndEnabled = !NotifState.dndEnabled
                        }
                    }
                }
            }

            // 2. Chubby Wavy Volume Slider + Audio Output Switcher Button
            RowLayout {
                visible: ShellConfig.hasQsItem("volume")
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 17
                    color: SystemState.muted ? MusicState.m3SurfaceContainerHigh : MusicState.m3PrimaryContainer
                    SysIcon {
                        anchors.centerIn: parent
                        name: (SystemState.muted || SystemState.volume === 0) ? "volume_mute" : (SystemState.volume < 45 ? "volume_low" : "volume_high")
                        size: 16
                        color: SystemState.muted ? MusicState.m3OnSurfaceVariant : MusicState.m3OnPrimaryContainer
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: SystemState.toggleMute() }
                }

                M3WavyBar {
                    id: volBar
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    value: SystemState.muted ? 0 : (SystemState.volume / 100.0)
                    activeColor: MusicState.m3Primary
                    trackColor: MusicState.m3SurfaceContainerHigh
                    lineWidth: 6.0
                    amplitude: 3.8
                    animated: SystemState.quickSettingsOpen && SystemState.quickSettingsSubmenu === "" && !SystemState.muted && SystemState.volume > 0
                    onMoved: function(ratio) { SystemState.setVolume(ratio * 100) }
                }

                Text {
                    Layout.preferredWidth: 32
                    horizontalAlignment: Text.AlignRight
                    text: SystemState.muted ? "0%" : (SystemState.volume + "%")
                    color: MusicState.m3OnSurfaceVariant
                    font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.SemiBold
                }

                // Audio Output Device Selector Button
                Rectangle {
                    Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 16
                    color: audMa.containsMouse ? MusicState.m3PrimaryContainer : MusicState.m3SurfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 150 } }
                    SysIcon {
                        anchors.centerIn: parent
                        name: "audio_out"
                        size: 15
                        color: audMa.containsMouse ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface
                    }
                    MouseArea {
                        id: audMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SystemState.openSubmenu("audio")
                    }
                }
            }

            // 3. Chubby Wavy Brightness Slider (auto-shown on laptops)
            RowLayout {
                Layout.fillWidth: true
                visible: ShellConfig.hasQsItem("brightness") && SystemState.hasBrightness
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 17
                    color: MusicState.m3SurfaceContainerHigh
                    SysIcon { anchors.centerIn: parent; name: "brightness"; size: 17; color: MusicState.m3OnSurface }
                }

                M3WavyBar {
                    id: brBar
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    value: SystemState.brightness / 100.0
                    activeColor: MusicState.m3Primary
                    trackColor: MusicState.m3SurfaceContainerHigh
                    lineWidth: 6.0
                    amplitude: 3.8
                    animated: SystemState.quickSettingsOpen && SystemState.quickSettingsSubmenu === "" && SystemState.brightness > 0
                    onMoved: function(ratio) { SystemState.setBrightness(ratio * 100) }
                }

                Text {
                    Layout.preferredWidth: 32
                    horizontalAlignment: Text.AlignRight
                    text: SystemState.brightness + "%"
                    color: MusicState.m3OnSurfaceVariant
                    font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.SemiBold
                }
            }

            // 3.5 Caelestia Quick Mode Chips: Game Mode & Keep Awake
            RowLayout {
                visible: ShellConfig.hasQsItem("modes")
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: SystemState.gameMode ? MusicState.shapeMd : 18
                    color: SystemState.gameMode ? MusicState.m3TertiaryContainer : MusicState.m3SurfaceContainerHigh
                    Behavior on radius { M3Anim { duration: 220 } }
                    Behavior on color  { ColorAnimation  { duration: 160 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        SysIcon { name: "apps"; size: 14; color: SystemState.gameMode ? MusicState.m3OnTertiaryContainer : MusicState.m3OnSurface }
                        Text {
                            text: SystemState.gameMode ? "Игровой: Вкл" : "Игровой режим"
                            color: SystemState.gameMode ? MusicState.m3OnTertiaryContainer : MusicState.m3OnSurface
                            font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: SystemState.toggleGameMode() }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: SystemState.keepAwake ? MusicState.shapeMd : 18
                    color: SystemState.keepAwake ? MusicState.m3TertiaryContainer : MusicState.m3SurfaceContainerHigh
                    Behavior on radius { M3Anim { duration: 220 } }
                    Behavior on color  { ColorAnimation  { duration: 160 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        SysIcon { name: "brightness"; size: 14; color: SystemState.keepAwake ? MusicState.m3OnTertiaryContainer : MusicState.m3OnSurface }
                        Text {
                            text: SystemState.keepAwake ? "Экран: Не спать" : "Не засыпать"
                            color: SystemState.keepAwake ? MusicState.m3OnTertiaryContainer : MusicState.m3OnSurface
                            font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: SystemState.toggleKeepAwake() }
                }
            }

            // 4. Bottom Action Row: Screenshot + Clipboard + Power Controls
            RowLayout {
                visible: ShellConfig.hasQsItem("actions")
                Layout.fillWidth: true
                spacing: 6

                // Screenshot Button
                Rectangle {
                    Layout.preferredHeight: 34
                    Layout.preferredWidth: shotRow.implicitWidth + 18
                    radius: 17
                    color: shotMa.containsMouse ? MusicState.m3PrimaryContainer : MusicState.m3SurfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 160 } }
                    RowLayout {
                        id: shotRow
                        anchors.centerIn: parent
                        spacing: 5
                        SysIcon { name: "screenshot"; size: 14; color: shotMa.containsMouse ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface }
                        Text { text: "Снимок"; color: shotMa.containsMouse ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold }
                    }
                    MouseArea { id: shotMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ScreenshotState.open("region") }
                }

                // Clipboard Button
                Rectangle {
                    Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 17
                    color: clipMa.containsMouse ? MusicState.m3PrimaryContainer : MusicState.m3SurfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 160 } }
                    SysIcon { anchors.centerIn: parent; name: "clipboard"; size: 15; color: clipMa.containsMouse ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface }
                    MouseArea { id: clipMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ClipboardState.toggle() }
                }

                // Shell Settings Button
                Rectangle {
                    Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 17
                    color: cfgMa.containsMouse ? MusicState.m3PrimaryContainer : MusicState.m3SurfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 160 } }
                    SysIcon { anchors.centerIn: parent; name: "settings"; size: 15; color: cfgMa.containsMouse ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface }
                    MouseArea { id: cfgMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ShellConfig.openSettings() }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 17
                    color: lockMa.containsMouse ? MusicState.m3SecondaryContainer : MusicState.m3SurfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 150 } }
                    SysIcon { anchors.centerIn: parent; name: "lock"; size: 15; color: lockMa.containsMouse ? MusicState.m3OnSecondaryContainer : MusicState.m3OnSurface }
                    MouseArea { id: lockMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: SystemState.lockScreen() }
                }
                Rectangle {
                    Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 17
                    color: suspMa.containsMouse ? MusicState.m3SecondaryContainer : MusicState.m3SurfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 150 } }
                    SysIcon { anchors.centerIn: parent; name: "moon"; size: 15; color: suspMa.containsMouse ? MusicState.m3OnSecondaryContainer : MusicState.m3OnSurface }
                    MouseArea { id: suspMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: SystemState.suspendSystem() }
                }
                Rectangle {
                    Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 17
                    color: rebMa.containsMouse ? MusicState.m3ErrorContainer : MusicState.m3SurfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 150 } }
                    SysIcon { anchors.centerIn: parent; name: "reboot"; size: 15; color: rebMa.containsMouse ? MusicState.m3OnErrorContainer : MusicState.m3OnSurface }
                    MouseArea { id: rebMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: SystemState.rebootSystem() }
                }
                Rectangle {
                    Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 17
                    color: pwrMa.containsMouse ? MusicState.m3ErrorContainer : MusicState.m3SurfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 150 } }
                    SysIcon { anchors.centerIn: parent; name: "power"; size: 15; color: pwrMa.containsMouse ? MusicState.m3OnErrorContainer : MusicState.m3Error }
                    MouseArea { id: pwrMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: SystemState.powerOffSystem() }
                }
            }
        }

        // =====================================================================
        // SUBMENU VIEW (Wi-Fi Networks / Bluetooth Devices / Audio Outputs)
        // =====================================================================
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12
            visible: SystemState.quickSettingsSubmenu !== ""

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 16
                    color: backMa.containsMouse ? MusicState.m3SurfaceContainerHighest : MusicState.m3SurfaceContainerHigh
                    SysIcon { anchors.centerIn: parent; name: "back"; size: 15; color: MusicState.m3OnSurface }
                    MouseArea { id: backMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { SystemState.quickSettingsSubmenu = ""; SystemState.cancelWifiPassword() } }
                }

                Text {
                    Layout.fillWidth: true
                    text: SystemState.quickSettingsSubmenu === "wifi"
                        ? "Сети Wi-Fi"
                        : (SystemState.quickSettingsSubmenu === "bt" ? "Устройства Bluetooth" : (SystemState.quickSettingsSubmenu === "edit" ? "Элементы управления" : "Вывод звука"))
                    color: MusicState.m3OnSurface
                    font.family: MusicState.fontUi; font.pixelSize: 14; font.weight: Font.Bold
                }

                Rectangle {
                    visible: SystemState.quickSettingsSubmenu !== "edit"
                    Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 16
                    color: refMa.containsMouse ? MusicState.m3SurfaceContainerHighest : MusicState.m3SurfaceContainerHigh
                    SysIcon { anchors.centerIn: parent; name: "refresh"; size: 15; color: MusicState.m3OnSurface }
                    MouseArea {
                        id: refMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { if (SystemState.quickSettingsSubmenu === "wifi") SystemState.refreshWifiList(true); else SystemState.openSubmenu(SystemState.quickSettingsSubmenu) }
                    }
                }
            }

            // Wi-Fi Status / Inline Password Bar
            ColumnLayout {
                visible: SystemState.quickSettingsSubmenu === "wifi" && (SystemState.wifiPasswordTarget !== "" || SystemState.wifiStatusMsg !== "")
                Layout.fillWidth: true
                spacing: 6

                Text {
                    visible: SystemState.wifiStatusMsg !== ""
                    Layout.fillWidth: true
                    text: SystemState.wifiStatusMsg
                    color: MusicState.m3Primary
                    font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.SemiBold
                    elide: Text.ElideRight
                }

                RowLayout {
                    visible: SystemState.wifiPasswordTarget !== ""
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        radius: 18
                        color: MusicState.m3SurfaceContainerHigh
                        border.width: 1
                        border.color: MusicState.m3Primary

                        TextInput {
                            id: wifiPwInput
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            verticalAlignment: Text.AlignVCenter
                            echoMode: TextInput.Password
                            color: MusicState.m3OnSurface
                            font.family: MusicState.fontUi; font.pixelSize: 12
                            onAccepted: {
                                if (text.length > 0) {
                                    SystemState.connectWifi(SystemState.wifiPasswordTarget, text, "wpa", false)
                                    text = ""
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: wifiPwInput.text.length === 0
                                text: "Пароль для " + SystemState.wifiPasswordTarget
                                color: MusicState.m3OnSurfaceVariant
                                opacity: 0.7
                                font.family: MusicState.fontUi; font.pixelSize: 11
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 58; Layout.preferredHeight: 36; radius: 18
                        color: MusicState.m3Primary
                        Text { anchors.centerIn: parent; text: "OK"; color: MusicState.m3OnPrimary; font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (wifiPwInput.text.length > 0) {
                                    SystemState.connectWifi(SystemState.wifiPasswordTarget, wifiPwInput.text, "wpa", false)
                                    wifiPwInput.text = ""
                                }
                            }
                        }
                    }
                }
            }

            // Wi-Fi List
            ListView {
                visible: SystemState.quickSettingsSubmenu === "wifi"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: SystemState.wifiNetworks

                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view ? ListView.view.width : 320
                    height: 44
                    radius: 14
                    color: modelData.inUse ? MusicState.m3PrimaryContainer : (wItemMa.containsMouse ? MusicState.m3SurfaceContainerHighest : MusicState.m3SurfaceContainerHigh)

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                        SysIcon { name: "wifi"; size: 16; color: modelData.inUse ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.ssid
                            color: modelData.inUse ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface
                            font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: modelData.inUse ? Font.Bold : Font.Medium
                            elide: Text.ElideRight
                        }
                        SysIcon {
                            visible: (modelData.security || "") !== "" && !modelData.inUse
                            name: "lock"
                            size: 12
                            color: MusicState.m3OnSurfaceVariant
                        }
                        Text {
                            text: modelData.inUse ? "Подкл." : (modelData.signal + "%")
                            color: modelData.inUse ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurfaceVariant
                            font.family: MusicState.fontUi; font.pixelSize: 11
                        }
                    }

                    MouseArea {
                        id: wItemMa
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.inUse) return
                            SystemState.connectWifi(modelData.ssid, "", modelData.security, modelData.saved)
                            if (SystemState.wifiPasswordTarget !== "") wifiPwInput.forceActiveFocus()
                        }
                    }
                }
            }

            // Bluetooth List
            ListView {
                visible: SystemState.quickSettingsSubmenu === "bt"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: SystemState.btDevices

                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view ? ListView.view.width : 320
                    height: 44
                    radius: 14
                    color: modelData.connected ? MusicState.m3PrimaryContainer : (bItemMa.containsMouse ? MusicState.m3SurfaceContainerHighest : MusicState.m3SurfaceContainerHigh)

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
                        SysIcon { name: "bluetooth"; size: 16; color: modelData.connected ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.name
                            color: modelData.connected ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface
                            font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: modelData.connected ? Font.Bold : Font.Medium
                            elide: Text.ElideRight
                        }
                        Text {
                            text: modelData.connected ? "Подкл." : "Подключить"
                            color: modelData.connected ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurfaceVariant
                            font.family: MusicState.fontUi; font.pixelSize: 10
                        }
                    }

                    MouseArea {
                        id: bItemMa
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: SystemState.toggleBtDevice(modelData.mac, modelData.connected)
                    }
                }
            }

            // Audio Sinks List
            ListView {
                visible: SystemState.quickSettingsSubmenu === "audio"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: SystemState.audioSinks

                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view ? ListView.view.width : 320
                    height: 44
                    radius: 14
                    color: modelData.active ? MusicState.m3PrimaryContainer : (aItemMa.containsMouse ? MusicState.m3SurfaceContainerHighest : MusicState.m3SurfaceContainerHigh)

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
                        SysIcon { name: "audio_out"; size: 16; color: modelData.active ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.desc
                            color: modelData.active ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface
                            font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: modelData.active ? Font.Bold : Font.Medium
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: aItemMa
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: SystemState.setAudioSink(modelData.id)
                    }
                }
            }

            // Edit Submenu: Full Constructor (Add/Remove, 1x/2x Stretch, Menu & Pill Sizing)
            Flickable {
                visible: SystemState.quickSettingsSubmenu === "edit"
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: editSubCol.implicitHeight + 16
                clip: true

                ColumnLayout {
                    id: editSubCol
                    width: parent.width
                    spacing: 10

                    Text {
                        text: "Плитки (вкл/выкл и ширина 1× / 2×)"
                        color: MusicState.m3OnSurfaceVariant
                        font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold
                    }

                    Repeater {
                        model: [
                            { id: "wifi",         label: "Wi-Fi" },
                            { id: "bt",           label: "Bluetooth" },
                            { id: "nightLight",   label: "Ночной свет" },
                            { id: "powerProfile", label: "Питание / DND" }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool active: ShellConfig.hasQsItem(modelData.id)
                            readonly property bool wide: ShellConfig.isQsWide(modelData.id)
                            Layout.fillWidth: true
                            Layout.preferredHeight: 38
                            radius: 14
                            color: MusicState.m3SurfaceContainerHigh

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12; anchors.rightMargin: 8
                                spacing: 8

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.label
                                    color: active ? MusicState.m3OnSurface : MusicState.m3OnSurfaceVariant
                                    opacity: active ? 1.0 : 0.6
                                    font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.SemiBold
                                }

                                Rectangle {
                                    visible: active
                                    Layout.preferredWidth: 44; Layout.preferredHeight: 24; radius: 12
                                    color: wide ? MusicState.m3Primary : MusicState.m3SurfaceContainer
                                    Text {
                                        anchors.centerIn: parent
                                        text: wide ? "2×" : "1×"
                                        color: wide ? MusicState.m3OnPrimary : MusicState.m3OnSurface
                                        font.family: MusicState.fontUi; font.pixelSize: 10; font.weight: Font.Bold
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: ShellConfig.toggleQsWide(modelData.id)
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 54; Layout.preferredHeight: 24; radius: 12
                                    color: active ? MusicState.m3PrimaryContainer : MusicState.m3SurfaceContainer
                                    Text {
                                        anchors.centerIn: parent
                                        text: active ? "Вкл" : "Выкл"
                                        color: active ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurfaceVariant
                                        font.family: MusicState.fontUi; font.pixelSize: 10; font.weight: Font.Bold
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: ShellConfig.toggleQsItem(modelData.id)
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        Layout.topMargin: 2
                        text: "Дополнительные блоки меню"
                        color: MusicState.m3OnSurfaceVariant
                        font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: [
                                { id: "volume",     label: "Громкость" },
                                { id: "brightness", label: "Яркость" },
                                { id: "modes",      label: "Игровой / Не спать" },
                                { id: "actions",    label: "Нижняя панель" }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool active: ShellConfig.hasQsItem(modelData.id)
                                height: 30; width: blkTxt.implicitWidth + 20; radius: 15
                                color: active ? MusicState.m3PrimaryContainer : MusicState.m3SurfaceContainerHigh
                                Text {
                                    id: blkTxt; anchors.centerIn: parent
                                    text: (active ? "✓ " : "+ ") + modelData.label
                                    color: active ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface
                                    font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: active ? Font.Bold : Font.Medium
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ShellConfig.toggleQsItem(modelData.id) }
                            }
                        }
                    }

                    Text {
                        Layout.topMargin: 4
                        text: "Увеличение и удлинение меню"
                        color: MusicState.m3OnSurfaceVariant
                        font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold
                    }

                    Repeater {
                        model: [
                            { key: "qsWidth",      label: "Ширина меню",    val: ShellConfig.qsWidth,      step: 20, minV: 300, maxV: 460 },
                            { key: "qsTileHeight", label: "Высота плиток",  val: ShellConfig.qsTileHeight, step: 6,  minV: 46,  maxV: 82  },
                            { key: "qsSpacing",    label: "Отступы блоков", val: ShellConfig.qsSpacing,    step: 2,  minV: 6,   maxV: 20  }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true; Layout.preferredHeight: 38; radius: 14
                            color: MusicState.m3SurfaceContainerHigh
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; spacing: 8
                                Text { Layout.fillWidth: true; text: modelData.label; color: MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 12 }
                                Rectangle {
                                    Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 13
                                    color: MusicState.m3SurfaceContainer
                                    Text { anchors.centerIn: parent; text: "−"; color: MusicState.m3OnSurface; font.pixelSize: 14; font.weight: Font.Bold }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            ShellConfig[modelData.key] = Math.max(modelData.minV, ShellConfig[modelData.key] - modelData.step)
                                            ShellConfig.save()
                                        }
                                    }
                                }
                                Text {
                                    Layout.preferredWidth: 38; horizontalAlignment: Text.AlignHCenter
                                    text: modelData.val + "px"
                                    color: MusicState.m3Primary
                                    font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold
                                }
                                Rectangle {
                                    Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 13
                                    color: MusicState.m3SurfaceContainer
                                    Text { anchors.centerIn: parent; text: "+"; color: MusicState.m3OnSurface; font.pixelSize: 14; font.weight: Font.Bold }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            ShellConfig[modelData.key] = Math.min(modelData.maxV, ShellConfig[modelData.key] + modelData.step)
                                            ShellConfig.save()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        Layout.topMargin: 4
                        text: "Пилюля на верхней панели"
                        color: MusicState.m3OnSurfaceVariant
                        font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: [
                                { id: "wifi",       label: "Wi-Fi" },
                                { id: "bt",         label: "Bluetooth" },
                                { id: "volume",     label: "Звук" },
                                { id: "battery",    label: "Батарея" },
                                { id: "nightLight", label: "Ночной свет" },
                                { id: "gameMode",   label: "Игровой" }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool active: ShellConfig.hasPillItem(modelData.id)
                                height: 30; width: pEdTxt.implicitWidth + 20; radius: 15
                                color: active ? MusicState.m3PrimaryContainer : MusicState.m3SurfaceContainerHigh
                                Text {
                                    id: pEdTxt; anchors.centerIn: parent
                                    text: (active ? "✓ " : "+ ") + modelData.label
                                    color: active ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface
                                    font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: active ? Font.Bold : Font.Medium
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ShellConfig.togglePillItem(modelData.id) }
                            }
                        }
                    }

                    Repeater {
                        model: [
                            { key: "pillIconSize", label: "Размер значков",   val: ShellConfig.pillIconSize, step: 1, minV: 13, maxV: 22 },
                            { key: "pillPadding",  label: "Удлинение пилюли", val: ShellConfig.pillPadding,  step: 4, minV: 16, maxV: 48 },
                            { key: "pillSpacing",  label: "Интервал значков", val: ShellConfig.pillSpacing,  step: 2, minV: 6,  maxV: 20 }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true; Layout.preferredHeight: 38; radius: 14
                            color: MusicState.m3SurfaceContainerHigh
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; spacing: 8
                                Text { Layout.fillWidth: true; text: modelData.label; color: MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 12 }
                                Rectangle {
                                    Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 13
                                    color: MusicState.m3SurfaceContainer
                                    Text { anchors.centerIn: parent; text: "−"; color: MusicState.m3OnSurface; font.pixelSize: 14; font.weight: Font.Bold }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            ShellConfig[modelData.key] = Math.max(modelData.minV, ShellConfig[modelData.key] - modelData.step)
                                            ShellConfig.save()
                                        }
                                    }
                                }
                                Text {
                                    Layout.preferredWidth: 38; horizontalAlignment: Text.AlignHCenter
                                    text: modelData.val + "px"
                                    color: MusicState.m3Primary
                                    font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold
                                }
                                Rectangle {
                                    Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 13
                                    color: MusicState.m3SurfaceContainer
                                    Text { anchors.centerIn: parent; text: "+"; color: MusicState.m3OnSurface; font.pixelSize: 14; font.weight: Font.Bold }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            ShellConfig[modelData.key] = Math.min(modelData.maxV, ShellConfig[modelData.key] + modelData.step)
                                            ShellConfig.save()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        Layout.preferredHeight: 36
                        radius: 18
                        color: MusicState.m3SurfaceContainerHigh
                        Text { anchors.centerIn: parent; text: "Сбросить размеры и элементы"; color: MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.SemiBold }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ShellConfig.resetQsLayout() }
                    }
                }
            }
        }
    }
}
