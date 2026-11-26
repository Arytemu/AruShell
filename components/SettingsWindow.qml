import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../services"

/**
 * Caelestia-inspired Material You Control Center / Settings Window (5 tabs + live search):
 * - Обои и стиль (превью обоев + карусель, Тёмная/Светлая тема, прозрачность панелей, шрифт, акцент, шейп/картинка)
 * - Рабочий стол и музыка (перемещение виджетов, клипы, выбор музыкального клиента MPRIS)
 * - Панели и режимы (док, островок, погода, OSD, Game Mode, Keep Awake)
 * - Система и бинды (шпаргалка клавиш, перезапуск шелла, очистка буфера)
 * - О системе (About AruShell: версия, Hostname, OS, Kernel, WM, Uptime)
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
    property string searchQuery: ""

    readonly property var navTabs: [
        { icon: "palette",  label: "Обои и стиль",       keys: "обои стиль тема темная светлая прозрачность шрифт акцент шейп иконка картинка" },
        { icon: "move",     label: "Стол и музыка",      keys: "рабочий стол виджеты музыка клиент mpris яндекс спотифай клипы видео обложка" },
        { icon: "sliders",  label: "Панели и режимы",    keys: "панель док остров погода osd тост игровой game mode кофеин не засыпать" },
        { icon: "keyboard", label: "Система и бинды",    keys: "бинды клавиши шпаргалка перезапуск буфер обмена" },
        { icon: "volume_high", label: "Визуализатор",    keys: "визуализатор cava эквалайзер плитки столбики ширина высота" },
        { icon: "sliders",  label: "Анимации Hyprland",  keys: "анимации hyprland скорость окна воркспейсы пружина плавные" },
        { icon: "settings", label: "О системе",          keys: "о системе about версия ядро kernel hostname cachyos hyprland" }
    ]

    function jumpToMatchingTab(q) {
        const s = String(q || "").trim().toLowerCase()
        if (!s) return
        for (let i = 0; i < navTabs.length; i++) {
            if (navTabs[i].label.toLowerCase().indexOf(s) !== -1 || navTabs[i].keys.indexOf(s) !== -1) {
                tabIndex = i
                return
            }
        }
    }

    Item {
        anchors.fill: parent
        focus: true
        Component.onCompleted: forceActiveFocus()
        Keys.onEscapePressed: ShellConfig.settingsOpen = false

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
            width: 780
            height: 630
            radius: MusicState.shapeXl
            color: MusicState.m3SurfaceContainer
            border.width: 1
            border.color: MusicState.m3OutlineVariant
            clip: true

            MouseArea { anchors.fill: parent }

            RowLayout {
                anchors.fill: parent
                spacing: 0

                // Left Navigation Drawer (Material 3 two-pane hierarchy)
                Rectangle {
                    Layout.preferredWidth: 224
                    Layout.fillHeight: true
                    color: MusicState.m3SurfaceContainerLow

                    Rectangle {
                        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                        width: 1
                        color: MusicState.m3OutlineVariant
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 6

                        // Search Settings Pill (M3 Search Bar with visible focus outline)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            Layout.bottomMargin: 6
                            radius: 20
                            color: MusicState.m3SurfaceContainerHigh
                            border.width: 1
                            border.color: cfgSearchInput.activeFocus ? MusicState.m3Outline : MusicState.m3OutlineVariant

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 8

                                SysIcon { name: "search"; size: 14; color: MusicState.m3OnSurfaceVariant }

                                TextInput {
                                    id: cfgSearchInput
                                    Layout.fillWidth: true
                                    color: MusicState.m3OnSurface
                                    font.family: MusicState.fontUi; font.pixelSize: 12
                                    onTextEdited: {
                                        settingsWin.searchQuery = text
                                        settingsWin.jumpToMatchingTab(text)
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: cfgSearchInput.text.length === 0
                                        text: "Поиск настроек..."
                                        color: MusicState.m3OnSurfaceVariant
                                        opacity: 0.68
                                        font.family: MusicState.fontUi; font.pixelSize: 12
                                    }
                                }
                            }
                        }

                        Repeater {
                            model: settingsWin.navTabs

                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                readonly property bool isSel: settingsWin.tabIndex === index

                                Layout.fillWidth: true
                                Layout.preferredHeight: 42
                                radius: 21
                                color: isSel ? MusicState.m3SecondaryContainer : (navMa.containsMouse ? MusicState.m3SurfaceContainerHigh : "transparent")
                                Behavior on color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    SysIcon {
                                        name: modelData.icon
                                        size: 16
                                        color: isSel ? MusicState.m3OnSecondaryContainer : MusicState.m3OnSurfaceVariant
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.label
                                        color: isSel ? MusicState.m3OnSecondaryContainer : MusicState.m3OnSurface
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

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 38
                            radius: 19
                            color: clMa.containsMouse ? MusicState.m3SurfaceContainerHighest : MusicState.m3SurfaceContainer

                            Text {
                                anchors.centerIn: parent
                                text: "Закрыть"
                                color: MusicState.m3OnSurface
                                font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.SemiBold
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
                        // TAB 0: WALLPAPER & STYLE (Caelestia style)
                        // =====================================================
                        ColumnLayout {
                            visible: settingsWin.tabIndex === 0
                            Layout.fillWidth: true
                            spacing: 14

                            Text {
                                text: "Обои и стиль"
                                color: MusicState.m3OnSurface
                                font.family: MusicState.fontUi; font.pixelSize: 18; font.weight: Font.Bold
                            }

                            // Wallpaper Preview Banner + Open Carousel Button (like Caelestia 00:55!)
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 132
                                radius: 22
                                color: MusicState.m3SurfaceContainerHigh

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 14

                                    ClippingRectangle {
                                        Layout.preferredWidth: 186
                                        Layout.fillHeight: true
                                        radius: 16
                                        color: MusicState.m3SurfaceContainer

                                        Image {
                                            anchors.fill: parent
                                            source: ShellConfig.wallpaperPath ? ("file://" + ShellConfig.wallpaperPath) : ""
                                            sourceSize: Qt.size(320, 180)
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        spacing: 8

                                        Text {
                                            text: "Текущие обои"
                                            color: MusicState.m3OnSurface
                                            font.family: MusicState.fontUi; font.pixelSize: 14; font.weight: Font.Bold
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: ShellConfig.wallpaperPath
                                                ? ShellConfig.wallpaperPath.split("/").pop()
                                                : "Не выбраны"
                                            color: MusicState.m3OnSurfaceVariant
                                            font.family: MusicState.fontUi; font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }

                                        Item { Layout.fillHeight: true }

                                        Rectangle {
                                            Layout.preferredHeight: 36
                                            Layout.preferredWidth: wpBtnTxt.implicitWidth + 28
                                            radius: 18
                                            color: MusicState.m3Primary
                                            Text {
                                                id: wpBtnTxt; anchors.centerIn: parent
                                                text: "Выбрать обои (Super+W)"
                                                color: MusicState.m3OnPrimary
                                                font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.Bold
                                            }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    ShellConfig.settingsOpen = false
                                                    WallpaperState.toggle()
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Dark / Light Theme Toggle
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 50; radius: 18; color: MusicState.m3SurfaceContainerHigh
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 1
                                        Text { text: "Тёмная тема"; color: MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 13; font.weight: Font.Medium }
                                        Text { text: ShellConfig.darkTheme ? "Material You Dark" : "Material You Light"; color: MusicState.m3OnSurfaceVariant; font.family: MusicState.fontUi; font.pixelSize: 10 }
                                    }
                                    Rectangle {
                                        Layout.preferredWidth: 46; Layout.preferredHeight: 26; radius: 13
                                        color: ShellConfig.darkTheme ? MusicState.m3Primary : MusicState.m3SurfaceContainer
                                        Rectangle { width: 20; height: 20; radius: 10; y: 3; x: ShellConfig.darkTheme ? 23 : 3; color: ShellConfig.darkTheme ? MusicState.m3OnPrimary : MusicState.m3OnSurfaceVariant; Behavior on x { M3Anim { duration: 220 } } }
                                    }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ShellConfig.darkTheme = !ShellConfig.darkTheme; ShellConfig.save() } }
                            }

                            // Panel Transparency Selector
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 54; radius: 18; color: MusicState.m3SurfaceContainerHigh
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 14; spacing: 10
                                    Text { text: "Непрозрачность панелей"; color: MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 13; font.weight: Font.Medium; Layout.fillWidth: true }
                                    Repeater {
                                        model: [0.75, 0.85, 0.92, 1.0]
                                        delegate: Rectangle {
                                            required property real modelData
                                            readonly property bool sel: Math.abs(ShellConfig.panelOpacity - modelData) < 0.04
                                            Layout.preferredHeight: 30; Layout.preferredWidth: 46; radius: 15
                                            color: sel ? MusicState.m3PrimaryContainer : MusicState.m3SurfaceContainer
                                            Text { anchors.centerIn: parent; text: Math.round(modelData * 100) + "%"; color: sel ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ShellConfig.panelOpacity = modelData; ShellConfig.save() } }
                                        }
                                    }
                                }
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
                                        id: autoColTxt; anchors.centerIn: parent; text: "Авто (из обоев)"
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
                                        border.color: MusicState.m3OnSurface
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: { ShellConfig.accentOverride = modelData; ShellConfig.save() }
                                        }
                                    }
                                }
                            }

                            // Launcher Shape & Custom Image Picker
                            Text { text: "Иконка / шейп кнопки меню приложений"; color: MusicState.m3OnSurfaceVariant; font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.SemiBold }
                            Flow {
                                Layout.fillWidth: true
                                spacing: 8
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
                                        readonly property bool sel: ShellConfig.launcherImagePath === "" && ShellConfig.launcherShape === modelData.id
                                        height: 36; width: lShRow.implicitWidth + 20; radius: 18
                                        color: sel ? MusicState.m3PrimaryContainer : MusicState.m3SurfaceContainerHigh
                                        RowLayout {
                                            id: lShRow; anchors.centerIn: parent; spacing: 6
                                            M3Shape { Layout.preferredWidth: 18; Layout.preferredHeight: 18; shape: modelData.id; fillColor: sel ? MusicState.m3OnPrimaryContainer : MusicState.m3Primary }
                                            Text { text: modelData.label; color: sel ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.SemiBold }
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                ShellConfig.launcherImagePath = ""
                                                ShellConfig.launcherShape = modelData.id
                                                ShellConfig.save()
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    readonly property bool sel: ShellConfig.launcherImagePath !== ""
                                    height: 36; width: custImgTxt.implicitWidth + 24; radius: 18
                                    color: sel ? MusicState.m3PrimaryContainer : MusicState.m3SurfaceContainerHigh
                                    Text {
                                        id: custImgTxt; anchors.centerIn: parent
                                        text: sel ? "Своя картинка ✓" : "+ Своя картинка"
                                        color: sel ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface
                                        font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: ShellConfig.browseLauncherImage()
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                visible: ShellConfig.launcherImagePath !== ""

                                Rectangle {
                                    Layout.fillWidth: true; Layout.preferredHeight: 38; radius: 19
                                    color: MusicState.m3SurfaceContainerHigh
                                    TextInput {
                                        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                                        verticalAlignment: Text.AlignVCenter
                                        color: MusicState.m3OnSurface
                                        font.family: MusicState.fontUi; font.pixelSize: 11
                                        text: ShellConfig.launcherImagePath
                                        onAccepted: { ShellConfig.launcherImagePath = text.trim(); ShellConfig.save() }
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 19
                                    color: MusicState.m3SurfaceContainerHigh
                                    Text { anchors.centerIn: parent; text: "✕"; color: MusicState.m3OnSurface; font.pixelSize: 13; font.weight: Font.Bold }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ShellConfig.launcherImagePath = ""; ShellConfig.save() } }
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

                            // Dynamic HUD & Window Borders Toggles
                            Repeater {
                                model: [
                                    { key: "hudFromAlbum",       label: "Цвет HUD из обложки играющего трека",    val: ShellConfig.hudFromAlbum },
                                    { key: "hyprDynamicBorders", label: "Динамическая рамка окон Hyprland под HUD", val: ShellConfig.hyprDynamicBorders }
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
                                        onClicked: { ShellConfig[modelData.key] = !ShellConfig[modelData.key]; ShellConfig.save() }
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
                        // TAB 1: DESKTOP & MUSIC
                        // =====================================================
                        ColumnLayout {
                            visible: settingsWin.tabIndex === 1
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                text: "Рабочий стол и музыка"
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
                                        onClicked: { ShellConfig.settingsOpen = false; ShellConfig.editMode = true }
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 160; Layout.preferredHeight: 46; radius: 23
                                    color: MusicState.m3SurfaceContainerHigh
                                    Text { anchors.centerIn: parent; text: "Сбросить позиции"; color: MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.SemiBold }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ShellConfig.resetWidgetPositions() }
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
                                        onClicked: { ShellConfig[modelData.key] = !ShellConfig[modelData.key]; ShellConfig.save() }
                                    }
                                }
                            }

                            // Music Client (MPRIS) selector
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: 6
                                spacing: 8

                                Text {
                                    text: "Музыкальный клиент (MPRIS)"
                                    color: MusicState.m3OnSurfaceVariant
                                    font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.SemiBold
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: "Авто-режим игнорирует браузеры (Telegram Web и др.) и подключается к нативным и Electron-плеерам. Сейчас в MPRIS: " + MusicState.detectedMprisList
                                    color: MusicState.m3OnSurfaceVariant
                                    opacity: 0.78
                                    font.family: MusicState.fontUi; font.pixelSize: 11
                                    wrapMode: Text.Wrap
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Repeater {
                                        model: [
                                            { id: "auto",    label: "Авто" },
                                            { id: "yandex",  label: "Яндекс Музыка" },
                                            { id: "spotify", label: "Spotify" },
                                            { id: "apple",   label: "Apple Music" },
                                            { id: "ytmusic", label: "YT Music" },
                                            { id: "tidal",   label: "Tidal" },
                                            { id: "deezer",  label: "Deezer" },
                                            { id: "mpd",     label: "MPD / Локальный" },
                                            { id: "custom",  label: "Свой" }
                                        ]
                                        delegate: Rectangle {
                                            required property var modelData
                                            readonly property bool sel: ShellConfig.musicClientMode === modelData.id
                                            height: 34; width: mcTxt.implicitWidth + 22; radius: 17
                                            color: sel ? MusicState.m3PrimaryContainer : MusicState.m3SurfaceContainerHigh
                                            Behavior on color { ColorAnimation { duration: 140 } }

                                            Text {
                                                id: mcTxt; anchors.centerIn: parent; text: modelData.label
                                                color: sel ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface
                                                font.family: MusicState.fontUi; font.pixelSize: 12
                                                font.weight: sel ? Font.Bold : Font.Medium
                                            }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: { ShellConfig.musicClientMode = modelData.id; ShellConfig.save() }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    visible: ShellConfig.musicClientMode === "custom"
                                    Layout.fillWidth: true; Layout.preferredHeight: 44; radius: 22
                                    color: MusicState.m3SurfaceContainerHigh
                                    border.width: customClientInput.activeFocus ? 2 : 1
                                    border.color: customClientInput.activeFocus ? MusicState.m3Primary : MusicState.m3OutlineVariant

                                    TextInput {
                                        id: customClientInput
                                        anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                                        verticalAlignment: Text.AlignVCenter
                                        color: MusicState.m3OnSurface
                                        font.family: MusicState.fontUi; font.pixelSize: 13
                                        text: ShellConfig.musicCustomClient
                                        onTextEdited: { ShellConfig.musicCustomClient = text; ShellConfig.save() }
                                        onAccepted: { ShellConfig.musicCustomClient = text; ShellConfig.save() }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: customClientInput.text.length === 0
                                            text: "Имя клиента MPRIS (напр. amberol, feishin, vlc)"
                                            color: MusicState.m3OnSurfaceVariant
                                            opacity: 0.65
                                            font.family: MusicState.fontUi; font.pixelSize: 12
                                        }
                                    }
                                }
                            }
                        }

                        // =====================================================
                        // TAB 2: PANELS & MODES
                        // =====================================================
                        ColumnLayout {
                            visible: settingsWin.tabIndex === 2
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                text: "Панели, островок и режимы"
                                color: MusicState.m3OnSurface
                                font.family: MusicState.fontUi; font.pixelSize: 18; font.weight: Font.Bold
                            }

                            Repeater {
                                model: [
                                    { key: "dockPinned",          label: "Закрепить нижний док (не скрывать)",             val: ShellConfig.dockPinned },
                                    { key: "islandAutoClose",     label: "Автозакрытие островка при уводе курсора",        val: ShellConfig.islandAutoClose },
                                    { key: "showWeatherInIsland", label: "Показывать погоду в пилюле островка",            val: ShellConfig.showWeatherInIsland },
                                    { key: "osdEnabled",          label: "Всплывающий OSD (звук, яркость, раскладка)",     val: ShellConfig.osdEnabled },
                                    { key: "blurTiledBg",         label: "Размывать фон за тайловыми окнами",             val: ShellConfig.blurTiledBg },
                                    { key: "kittyAutoFont",       label: "Авто-масштаб шрифта Kitty под размер окна",     val: ShellConfig.kittyAutoFont },
                                    { key: "syncSystemTheme",     label: "Синхронизировать акцент с Kitty и GTK3/4",      val: ShellConfig.syncSystemTheme },
                                    { key: "inhibitWhenAudio",    label: "Не блокировать экран при аудио/видео",          val: ShellConfig.inhibitWhenAudio }
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
                                        onClicked: { ShellConfig[modelData.key] = !ShellConfig[modelData.key]; ShellConfig.save() }
                                    }
                                }
                            }
                            // Game Mode Toggle
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 52; radius: 18; color: MusicState.m3SurfaceContainerHigh
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 1
                                        Text { text: "Игровой режим (Game Mode)"; color: MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 13; font.weight: Font.Medium }
                                        Text { text: "Отключает анимации, блюр и тени Hyprland для максимального FPS"; color: MusicState.m3OnSurfaceVariant; font.family: MusicState.fontUi; font.pixelSize: 10 }
                                    }
                                    Rectangle {
                                        Layout.preferredWidth: 46; Layout.preferredHeight: 26; radius: 13
                                        color: SystemState.gameMode ? MusicState.m3Primary : MusicState.m3SurfaceContainer
                                        Rectangle { width: 20; height: 20; radius: 10; y: 3; x: SystemState.gameMode ? 23 : 3; color: SystemState.gameMode ? MusicState.m3OnPrimary : MusicState.m3OnSurfaceVariant; Behavior on x { M3Anim { duration: 220 } } }
                                    }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: SystemState.toggleGameMode() }
                            }

                            // Keep Awake Toggle
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 52; radius: 18; color: MusicState.m3SurfaceContainerHigh
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 1
                                        Text { text: "Не засыпать (Keep Awake)"; color: MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 13; font.weight: Font.Medium }
                                        Text { text: "Приостанавливает автоблокировку hypridle на время просмотра или игр"; color: MusicState.m3OnSurfaceVariant; font.family: MusicState.fontUi; font.pixelSize: 10 }
                                    }
                                    Rectangle {
                                        Layout.preferredWidth: 46; Layout.preferredHeight: 26; radius: 13
                                        color: SystemState.keepAwake ? MusicState.m3Primary : MusicState.m3SurfaceContainer
                                        Rectangle { width: 20; height: 20; radius: 10; y: 3; x: SystemState.keepAwake ? 23 : 3; color: SystemState.keepAwake ? MusicState.m3OnPrimary : MusicState.m3OnSurfaceVariant; Behavior on x { M3Anim { duration: 220 } } }
                                    }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: SystemState.toggleKeepAwake() }
                            }

                            // Toast duration
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 52; radius: 18; color: MusicState.m3SurfaceContainerHigh
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 14; spacing: 10
                                    Text { text: "Длительность тоста уведомления"; color: MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 13; font.weight: Font.Medium; Layout.fillWidth: true }
                                    Repeater {
                                        model: [2000, 3000, 5000]
                                        delegate: Rectangle {
                                            required property int modelData
                                            readonly property bool sel: ShellConfig.toastDurationMs === modelData
                                            Layout.preferredHeight: 30; Layout.preferredWidth: 48; radius: 15
                                            color: sel ? MusicState.m3PrimaryContainer : MusicState.m3SurfaceContainer
                                            Text { anchors.centerIn: parent; text: (modelData / 1000) + "с"; color: sel ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ShellConfig.toastDurationMs = modelData; ShellConfig.save() } }
                                        }
                                    }
                                }
                            }
                        }

                        // =====================================================
                        // TAB 3: SYSTEM & SHORTCUTS
                        // =====================================================
                        ColumnLayout {
                            visible: settingsWin.tabIndex === 3
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                text: "Система и горячие клавиши"
                                color: MusicState.m3OnSurface
                                font.family: MusicState.fontUi; font.pixelSize: 18; font.weight: Font.Bold
                            }

                            Repeater {
                                model: [
                                    { key: "Super",           desc: "Открыть меню приложений (Приложения / Окна / Эмодзи)" },
                                    { key: "Super + W",       desc: "Карусель обоев (стрелки + свои папки)" },
                                    { key: "Super + B",       desc: "3D-глобус веб-поиска с запуском Firefox" },
                                    { key: "Super + L",       desc: "Экран блокировки в стиле Caelestia" },
                                    { key: "Super + V",       desc: "История буфера обмена (cliphist)" },
                                    { key: "Super + Shift + S", desc: "Скриншот области (с лупой и редактором)" },
                                    { key: "Print",           desc: "Скриншот области / Shift+Print — весь экран" }
                                ]
                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true; Layout.preferredHeight: 42; radius: 16; color: MusicState.m3SurfaceContainerHigh
                                    RowLayout {
                                        anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 12
                                        Rectangle {
                                            Layout.preferredHeight: 26; Layout.preferredWidth: kTxt.implicitWidth + 16; radius: 13
                                            color: MusicState.m3PrimaryContainer
                                            Text { id: kTxt; anchors.centerIn: parent; text: modelData.key; color: MusicState.m3OnPrimaryContainer; font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold }
                                        }
                                        Text { Layout.fillWidth: true; text: modelData.desc; color: MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 12; elide: Text.ElideRight }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: 6
                                spacing: 10

                                Rectangle {
                                    Layout.fillWidth: true; Layout.preferredHeight: 44; radius: 22
                                    color: MusicState.m3PrimaryContainer
                                    Text { anchors.centerIn: parent; text: "Перезапустить AruShell"; color: MusicState.m3OnPrimaryContainer; font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.Bold }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: Quickshell.execDetached(["bash", "-c", "systemctl --user restart arushell.service 2>/dev/null || (pkill -9 -x quickshell; sleep 0.25; nohup quickshell -c AruShell >/tmp/arushell.log 2>&1 &)"])
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true; Layout.preferredHeight: 44; radius: 22
                                    color: MusicState.m3SurfaceContainerHigh
                                    Text { anchors.centerIn: parent; text: "Очистить буфер обмена"; color: MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.SemiBold }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ClipboardState.clearAll() }
                                }
                            }
                        }

                        // =====================================================
                        // TAB 4: ABOUT (Caelestia 00:57 style)
                        // =====================================================
                        ColumnLayout {
                            visible: settingsWin.tabIndex === 6
                            Layout.fillWidth: true
                            spacing: 14

                            // Hero Header Card
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 130
                                radius: 24
                                color: MusicState.m3SurfaceContainerHigh

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Item {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 52; height: 52
                                        M3Shape {
                                            anchors.fill: parent
                                            shape: "cookie8"
                                            fillColor: MusicState.m3PrimaryContainer
                                            spin: settingsWin.tabIndex === 6
                                            spinDuration: 20000
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            text: "A"
                                            color: MusicState.m3OnPrimaryContainer
                                            font.family: MusicState.fontUi; font.pixelSize: 22; font.weight: Font.Black
                                        }
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "AruShell"
                                        color: MusicState.m3OnSurface
                                        font.family: MusicState.fontUi; font.pixelSize: 22; font.weight: Font.Black
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "Material 3 Expressive Desktop Shell · Quickshell"
                                        color: MusicState.m3OnSurfaceVariant
                                        font.family: MusicState.fontUi; font.pixelSize: 11
                                    }
                                }
                            }

                            // System Info List Card
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: aboutCol.implicitHeight + 28
                                radius: 22
                                color: MusicState.m3SurfaceContainerHigh

                                ColumnLayout {
                                    id: aboutCol
                                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                                    spacing: 10

                                    Repeater {
                                        model: [
                                            { k: "Версия AruShell", v: "v1.2.5" },
                                            { k: "Пользователь",    v: SystemState.userName || "user" },
                                            { k: "Хост",         v: SystemState.hostName || "linux" },
                                            { k: "Система",      v: SystemState.distroName || "CachyOS" },
                                            { k: "Ядро",         v: SystemState.kernelVer || "—" },
                                            { k: "Композитор",   v: "Hyprland (Wayland)" },
                                            { k: "Аптайм",       v: SystemState.uptimeText || "—" },
                                            { k: "Память",       v: SystemState.ramText || (SystemState.ramPercent + "%") },
                                            { k: "Диск /",       v: SystemState.diskText || (SystemState.diskPercent + "%") }
                                        ]
                                        delegate: RowLayout {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            Text {
                                                Layout.preferredWidth: 130
                                                text: modelData.k
                                                color: MusicState.m3OnSurfaceVariant
                                                font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.Medium
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                horizontalAlignment: Text.AlignRight
                                                text: modelData.v
                                                color: MusicState.m3OnSurface
                                                font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.Bold
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // =====================================================
                        // TAB 5: AUDIO VISUALIZER (CAVA)
                        // =====================================================
                        ColumnLayout {
                            visible: settingsWin.tabIndex === 4
                            Layout.fillWidth: true
                            spacing: 12

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                Text {
                                    text: "Аудио-визуализатор (Cava)"
                                    color: MusicState.m3OnSurface
                                    font.family: MusicState.fontUi; font.pixelSize: 18; font.weight: Font.Bold
                                    Layout.fillWidth: true
                                }
                                Rectangle {
                                    Layout.preferredHeight: 26
                                    Layout.preferredWidth: cavaStTxt.implicitWidth + 18
                                    radius: 13
                                    color: SystemState.hasCava ? MusicState.m3PrimaryContainer : MusicState.m3ErrorContainer
                                    Text {
                                        id: cavaStTxt
                                        anchors.centerIn: parent
                                        text: SystemState.hasCava ? "cava установлен" : "cava не найден (pacman -S cava)"
                                        color: SystemState.hasCava ? MusicState.m3OnPrimaryContainer : MusicState.m3OnErrorContainer
                                        font.family: MusicState.fontUi; font.pixelSize: 10; font.weight: Font.Bold
                                    }
                                }
                            }

                            // Master On/Off Toggle
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 54; radius: 18; color: MusicState.m3SurfaceContainerHigh
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 1
                                        Text { text: "Включить визуализатор на рабочем столе"; color: MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 13; font.weight: Font.Medium }
                                        Text { text: "Автоматически скрывается на паузе (требуется пакет cava)"; color: MusicState.m3OnSurfaceVariant; font.family: MusicState.fontUi; font.pixelSize: 10 }
                                    }
                                    Rectangle {
                                        Layout.preferredWidth: 46; Layout.preferredHeight: 26; radius: 13
                                        color: ShellConfig.audioVisualizer ? MusicState.m3Primary : MusicState.m3SurfaceContainer
                                        Rectangle { width: 20; height: 20; radius: 10; y: 3; x: ShellConfig.audioVisualizer ? 23 : 3; color: ShellConfig.audioVisualizer ? MusicState.m3OnPrimary : MusicState.m3OnSurfaceVariant; Behavior on x { M3Anim { duration: 220 } } }
                                    }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ShellConfig.audioVisualizer = !ShellConfig.audioVisualizer; ShellConfig.save() } }
                            }

                            // Width Mode: Full-screen vs Compact Center
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 54; radius: 18; color: MusicState.m3SurfaceContainerHigh
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 14; spacing: 8
                                    Text { text: "Ширина визуализатора"; color: MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 13; font.weight: Font.Medium; Layout.fillWidth: true }
                                    Repeater {
                                        model: [
                                            { full: false, label: "По центру" },
                                            { full: true,  label: "На весь экран" }
                                        ]
                                        delegate: Rectangle {
                                            required property var modelData
                                            readonly property bool sel: ShellConfig.visFullWidth === modelData.full
                                            Layout.preferredHeight: 30; Layout.preferredWidth: vwTxt.implicitWidth + 18; radius: 15
                                            color: sel ? MusicState.m3PrimaryContainer : MusicState.m3SurfaceContainer
                                            Text { id: vwTxt; anchors.centerIn: parent; text: modelData.label; color: sel ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ShellConfig.visFullWidth = modelData.full; ShellConfig.save() } }
                                        }
                                    }
                                }
                            }

                            // Smooth Capsule Sliders for Bar Count, Height & Spacing
                            Repeater {
                                model: [
                                    { key: "visBars",    label: "Количество плиток",    minV: 16, maxV: 96,  step: 2, unit: ""   },
                                    { key: "visHeight",  label: "Высота столбиков",     minV: 40, maxV: 220, step: 4, unit: "px" },
                                    { key: "visSpacing", label: "Зазор между плитками", minV: 0,  maxV: 12,  step: 1, unit: "px" }
                                ]
                                delegate: Rectangle {
                                    id: visSlCard
                                    required property var modelData
                                    readonly property real curVal: Number(ShellConfig[modelData.key])
                                    readonly property real ratio: Math.max(0.0, Math.min(1.0, (curVal - modelData.minV) / Math.max(1, modelData.maxV - modelData.minV)))

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 62
                                    radius: 18
                                    color: MusicState.m3SurfaceContainerHigh

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 16; anchors.rightMargin: 16; anchors.topMargin: 8; anchors.bottomMargin: 10
                                        spacing: 6

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text { Layout.fillWidth: true; text: visSlCard.modelData.label; color: MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.Medium }
                                            Text { text: Math.round(visSlCard.curVal) + visSlCard.modelData.unit; color: MusicState.m3Primary; font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.Bold }
                                        }

                                        Rectangle {
                                            id: slTrack
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 16
                                            radius: 8
                                            color: MusicState.m3SurfaceContainer
                                            clip: true

                                            Rectangle {
                                                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                                width: Math.max(16, Math.round(parent.width * visSlCard.ratio))
                                                radius: 8
                                                color: MusicState.m3Primary
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                function applyFromX(mx) {
                                                    const r = Math.max(0.0, Math.min(1.0, mx / slTrack.width))
                                                    const raw = visSlCard.modelData.minV + r * (visSlCard.modelData.maxV - visSlCard.modelData.minV)
                                                    const snapped = Math.round(raw / visSlCard.modelData.step) * visSlCard.modelData.step
                                                    ShellConfig[visSlCard.modelData.key] = Math.max(visSlCard.modelData.minV, Math.min(visSlCard.modelData.maxV, snapped))
                                                }
                                                onPressed: function(m) { applyFromX(m.x) }
                                                onPositionChanged: function(m) { if (pressed) applyFromX(m.x) }
                                                onReleased: ShellConfig.save()
                                            }
                                        }
                                    }
                                }
                            }

                            // Style: Bars vs Mirror Wave
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 54; radius: 18; color: MusicState.m3SurfaceContainerHigh
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 14; spacing: 8
                                    Text { text: "Стиль отрисовки"; color: MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 13; font.weight: Font.Medium; Layout.fillWidth: true }
                                    Repeater {
                                        model: [
                                            { id: "bars",   label: "От нижнего края" },
                                            { id: "mirror", label: "Зеркальная волна" }
                                        ]
                                        delegate: Rectangle {
                                            required property var modelData
                                            readonly property bool sel: ShellConfig.visStyle === modelData.id
                                            Layout.preferredHeight: 30; Layout.preferredWidth: vsTxt.implicitWidth + 18; radius: 15
                                            color: sel ? MusicState.m3PrimaryContainer : MusicState.m3SurfaceContainer
                                            Text { id: vsTxt; anchors.centerIn: parent; text: modelData.label; color: sel ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ShellConfig.visStyle = modelData.id; ShellConfig.save() } }
                                        }
                                    }
                                }
                            }
                        }

                        // =====================================================
                        // TAB 6: HYPRLAND ANIMATIONS CUSTOMIZER
                        // =====================================================
                        ColumnLayout {
                            visible: settingsWin.tabIndex === 5
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                text: "Анимации Hyprland"
                                color: MusicState.m3OnSurface
                                font.family: MusicState.fontUi; font.pixelSize: 18; font.weight: Font.Bold
                            }

                            // Curve Preset
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 62; radius: 18; color: MusicState.m3SurfaceContainerHigh
                                ColumnLayout {
                                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 14; anchors.topMargin: 8; anchors.bottomMargin: 8; spacing: 6
                                    Text { text: "Пресет кривых"; color: MusicState.m3OnSurfaceVariant; font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold }
                                    RowLayout {
                                        Layout.fillWidth: true; spacing: 6
                                        Repeater {
                                            model: [
                                                { id: "smooth",  label: "Плавные M3" },
                                                { id: "snappy",  label: "Быстрые" },
                                                { id: "bounce",  label: "Пружина" },
                                                { id: "minimal", label: "Минимум" },
                                                { id: "off",     label: "Выкл" }
                                            ]
                                            delegate: Rectangle {
                                                required property var modelData
                                                readonly property bool sel: ShellConfig.hyprAnimStyle === modelData.id
                                                Layout.fillWidth: true; Layout.preferredHeight: 28; radius: 14
                                                color: sel ? MusicState.m3PrimaryContainer : MusicState.m3SurfaceContainer
                                                Text { anchors.centerIn: parent; text: modelData.label; color: sel ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold }
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ShellConfig.hyprAnimStyle = modelData.id; SystemState.applyHyprAnims() } }
                                            }
                                        }
                                    }
                                }
                            }

                            // Window Animation Style
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 54; radius: 18; color: MusicState.m3SurfaceContainerHigh
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 14; spacing: 6
                                    Text { text: "Открытие окон"; color: MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 13; font.weight: Font.Medium; Layout.fillWidth: true }
                                    Repeater {
                                        model: [
                                            { id: "popin",  label: "Pop-in" },
                                            { id: "slide",  label: "Slide" },
                                            { id: "gnomed", label: "Gnomed" },
                                            { id: "fade",   label: "Fade" }
                                        ]
                                        delegate: Rectangle {
                                            required property var modelData
                                            readonly property bool sel: ShellConfig.hyprAnimWinStyle === modelData.id
                                            Layout.preferredHeight: 30; Layout.preferredWidth: awTxt.implicitWidth + 16; radius: 15
                                            color: sel ? MusicState.m3PrimaryContainer : MusicState.m3SurfaceContainer
                                            Text { id: awTxt; anchors.centerIn: parent; text: modelData.label; color: sel ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ShellConfig.hyprAnimWinStyle = modelData.id; SystemState.applyHyprAnims() } }
                                        }
                                    }
                                }
                            }

                            // Workspace Transition Style
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 54; radius: 18; color: MusicState.m3SurfaceContainerHigh
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 14; spacing: 6
                                    Text { text: "Переход рабочих столов"; color: MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 13; font.weight: Font.Medium; Layout.fillWidth: true }
                                    Repeater {
                                        model: [
                                            { id: "slide",     label: "Slide" },
                                            { id: "slidefade", label: "SlideFade" },
                                            { id: "fade",      label: "Fade" },
                                            { id: "slidevert", label: "Верт." }
                                        ]
                                        delegate: Rectangle {
                                            required property var modelData
                                            readonly property bool sel: ShellConfig.hyprAnimWsStyle === modelData.id
                                            Layout.preferredHeight: 30; Layout.preferredWidth: awsTxt.implicitWidth + 14; radius: 15
                                            color: sel ? MusicState.m3PrimaryContainer : MusicState.m3SurfaceContainer
                                            Text { id: awsTxt; anchors.centerIn: parent; text: modelData.label; color: sel ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ShellConfig.hyprAnimWsStyle = modelData.id; SystemState.applyHyprAnims() } }
                                        }
                                    }
                                }
                            }

                            // Speed Multiplier
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 54; radius: 18; color: MusicState.m3SurfaceContainerHigh
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 14; spacing: 6
                                    Text { text: "Длительность (скорость)"; color: MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 13; font.weight: Font.Medium; Layout.fillWidth: true }
                                    Repeater {
                                        model: [
                                            { v: 0.6, label: "0.6×" },
                                            { v: 0.8, label: "0.8×" },
                                            { v: 1.0, label: "1.0×" },
                                            { v: 1.3, label: "1.3×" },
                                            { v: 1.6, label: "1.6×" }
                                        ]
                                        delegate: Rectangle {
                                            required property var modelData
                                            readonly property bool sel: Math.abs(ShellConfig.hyprAnimSpeed - modelData.v) < 0.05
                                            Layout.preferredHeight: 30; Layout.preferredWidth: 44; radius: 15
                                            color: sel ? MusicState.m3PrimaryContainer : MusicState.m3SurfaceContainer
                                            Text { anchors.centerIn: parent; text: modelData.label; color: sel ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ShellConfig.hyprAnimSpeed = modelData.v; SystemState.applyHyprAnims() } }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
