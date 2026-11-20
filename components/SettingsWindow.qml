import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../services"

/**
 * Full Material You Shell Settings Window (4 tabs):
 * - Внешний вид (шрифт, акцент, шейпы лаунчера и уведомлений, формат часов)
 * - Рабочий стол (перенос виджетов, видимость часов/плеера, видео-клипы и автопауза)
 * - Панели и Островок (док, автозакрытие островка, погода, OSD, время тоста)
 * - Система и клавиши (шпаргалка биндов, перезагрузка шелла, очистка буфера)
 */
PanelWindow {
    id: settingsWin

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "arushell-settings"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    property int tabIndex: 0

    Item {
        anchors.fill: parent
        focus: true
        Component.onCompleted: forceActiveFocus()
        Keys.onEscapePressed: ShellConfig.settingsOpen = false

        // Subtle dimmed scrim
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.42)
            MouseArea {
                anchors.fill: parent
                onClicked: ShellConfig.settingsOpen = false
            }
        }

        // Main Floating Material You Settings Card
        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 720
            height: 520
            radius: 30
            color: MusicState.m3SurfaceContainer
            clip: true

            MouseArea { anchors.fill: parent }

            RowLayout {
                anchors.fill: parent
                spacing: 0

                // Left Navigation Sidebar
                Rectangle {
                    Layout.preferredWidth: 206
                    Layout.fillHeight: true
                    color: MusicState.m3SurfaceContainerHigh

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.bottomMargin: 10
                            spacing: 10

                            Item {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                M3Shape {
                                    anchors.fill: parent
                                    shape: "cookie6"
                                    fillColor: MusicState.m3PrimaryContainer
                                }
                                SysIcon {
                                    anchors.centerIn: parent
                                    name: "settings"
                                    size: 16
                                    color: MusicState.m3OnPrimaryContainer
                                }
                            }

                            Text {
                                text: "Настройки"
                                color: MusicState.m3OnSurface
                                font.family: MusicState.fontUi
                                font.pixelSize: 16
                                font.weight: Font.Bold
                            }
                        }

                        Repeater {
                            model: [
                                { icon: "palette",  label: "Внешний вид" },
                                { icon: "move",     label: "Рабочий стол" },
                                { icon: "sliders",  label: "Панели и остров" },
                                { icon: "keyboard", label: "Система и бинды" }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                readonly property bool isSel: settingsWin.tabIndex === index

                                Layout.fillWidth: true
                                Layout.preferredHeight: 42
                                radius: 21
                                color: isSel ? MusicState.m3PrimaryContainer : (navMa.containsMouse ? MusicState.m3SurfaceContainerHighest : "transparent")
                                Behavior on color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    SysIcon {
                                        name: modelData.icon
                                        size: 16
                                        color: isSel ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurfaceVariant
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.label
                                        color: isSel ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface
                                        font.family: MusicState.fontUi
                                        font.pixelSize: 12
                                        font.weight: isSel ? Font.Bold : Font.Medium
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: navMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: settingsWin.tabIndex = index
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        // Close button at bottom of sidebar
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 38
                            radius: 19
                            color: clMa.containsMouse ? MusicState.m3SurfaceContainerHighest : MusicState.m3SurfaceContainer

                            Text {
                                anchors.centerIn: parent
                                text: "Закрыть"
                                color: MusicState.m3OnSurface
                                font.family: MusicState.fontUi
                                font.pixelSize: 12
                                font.weight: Font.SemiBold
                            }

                            MouseArea {
                                id: clMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ShellConfig.settingsOpen = false
                            }
                        }
                    }
                }

                // Right Content Area
                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: rightCol.implicitHeight + 44
                    clip: true

                    ColumnLayout {
                        id: rightCol
                        width: parent.width - 44
                        x: 22
                        y: 22
                        spacing: 14

                        // =====================================================
                        // TAB 0: APPEARANCE
                        // =====================================================
                        ColumnLayout {
                            visible: settingsWin.tabIndex === 0
                            Layout.fillWidth: true
                            spacing: 14

                            Text {
                                text: "Внешний вид и шейпы"
                                color: MusicState.m3OnSurface
                                font.family: MusicState.fontUi; font.pixelSize: 18; font.weight: Font.Bold
                            }

                            // Font selector
                            Text { text: "Шрифт интерфейса"; color: MusicState.m3OnSurfaceVariant; font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.SemiBold }
                            Flow {
                                Layout.fillWidth: true
                                spacing: 8
                                Repeater {
                                    model: ["Google Sans", "Inter", "Roboto", "JetBrains Mono"]
                                    delegate: Rectangle {
                                        required property string modelData
                                        readonly property bool sel: ShellConfig.fontFamily === modelData
                                        height: 34; width: fTxt.implicitWidth + 24; radius: 17
                                        color: sel ? MusicState.m3PrimaryContainer : MusicState.m3SurfaceContainerHigh
                                        Text {
                                            id: fTxt; anchors.centerIn: parent; text: modelData
                                            color: sel ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface
                                            font.family: modelData; font.pixelSize: 12; font.weight: sel ? Font.Bold : Font.Medium
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: { ShellConfig.fontFamily = modelData; ShellConfig.save() }
                                        }
                                    }
                                }
                            }

                            // Accent Color
                            Text { text: "Акцентный цвет Material You"; color: MusicState.m3OnSurfaceVariant; font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.SemiBold }
                            RowLayout {
                                spacing: 10
                                Rectangle {
                                    height: 34; width: autoColTxt.implicitWidth + 22; radius: 17
                                    color: ShellConfig.accentOverride === "" ? MusicState.m3PrimaryContainer : MusicState.m3SurfaceContainerHigh
                                    Text {
                                        id: autoColTxt; anchors.centerIn: parent; text: "Авто (из обложки)"
                                        color: ShellConfig.accentOverride === "" ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface
                                        font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: { ShellConfig.accentOverride = ""; ShellConfig.save() }
                                    }
                                }
                                Repeater {
                                    model: ["#D0BCFF", "#80DAAD", "#FFB787", "#8ECAE6", "#FFB4C6"]
                                    delegate: Rectangle {
                                        required property string modelData
                                        width: 30; height: 30; radius: 15
                                        color: modelData
                                        border.width: ShellConfig.accentOverride === modelData ? 3 : 0
                                        border.color: "#FFFFFF"
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: { ShellConfig.accentOverride = modelData; ShellConfig.save() }
                                        }
                                    }
                                }
                            }

                            // Launcher Shape Picker
                            Text { text: "Шейп кнопки меню приложений"; color: MusicState.m3OnSurfaceVariant; font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.SemiBold }
                            RowLayout {
                                spacing: 10
                                Repeater {
                                    model: [
                                        { id: "ghost",    label: "Ghost" },
                                        { id: "clover4",  label: "Клевер" },
                                        { id: "cookie6",  label: "Печенька" },
                                        { id: "gem",      label: "Ромб" },
                                        { id: "squircle", label: "Сквиркл" }
                                    ]
                                    delegate: Rectangle {
                                        required property var modelData
                                        readonly property bool sel: ShellConfig.launcherShape === modelData.id
                                        height: 36; width: lShRow.implicitWidth + 20; radius: 18
                                        color: sel ? MusicState.m3PrimaryContainer : MusicState.m3SurfaceContainerHigh
                                        RowLayout {
                                            id: lShRow; anchors.centerIn: parent; spacing: 6
                                            M3Shape { Layout.preferredWidth: 18; Layout.preferredHeight: 18; shape: modelData.id; fillColor: sel ? MusicState.m3OnPrimaryContainer : MusicState.m3Primary }
                                            Text { text: modelData.label; color: sel ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.SemiBold }
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: { ShellConfig.launcherShape = modelData.id; ShellConfig.save() }
                                        }
                                    }
                                }
                            }

                            // Notification Bell Shape Picker
                            Text { text: "Шейп кнопки уведомлений"; color: MusicState.m3OnSurfaceVariant; font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.SemiBold }
                            RowLayout {
                                spacing: 10
                                Repeater {
                                    model: [
                                        { id: "gem",      label: "Ромб" },
                                        { id: "cookie6",  label: "Печенька" },
                                        { id: "ghost",    label: "Ghost" },
                                        { id: "squircle", label: "Сквиркл" }
                                    ]
                                    delegate: Rectangle {
                                        required property var modelData
                                        readonly property bool sel: ShellConfig.notifShape === modelData.id
                                        height: 36; width: nShRow.implicitWidth + 20; radius: 18
                                        color: sel ? MusicState.m3PrimaryContainer : MusicState.m3SurfaceContainerHigh
                                        RowLayout {
                                            id: nShRow; anchors.centerIn: parent; spacing: 6
                                            M3Shape { Layout.preferredWidth: 18; Layout.preferredHeight: 18; shape: modelData.id; fillColor: sel ? MusicState.m3OnPrimaryContainer : MusicState.m3Primary }
                                            Text { text: modelData.label; color: sel ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.SemiBold }
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: { ShellConfig.notifShape = modelData.id; ShellConfig.save() }
                                        }
                                    }
                                }
                            }

                            // 24h Clock Toggle
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 50; radius: 18; color: MusicState.m3SurfaceContainerHigh
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                                    Text { Layout.fillWidth: true; text: "24-часовой формат часов"; color: MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 13; font.weight: Font.Medium }
                                    Rectangle {
                                        Layout.preferredWidth: 46; Layout.preferredHeight: 26; radius: 13
                                        color: ShellConfig.clock24h ? MusicState.m3Primary : MusicState.m3SurfaceContainer
                                        Rectangle { width: 20; height: 20; radius: 10; y: 3; x: ShellConfig.clock24h ? 23 : 3; color: ShellConfig.clock24h ? MusicState.m3OnPrimary : MusicState.m3OnSurfaceVariant; Behavior on x { M3Anim { duration: 220 } } }
                                    }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ShellConfig.clock24h = !ShellConfig.clock24h; ShellConfig.save() } }
                            }
                        }

                        // =====================================================
                        // TAB 1: DESKTOP & WIDGETS
                        // =====================================================
                        ColumnLayout {
                            visible: settingsWin.tabIndex === 1
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                text: "Рабочий стол и виджеты"
                                color: MusicState.m3OnSurface
                                font.family: MusicState.fontUi; font.pixelSize: 18; font.weight: Font.Bold
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Rectangle {
                                    Layout.fillWidth: true; Layout.preferredHeight: 46; radius: 23
                                    color: MusicState.m3Primary
                                    Text { anchors.centerIn: parent; text: "Перемещать виджеты на столе"; color: MusicState.m3OnPrimary; font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.Bold }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            ShellConfig.settingsOpen = false
                                            ShellConfig.editMode = true
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 160; Layout.preferredHeight: 46; radius: 23
                                    color: MusicState.m3SurfaceContainerHigh
                                    Text { anchors.centerIn: parent; text: "Сбросить позиции"; color: MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.SemiBold }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: ShellConfig.resetWidgetPositions()
                                    }
                                }
                            }

                            Repeater {
                                model: [
                                    { key: "clockVisible",          label: "Показывать часы на рабочем столе",          val: ShellConfig.clockVisible },
                                    { key: "stageVisible",          label: "Показывать обложку и текст песни",          val: ShellConfig.stageVisible },
                                    { key: "videoWallpaperEnabled", label: "Живые музыкальные клипы на фоне",           val: ShellConfig.videoWallpaperEnabled },
                                    { key: "videoEmptyDesktopOnly", label: "Пауза клипа при открытии приложений",       val: ShellConfig.videoEmptyDesktopOnly }
                                ]
                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true; Layout.preferredHeight: 50; radius: 18; color: MusicState.m3SurfaceContainerHigh
                                    RowLayout {
                                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                                        Text { Layout.fillWidth: true; text: modelData.label; color: MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 13; font.weight: Font.Medium }
                                        Rectangle {
                                            Layout.preferredWidth: 46; Layout.preferredHeight: 26; radius: 13
                                            color: modelData.val ? MusicState.m3Primary : MusicState.m3SurfaceContainer
                                            Rectangle { width: 20; height: 20; radius: 10; y: 3; x: modelData.val ? 23 : 3; color: modelData.val ? MusicState.m3OnPrimary : MusicState.m3OnSurfaceVariant; Behavior on x { M3Anim { duration: 220 } } }
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            ShellConfig[modelData.key] = !ShellConfig[modelData.key]
                                            ShellConfig.save()
                                        }
                                    }
                                }
                            }
                        }

                        // =====================================================
                        // TAB 2: PANELS & DYNAMIC ISLAND
                        // =====================================================
                        ColumnLayout {
                            visible: settingsWin.tabIndex === 2
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                text: "Панели, Док и Dynamic Island"
                                color: MusicState.m3OnSurface
                                font.family: MusicState.fontUi; font.pixelSize: 18; font.weight: Font.Bold
                            }

                            Repeater {
                                model: [
                                    { key: "dockPinned",          label: "Всегда показывать нижний док (закрепить)",         val: ShellConfig.dockPinned },
                                    { key: "islandAutoClose",     label: "Автозакрытие Dynamic Island при уходе курсора",     val: ShellConfig.islandAutoClose },
                                    { key: "showWeatherInIsland", label: "Показывать погоду в компактной пилюле островка",    val: ShellConfig.showWeatherInIsland },
                                    { key: "osdEnabled",          label: "Волнистый OSD при изменении звука и яркости",       val: ShellConfig.osdEnabled }
                                ]
                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true; Layout.preferredHeight: 50; radius: 18; color: MusicState.m3SurfaceContainerHigh
                                    RowLayout {
                                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                                        Text { Layout.fillWidth: true; text: modelData.label; color: MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 13; font.weight: Font.Medium }
                                        Rectangle {
                                            Layout.preferredWidth: 46; Layout.preferredHeight: 26; radius: 13
                                            color: modelData.val ? MusicState.m3Primary : MusicState.m3SurfaceContainer
                                            Rectangle { width: 20; height: 20; radius: 10; y: 3; x: modelData.val ? 23 : 3; color: modelData.val ? MusicState.m3OnPrimary : MusicState.m3OnSurfaceVariant; Behavior on x { M3Anim { duration: 220 } } }
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            ShellConfig[modelData.key] = !ShellConfig[modelData.key]
                                            ShellConfig.save()
                                        }
                                    }
                                }
                            }

                            // Notification toast duration wavy slider
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 74; radius: 18; color: MusicState.m3SurfaceContainerHigh
                                ColumnLayout {
                                    anchors.fill: parent; anchors.margins: 14; spacing: 6
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { Layout.fillWidth: true; text: "Длительность показа уведомления в островке"; color: MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.Medium }
                                        Text { text: (ShellConfig.toastDurationMs / 1000).toFixed(1) + " с"; color: MusicState.m3Primary; font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.Bold }
                                    }
                                    M3WavyBar {
                                        Layout.fillWidth: true; Layout.preferredHeight: 22
                                        value: (ShellConfig.toastDurationMs - 1500) / 5500.0
                                        activeColor: MusicState.m3Primary
                                        trackColor: MusicState.m3SurfaceContainer
                                        lineWidth: 5.5; amplitude: 3.4
                                        animated: settingsWin.tabIndex === 2
                                        onMoved: function(r) {
                                            ShellConfig.toastDurationMs = Math.round((1500 + r * 5500) / 500) * 500
                                            ShellConfig.save()
                                        }
                                    }
                                }
                            }
                        }

                        // =====================================================
                        // TAB 3: SYSTEM & HOTKEYS
                        // =====================================================
                        ColumnLayout {
                            visible: settingsWin.tabIndex === 3
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                text: "Горячие клавиши и система"
                                color: MusicState.m3OnSurface
                                font.family: MusicState.fontUi; font.pixelSize: 18; font.weight: Font.Bold
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: hkCol.implicitHeight + 24
                                radius: 20
                                color: MusicState.m3SurfaceContainerHigh

                                ColumnLayout {
                                    id: hkCol
                                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                                    spacing: 8

                                    Repeater {
                                        model: [
                                            { k: "SUPER",           d: "Открыть меню приложений (App Launcher)" },
                                            { k: "SUPER + V",       d: "Менеджер буфера обмена (cliphist)" },
                                            { k: "SUPER + Shift + S", d: "Скриншотер (область / окно / экран)" },
                                            { k: "Print",           d: "Скриншотер (заморозка экрана)" },
                                            { k: "Shift + Print",   d: "Мгновенный скриншот всего экрана" },
                                            { k: "ПКМ на столе",    d: "Меню управления рабочим столом" }
                                        ]
                                        delegate: RowLayout {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            spacing: 12
                                            Rectangle {
                                                Layout.preferredHeight: 24; Layout.preferredWidth: kTxt.implicitWidth + 16; radius: 12
                                                color: MusicState.m3PrimaryContainer
                                                Text { id: kTxt; anchors.centerIn: parent; text: modelData.k; color: MusicState.m3OnPrimaryContainer; font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold }
                                            }
                                            Text { Layout.fillWidth: true; text: modelData.d; color: MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 12; elide: Text.ElideRight }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Rectangle {
                                    Layout.fillWidth: true; Layout.preferredHeight: 42; radius: 21; color: MusicState.m3PrimaryContainer
                                    Text { anchors.centerIn: parent; text: "Перезагрузить шелл"; color: MusicState.m3OnPrimaryContainer; font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.Bold }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ShellConfig.settingsOpen = false; Quickshell.reload(true) } }
                                }

                                Rectangle {
                                    Layout.fillWidth: true; Layout.preferredHeight: 42; radius: 21; color: MusicState.m3SurfaceContainerHigh
                                    Text { anchors.centerIn: parent; text: "Очистить буфер обмена"; color: MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.SemiBold }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ClipboardState.clearAll() }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
