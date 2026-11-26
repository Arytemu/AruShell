import QtQuick
import QtQuick.Layouts
import "../services"

/**
 * Dux Shell 2.0 / iOS-Style Interactive 4-Column Grid Control Center:
 * - Every widget lives on a real 4-column snap grid: { id, col, row, w (1..4), h (1..2) }
 * - Edit Mode (pencil button): draws visible grid cells; drag ANY tile with mouse to move
 *   across the grid (with live ghost snap preview), drag bottom-right corner handle to resize
 *   (1x1, 2x1, 3x1, 4x1, 1x2, 2x2, etc.) with ZERO jitter, hide or add tiles freely!
 * - Audio Submenu with Output Devices + Per-Application Volume Mixer
 */
Item {
    id: root

    property bool editMode: false

    // Grid geometry (fixed cell canvas -> zero feedback oscillation during drag/resize!)
    readonly property int cols: 4
    readonly property int cellW: 88
    readonly property int cellH: 58
    readonly property int gap: 8
    readonly property int canvasW: cols * cellW + (cols - 1) * gap

    // Live drag/resize state
    property string activeDragId: ""
    property string activeResizeId: ""
    property int ghostCol: 0
    property int ghostRow: 0
    property int ghostW: 1
    property int ghostH: 1

    readonly property var gridTiles: ShellConfig.qsGridLayout || []

    readonly property int usedRows: {
        let maxR = 4
        const list = gridTiles
        for (let i = 0; i < list.length; i++) {
            const t = list[i]
            if (!t) continue
            const endR = (t.row || 0) + (t.h || 1)
            if (endR > maxR) maxR = endR
        }
        return editMode ? Math.min(7, maxR + 1) : maxR
    }

    readonly property int canvasH: usedRows * cellH + Math.max(0, usedRows - 1) * gap

    width: canvasW + 32
    readonly property int targetHeight: {
        if (SystemState.quickSettingsSubmenu === "") return Math.max(140, Math.round(mainCol.implicitHeight + 32))
        if (SystemState.quickSettingsSubmenu === "power") return 260
        if (SystemState.quickSettingsSubmenu === "audio") return 430
        return 380
    }
    height: targetHeight
    Behavior on height { M3Anim { duration: 240 } }

    visible: opacity > 0.01
    opacity: SystemState.quickSettingsOpen ? 1.0 : 0.0
    scale: SystemState.quickSettingsOpen ? 1.0 : 0.94
    y: SystemState.quickSettingsOpen ? 0 : -12
    transformOrigin: Item.TopRight

    Behavior on opacity { M3Anim { duration: SystemState.quickSettingsOpen ? 220 : 150 } }
    Behavior on scale   { M3Anim { duration: SystemState.quickSettingsOpen ? 300 : 180 } }
    Behavior on y       { M3Anim { duration: SystemState.quickSettingsOpen ? 300 : 180 } }

    readonly property var allCatalog: [
        { id: "wifi",       label: "Wi-Fi",      defW: 2, defH: 1 },
        { id: "bt",         label: "Bluetooth",  defW: 2, defH: 1 },
        { id: "audio",      label: "Звук",       defW: 2, defH: 1 },
        { id: "power",      label: "Питание",    defW: 2, defH: 1 },
        { id: "night",      label: "Ночь",       defW: 1, defH: 1 },
        { id: "dnd",        label: "DND",        defW: 1, defH: 1 },
        { id: "game",       label: "Игра",       defW: 1, defH: 1 },
        { id: "awake",      label: "Не спать",   defW: 1, defH: 1 },
        { id: "volume",     label: "Громкость",  defW: 4, defH: 1 },
        { id: "brightness", label: "Яркость",    defW: 4, defH: 1 },
        { id: "screenshot", label: "Снимок",     defW: 2, defH: 1 },
        { id: "clipboard",  label: "Буфер",      defW: 1, defH: 1 },
        { id: "wallpaper",  label: "Обои",       defW: 1, defH: 1 }
    ]

    function hasTile(id) {
        const list = gridTiles
        for (let i = 0; i < list.length; i++) {
            if (list[i] && list[i].id === id) return true
        }
        return false
    }

    Connections {
        target: SystemState
        function onQuickSettingsOpenChanged() {
            if (!SystemState.quickSettingsOpen) {
                root.editMode = false
                root.activeDragId = ""
                root.activeResizeId = ""
            }
        }
    }

    Rectangle {
        id: panelBg
        anchors.fill: parent
        radius: 26
        color: MusicState.m3SurfaceContainer
        border.width: root.editMode ? 2 : 1
        border.color: root.editMode ? MusicState.m3Primary : MusicState.m3OutlineVariant
        Behavior on border.color { ColorAnimation { duration: 160 } }

        MouseArea { anchors.fill: parent }

        // =====================================================================
        // MAIN DUX GRID CONTROL CENTER VIEW
        // =====================================================================
        ColumnLayout {
            id: mainCol
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 16
            }
            spacing: 12
            visible: SystemState.quickSettingsSubmenu === ""

            // 1. Profile & Action Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 19
                    color: MusicState.m3PrimaryContainer
                    Text {
                        anchors.centerIn: parent
                        text: (SystemState.userName || "A").slice(0, 1).toUpperCase()
                        color: MusicState.m3OnPrimaryContainer
                        font.family: MusicState.fontUi; font.pixelSize: 16; font.weight: Font.Black
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        Layout.fillWidth: true
                        text: root.editMode ? "Сетка быстрых настроек" : (SystemState.userName || "Пользователь")
                        color: root.editMode ? MusicState.m3Primary : MusicState.m3OnSurface
                        font.family: MusicState.fontUi; font.pixelSize: 13; font.weight: Font.Bold
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.editMode
                            ? "Перетаскивай плитки и тяни правый нижний угол"
                            : ((SystemState.uptimeText ? ("Аптайм " + SystemState.uptimeText) : SystemState.distroName)
                               + (SystemState.hasBattery ? (" · " + SystemState.batteryPercent + "%") : ""))
                        color: MusicState.m3OnSurfaceVariant
                        font.family: MusicState.fontUi; font.pixelSize: 10; font.weight: Font.Medium
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    visible: root.editMode
                    Layout.preferredWidth: resetEdTxt.implicitWidth + 16
                    Layout.preferredHeight: 34; radius: 17
                    color: resetEdMa.containsMouse ? MusicState.m3ErrorContainer : MusicState.m3SurfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Text { id: resetEdTxt; anchors.centerIn: parent; text: "Сброс"; color: resetEdMa.containsMouse ? MusicState.m3OnErrorContainer : MusicState.m3OnSurfaceVariant; font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold }
                    MouseArea { id: resetEdMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ShellConfig.resetQsGrid() }
                }

                Rectangle {
                    Layout.preferredWidth: root.editMode ? (doneEdTxt.implicitWidth + 18) : 34
                    Layout.preferredHeight: 34; radius: 17
                    color: root.editMode ? MusicState.m3Primary : (editMa.containsMouse ? MusicState.m3SecondaryContainer : MusicState.m3SurfaceContainerHigh)
                    Behavior on color { ColorAnimation { duration: 140 } }
                    SysIcon { visible: !root.editMode; anchors.centerIn: parent; name: "edit"; size: 15; color: editMa.containsMouse ? MusicState.m3OnSecondaryContainer : MusicState.m3OnSurface }
                    Text { id: doneEdTxt; visible: root.editMode; anchors.centerIn: parent; text: "Готово"; color: MusicState.m3OnPrimary; font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold }
                    MouseArea { id: editMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.editMode = !root.editMode }
                }

                Rectangle {
                    visible: !root.editMode
                    Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 17
                    color: cfgMa.containsMouse ? MusicState.m3SecondaryContainer : MusicState.m3SurfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 140 } }
                    SysIcon { anchors.centerIn: parent; name: "settings"; size: 15; color: cfgMa.containsMouse ? MusicState.m3OnSecondaryContainer : MusicState.m3OnSurface }
                    MouseArea { id: cfgMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ShellConfig.openSettings() }
                }

                Rectangle {
                    visible: !root.editMode
                    Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 17
                    color: lockMa.containsMouse ? MusicState.m3SecondaryContainer : MusicState.m3SurfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 140 } }
                    SysIcon { anchors.centerIn: parent; name: "lock"; size: 15; color: lockMa.containsMouse ? MusicState.m3OnSecondaryContainer : MusicState.m3OnSurface }
                    MouseArea { id: lockMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: SystemState.lockScreen() }
                }

                Rectangle {
                    visible: !root.editMode
                    Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 17
                    color: pwrMenuMa.containsMouse ? MusicState.m3ErrorContainer : MusicState.m3SurfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 140 } }
                    SysIcon { anchors.centerIn: parent; name: "power"; size: 15; color: pwrMenuMa.containsMouse ? MusicState.m3OnErrorContainer : MusicState.m3Error }
                    MouseArea { id: pwrMenuMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: SystemState.openSubmenu("power") }
                }
            }

            // 2. Interactive 4-Column Snap Grid Canvas
            Item {
                id: gridCanvas
                Layout.preferredWidth: root.canvasW
                Layout.preferredHeight: root.canvasH

                // Background Grid Cells (visible in Edit Mode!)
                Repeater {
                    model: root.editMode ? (root.cols * root.usedRows) : 0
                    delegate: Rectangle {
                        required property int index
                        readonly property int c: index % root.cols
                        readonly property int r: Math.floor(index / root.cols)
                        x: c * (root.cellW + root.gap)
                        y: r * (root.cellH + root.gap)
                        width: root.cellW
                        height: root.cellH
                        radius: 18
                        color: Qt.rgba(MusicState.m3OnSurface.r, MusicState.m3OnSurface.g, MusicState.m3OnSurface.b, 0.04)
                        border.width: 1
                        border.color: Qt.rgba(MusicState.m3Outline.r, MusicState.m3Outline.g, MusicState.m3Outline.b, 0.28)
                    }
                }

                // Live Ghost Target Preview (shows exact snap cells while dragging or resizing!)
                Rectangle {
                    visible: root.editMode && (root.activeDragId !== "" || root.activeResizeId !== "")
                    x: root.ghostCol * (root.cellW + root.gap)
                    y: root.ghostRow * (root.cellH + root.gap)
                    width: root.ghostW * root.cellW + (root.ghostW - 1) * root.gap
                    height: root.ghostH * root.cellH + (root.ghostH - 1) * root.gap
                    radius: 20
                    z: 2
                    color: Qt.rgba(MusicState.m3Primary.r, MusicState.m3Primary.g, MusicState.m3Primary.b, 0.22)
                    border.width: 2
                    border.color: MusicState.m3Primary
                    Behavior on x      { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    Behavior on y      { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    Behavior on width  { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                }

                // Live Interactive Grid Widgets
                Repeater {
                    model: root.gridTiles
                    delegate: Item {
                        id: tileWrap
                        required property var modelData
                        required property int index

                        readonly property string tid: modelData.id || ""
                        readonly property int tCol: modelData.col || 0
                        readonly property int tRow: modelData.row || 0
                        readonly property int tW: Math.max(1, Math.min(4, modelData.w || 1))
                        readonly property int tH: Math.max(1, Math.min(2, modelData.h || 1))

                        readonly property bool isDragging: root.activeDragId === tid
                        readonly property bool isResizing: root.activeResizeId === tid
                        readonly property bool isSlider: tid === "volume" || tid === "brightness"

                        property real dragX: 0
                        property real dragY: 0

                        readonly property real snapX: tCol * (root.cellW + root.gap)
                        readonly property real snapY: tRow * (root.cellH + root.gap)
                        readonly property real snapW: tW * root.cellW + (tW - 1) * root.gap
                        readonly property real snapH: tH * root.cellH + (tH - 1) * root.gap

                        x: isDragging ? dragX : snapX
                        y: isDragging ? dragY : snapY
                        width: isResizing ? (root.ghostW * root.cellW + (root.ghostW - 1) * root.gap) : snapW
                        height: isResizing ? (root.ghostH * root.cellH + (root.ghostH - 1) * root.gap) : snapH
                        z: (isDragging || isResizing) ? 60 : 10
                        scale: isDragging ? 1.04 : 1.0

                        Behavior on x      { enabled: !tileWrap.isDragging; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Behavior on y      { enabled: !tileWrap.isDragging; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Behavior on width  { enabled: !tileWrap.isResizing; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                        Behavior on height { enabled: !tileWrap.isResizing; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                        Behavior on scale  { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                        readonly property bool isActive: {
                            if (tid === "wifi") return SystemState.wifiEnabled || SystemState.ethernetConnected
                            if (tid === "bt") return SystemState.btEnabled
                            if (tid === "audio") return !SystemState.muted
                            if (tid === "power") return SystemState.powerProfile === "performance"
                            if (tid === "night") return SystemState.nightLight
                            if (tid === "dnd") return NotifState.dndEnabled
                            if (tid === "game") return SystemState.gameMode
                            if (tid === "awake") return SystemState.keepAwake
                            return false
                        }

                        readonly property string iconName: {
                            if (tid === "wifi") return SystemState.ethernetConnected ? "ethernet" : (SystemState.wifiEnabled ? "wifi" : "wifi_off")
                            if (tid === "bt") return SystemState.btEnabled ? "bluetooth" : "bluetooth_off"
                            if (tid === "audio") return "audio_out"
                            if (tid === "power") return "performance"
                            if (tid === "night") return "nightlight"
                            if (tid === "dnd") return NotifState.dndEnabled ? "bell_off" : "bell"
                            if (tid === "game") return "apps"
                            if (tid === "awake") return "brightness"
                            if (tid === "volume") return (SystemState.muted || SystemState.volume === 0) ? "volume_mute" : (SystemState.volume < 45 ? "volume_low" : "volume_high")
                            if (tid === "brightness") return "brightness"
                            if (tid === "screenshot") return "screenshot"
                            if (tid === "clipboard") return "clipboard"
                            return "palette"
                        }

                        readonly property string titleText: {
                            if (tid === "wifi") return SystemState.ethernetConnected ? "Ethernet" : "Wi-Fi"
                            if (tid === "bt") return "Bluetooth"
                            if (tid === "audio") return "Звук"
                            if (tid === "power") return "Питание"
                            if (tid === "night") return "Ночь"
                            if (tid === "dnd") return "DND"
                            if (tid === "game") return "Игра"
                            if (tid === "awake") return "Не спать"
                            if (tid === "volume") return "Громкость"
                            if (tid === "brightness") return "Яркость"
                            if (tid === "screenshot") return "Снимок"
                            if (tid === "clipboard") return "Буфер"
                            return "Обои"
                        }

                        readonly property string subText: {
                            if (tid === "wifi") return SystemState.ethernetConnected ? "Подкл." : (SystemState.wifiEnabled ? (SystemState.wifiSsid || "Вкл") : "Выкл")
                            if (tid === "bt") return SystemState.btEnabled ? (SystemState.btDevice || "Вкл") : "Выкл"
                            if (tid === "audio") return SystemState.muted ? "Выкл" : (SystemState.volume + "%")
                            if (tid === "power") return SystemState.powerProfile === "performance" ? "Максимум" : (SystemState.powerProfile === "power-saver" ? "Экономия" : "Баланс")
                            if (tid === "night") return SystemState.nightLight ? "4200K" : "Выкл"
                            if (tid === "dnd") return NotifState.dndEnabled ? "Вкл" : "Выкл"
                            if (tid === "game") return SystemState.gameMode ? "Вкл" : "Выкл"
                            if (tid === "awake") return SystemState.keepAwake ? "Вкл" : "Выкл"
                            return ""
                        }

                        readonly property bool hasSubmenu: tid === "wifi" || tid === "bt" || tid === "audio"

                        readonly property color tileFill: {
                            if (isSlider) return MusicState.m3SurfaceContainerHigh
                            if (tid === "audio" || tid === "screenshot" || tid === "clipboard" || tid === "wallpaper") return MusicState.m3SurfaceContainerHigh
                            if (!isActive) return MusicState.m3SurfaceContainerHigh
                            if (tid === "wifi" || tid === "bt") return MusicState.m3PrimaryContainer
                            if (tid === "power") return MusicState.m3SecondaryContainer
                            return MusicState.m3TertiaryContainer
                        }

                        readonly property color tileFg: {
                            if (isSlider || tid === "audio" || tid === "screenshot" || tid === "clipboard" || tid === "wallpaper" || !isActive) return MusicState.m3OnSurface
                            if (tid === "wifi" || tid === "bt") return MusicState.m3OnPrimaryContainer
                            if (tid === "power") return MusicState.m3OnSecondaryContainer
                            return MusicState.m3OnTertiaryContainer
                        }

                        Rectangle {
                            id: cardBody
                            anchors.fill: parent
                            radius: 20
                            color: tileWrap.tileFill
                            clip: true
                            border.width: root.editMode ? 1.5 : 0
                            border.color: (tileWrap.isDragging || tileWrap.isResizing) ? MusicState.m3Primary : MusicState.m3Outline
                            Behavior on color { ColorAnimation { duration: 160 } }

                            // --- SLIDER CONTENT (Horizontal when w >= 2, Vertical when w == 1 && h >= 2!) ---
                            Item {
                                visible: tileWrap.isSlider
                                anchors.fill: parent

                                readonly property real ratio: tileWrap.tid === "volume"
                                    ? (SystemState.muted ? 0.0 : SystemState.volume / 100.0)
                                    : (SystemState.brightness / 100.0)
                                readonly property bool vertical: tileWrap.tW === 1 && tileWrap.tH >= 2

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.bottom: parent.bottom
                                    anchors.top: parent.vertical ? undefined : parent.top
                                    anchors.right: parent.vertical ? parent.right : undefined
                                    width: parent.vertical ? parent.width : (tileWrap.tW === 1 ? Math.round(parent.width * parent.ratio) : Math.max(parent.height, Math.round(parent.width * parent.ratio)))
                                    height: parent.vertical ? Math.max(parent.width * 0.45, Math.round(parent.height * parent.ratio)) : parent.height
                                    radius: 20
                                    color: (tileWrap.tid === "volume" && SystemState.muted) ? MusicState.m3SurfaceContainerHighest : MusicState.m3PrimaryContainer
                                    Behavior on width  { enabled: !slMa.pressed; NumberAnimation { duration: 110 } }
                                    Behavior on height { enabled: !slMa.pressed; NumberAnimation { duration: 110 } }
                                }

                                // Horizontal Slider Labels
                                RowLayout {
                                    visible: !parent.vertical
                                    anchors.fill: parent
                                    anchors.leftMargin: 12; anchors.rightMargin: 14
                                    spacing: 10
                                    SysIcon { name: tileWrap.iconName; size: 17; color: MusicState.m3OnPrimaryContainer }
                                    Text {
                                        visible: tileWrap.tW >= 2
                                        Layout.fillWidth: true
                                        text: tileWrap.titleText
                                        color: parent.parent.ratio > 0.35 ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface
                                        font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.SemiBold
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: tileWrap.tid === "volume" ? (SystemState.muted ? "Выкл" : (SystemState.volume + "%")) : (SystemState.brightness + "%")
                                        color: parent.parent.ratio > 0.85 ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurfaceVariant
                                        font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold
                                    }
                                }

                                // Vertical Slider Labels (1x2 iOS style!)
                                ColumnLayout {
                                    visible: parent.vertical
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: tileWrap.tid === "volume" ? (SystemState.muted ? "0%" : (SystemState.volume + "%")) : (SystemState.brightness + "%")
                                        color: MusicState.m3OnSurface
                                        font.family: MusicState.fontUi; font.pixelSize: 10; font.weight: Font.Bold
                                    }
                                    Item { Layout.fillHeight: true }
                                    SysIcon { Layout.alignment: Qt.AlignHCenter; name: tileWrap.iconName; size: 18; color: MusicState.m3OnPrimaryContainer }
                                }

                                MouseArea {
                                    id: slMa
                                    anchors.fill: parent
                                    enabled: !root.editMode
                                    cursorShape: Qt.PointingHandCursor
                                    function applyPos(mx, my) {
                                        const pct = parent.vertical
                                            ? Math.max(0, Math.min(100, (1.0 - my / parent.height) * 100))
                                            : Math.max(0, Math.min(100, (mx / parent.width) * 100))
                                        if (tileWrap.tid === "volume") SystemState.setVolume(pct)
                                        else SystemState.setBrightness(Math.max(5, pct))
                                    }
                                    onPressed: function(m) { applyPos(m.x, m.y) }
                                    onPositionChanged: function(m) { if (pressed) applyPos(m.x, m.y) }
                                }
                            }

                            // --- STANDARD TILE CONTENT (adapts cleanly to 1x1, 2x1, 2x2, 4x1!) ---
                            Item {
                                visible: !tileWrap.isSlider
                                anchors.fill: parent

                                // Compact 1x1 or Tall 1x2 Layout
                                ColumnLayout {
                                    visible: tileWrap.tW === 1
                                    anchors.centerIn: parent
                                    spacing: 4
                                    SysIcon { Layout.alignment: Qt.AlignHCenter; name: tileWrap.iconName; size: tileWrap.tH >= 2 ? 22 : 18; color: tileWrap.tileFg }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: tileWrap.titleText
                                        color: tileWrap.tileFg
                                        font.family: MusicState.fontUi; font.pixelSize: 10; font.weight: Font.Bold
                                    }
                                }

                                // Wide 2x1 / 3x1 / 4x1 / 2x2 Layout
                                RowLayout {
                                    visible: tileWrap.tW >= 2
                                    anchors.fill: parent
                                    anchors.leftMargin: 10; anchors.rightMargin: 8
                                    spacing: 10

                                    Rectangle {
                                        Layout.preferredWidth: tileWrap.tH >= 2 ? 42 : 36
                                        Layout.preferredHeight: tileWrap.tH >= 2 ? 42 : 36
                                        radius: Layout.preferredWidth / 2
                                        color: tileWrap.isActive
                                            ? (tileWrap.tid === "audio" ? MusicState.m3SecondaryContainer : MusicState.m3Primary)
                                            : MusicState.m3SurfaceContainer
                                        SysIcon {
                                            anchors.centerIn: parent
                                            name: tileWrap.iconName
                                            size: tileWrap.tH >= 2 ? 20 : 17
                                            color: tileWrap.isActive
                                                ? (tileWrap.tid === "audio" ? MusicState.m3OnSecondaryContainer : MusicState.m3OnPrimary)
                                                : MusicState.m3OnSurface
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            Layout.fillWidth: true
                                            text: tileWrap.titleText
                                            color: tileWrap.tileFg
                                            font.family: MusicState.fontUi; font.pixelSize: tileWrap.tH >= 2 ? 14 : 12; font.weight: Font.Bold
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            visible: tileWrap.subText !== ""
                                            Layout.fillWidth: true
                                            text: tileWrap.subText
                                            color: tileWrap.tileFg; opacity: 0.82
                                            font.family: MusicState.fontUi; font.pixelSize: 10
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Rectangle {
                                        visible: !root.editMode && tileWrap.hasSubmenu
                                        Layout.preferredWidth: 26; Layout.preferredHeight: 36; radius: 13
                                        color: subArrMa.containsMouse ? Qt.rgba(MusicState.m3OnSurface.r, MusicState.m3OnSurface.g, MusicState.m3OnSurface.b, 0.12) : "transparent"
                                        z: 5
                                        SysIcon { anchors.centerIn: parent; name: "chevron_right"; size: 14; color: tileWrap.tileFg }
                                        MouseArea { id: subArrMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: SystemState.openSubmenu(tileWrap.tid) }
                                    }
                                }

                                // M3 Hover & Press State Layer (works cleanly on both Dark and Light themes)
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 20
                                    color: Qt.rgba(
                                        MusicState.m3OnSurface.r,
                                        MusicState.m3OnSurface.g,
                                        MusicState.m3OnSurface.b,
                                        tileBodyMa.pressed ? 0.12 : (tileBodyMa.containsMouse ? 0.07 : 0.0)
                                    )
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }

                                // Normal-mode click action (Right-click opens submenu even on compact 1x1 tiles!)
                                MouseArea {
                                    id: tileBodyMa
                                    anchors.fill: parent
                                    anchors.rightMargin: (tileWrap.tW >= 2 && tileWrap.hasSubmenu) ? 34 : 0
                                    enabled: !root.editMode
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: function(mouse) {
                                        if (mouse.button === Qt.RightButton && tileWrap.hasSubmenu) {
                                            SystemState.openSubmenu(tileWrap.tid)
                                            return
                                        }
                                        if (tileWrap.tid === "wifi") SystemState.toggleWifi()
                                        else if (tileWrap.tid === "bt") SystemState.toggleBluetooth()
                                        else if (tileWrap.tid === "audio") SystemState.openSubmenu("audio")
                                        else if (tileWrap.tid === "power") SystemState.cyclePowerProfile()
                                        else if (tileWrap.tid === "night") SystemState.toggleNightLight()
                                        else if (tileWrap.tid === "dnd") NotifState.dndEnabled = !NotifState.dndEnabled
                                        else if (tileWrap.tid === "game") SystemState.toggleGameMode()
                                        else if (tileWrap.tid === "awake") SystemState.toggleKeepAwake()
                                        else if (tileWrap.tid === "screenshot") ScreenshotState.open("region")
                                        else if (tileWrap.tid === "clipboard") ClipboardState.toggle()
                                        else if (tileWrap.tid === "wallpaper") { SystemState.quickSettingsOpen = false; WallpaperState.toggle() }
                                    }
                                }
                            }
                        }

                        // --- EDIT MODE: DRAG TILE ANYWHERE ON GRID ---
                        MouseArea {
                            id: dragTileMa
                            anchors.fill: parent
                            enabled: root.editMode
                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            z: 20

                            property real grabOffX: 0
                            property real grabOffY: 0

                            onPressed: function(m) {
                                const pt = mapToItem(gridCanvas, m.x, m.y)
                                grabOffX = pt.x - tileWrap.snapX
                                grabOffY = pt.y - tileWrap.snapY
                                tileWrap.dragX = tileWrap.snapX
                                tileWrap.dragY = tileWrap.snapY
                                root.activeDragId = tileWrap.tid
                                root.ghostCol = tileWrap.tCol
                                root.ghostRow = tileWrap.tRow
                                root.ghostW = tileWrap.tW
                                root.ghostH = tileWrap.tH
                            }
                            onPositionChanged: function(m) {
                                if (!pressed) return
                                const pt = mapToItem(gridCanvas, m.x, m.y)
                                tileWrap.dragX = pt.x - grabOffX
                                tileWrap.dragY = pt.y - grabOffY
                                const c = Math.max(0, Math.min(root.cols - tileWrap.tW, Math.round(tileWrap.dragX / (root.cellW + root.gap))))
                                const r = Math.max(0, Math.min(6, Math.round(tileWrap.dragY / (root.cellH + root.gap))))
                                root.ghostCol = c
                                root.ghostRow = r
                            }
                            onReleased: {
                                if (root.activeDragId === tileWrap.tid) {
                                    ShellConfig.updateGridTile(tileWrap.tid, root.ghostCol, root.ghostRow, tileWrap.tW, tileWrap.tH)
                                    root.activeDragId = ""
                                }
                            }
                        }

                        // --- EDIT MODE: REMOVE BUTTON (TOP-LEFT) ---
                        Rectangle {
                            visible: root.editMode
                            anchors.left: parent.left; anchors.top: parent.top
                            anchors.margins: -3
                            width: 20; height: 20; radius: 10; z: 30
                            color: MusicState.m3ErrorContainer
                            Text { anchors.centerIn: parent; text: "−"; color: MusicState.m3OnErrorContainer; font.pixelSize: 13; font.weight: Font.Black }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ShellConfig.removeGridTile(tileWrap.tid) }
                        }

                        // --- EDIT MODE: DRAG-TO-RESIZE CORNER HANDLE (BOTTOM-RIGHT, iOS/DUX STYLE!) ---
                        Rectangle {
                            visible: root.editMode
                            anchors.right: parent.right; anchors.bottom: parent.bottom
                            anchors.margins: 2
                            width: 22; height: 22; radius: 11; z: 30
                            color: resizeTileMa.pressed || resizeTileMa.containsMouse ? MusicState.m3Primary : MusicState.m3SecondaryContainer

                            Text {
                                anchors.centerIn: parent
                                text: "⌟"
                                color: resizeTileMa.pressed || resizeTileMa.containsMouse ? MusicState.m3OnPrimary : MusicState.m3OnSecondaryContainer
                                font.pixelSize: 14; font.weight: Font.Black
                            }

                            MouseArea {
                                id: resizeTileMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.SizeFDiagCursor

                                onPressed: {
                                    root.activeResizeId = tileWrap.tid
                                    root.ghostCol = tileWrap.tCol
                                    root.ghostRow = tileWrap.tRow
                                    root.ghostW = tileWrap.tW
                                    root.ghostH = tileWrap.tH
                                }
                                onPositionChanged: function(m) {
                                    if (!pressed) return
                                    const pt = mapToItem(gridCanvas, m.x, m.y)
                                    const relX = pt.x - tileWrap.snapX
                                    const relY = pt.y - tileWrap.snapY
                                    const maxW = root.cols - tileWrap.tCol
                                    const newW = Math.max(1, Math.min(maxW, Math.round((relX + root.gap) / (root.cellW + root.gap))))
                                    const newH = Math.max(1, Math.min(2, Math.round((relY + root.gap) / (root.cellH + root.gap))))
                                    root.ghostW = newW
                                    root.ghostH = newH
                                }
                                onReleased: {
                                    if (root.activeResizeId === tileWrap.tid) {
                                        ShellConfig.updateGridTile(tileWrap.tid, tileWrap.tCol, tileWrap.tRow, root.ghostW, root.ghostH)
                                        root.activeResizeId = ""
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 3. Edit Mode Footer: Add Hidden Tiles + Reset Grid
            ColumnLayout {
                visible: root.editMode
                Layout.fillWidth: true
                spacing: 8

                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: root.allCatalog
                        delegate: Rectangle {
                            required property var modelData
                            visible: !root.hasTile(modelData.id)
                            height: 26; width: addTxt.implicitWidth + 16; radius: 13
                            color: MusicState.m3SurfaceContainerHigh
                            Text { id: addTxt; anchors.centerIn: parent; text: "+ " + modelData.label; color: MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 10; font.weight: Font.Bold }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ShellConfig.addGridTile(modelData.id, modelData.defW, modelData.defH) }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 30; radius: 15
                    color: MusicState.m3SurfaceContainerHigh
                    Text { anchors.centerIn: parent; text: "Сбросить сетку по умолчанию"; color: MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.SemiBold }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ShellConfig.resetQsGrid() }
                }
            }
        }

        // =====================================================================
        // SUBMENU VIEWS (Wi-Fi / Bluetooth / Audio + App Mixer / Power)
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
                    text: SystemState.quickSettingsSubmenu === "wifi" ? "Сети Wi-Fi"
                        : (SystemState.quickSettingsSubmenu === "bt" ? "Устройства Bluetooth"
                        : (SystemState.quickSettingsSubmenu === "power" ? "Питание и сеанс" : "Звук и микшер приложений"))
                    color: MusicState.m3OnSurface
                    font.family: MusicState.fontUi; font.pixelSize: 14; font.weight: Font.Bold
                }

                Rectangle {
                    visible: SystemState.quickSettingsSubmenu !== "power"
                    Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 16
                    color: refMa.containsMouse ? MusicState.m3SurfaceContainerHighest : MusicState.m3SurfaceContainerHigh
                    SysIcon { anchors.centerIn: parent; name: "refresh"; size: 15; color: MusicState.m3OnSurface }
                    MouseArea {
                        id: refMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { if (SystemState.quickSettingsSubmenu === "wifi") SystemState.refreshWifiList(true); else SystemState.openSubmenu(SystemState.quickSettingsSubmenu) }
                    }
                }
            }

            // Power Actions Submenu
            GridLayout {
                visible: SystemState.quickSettingsSubmenu === "power"
                Layout.fillWidth: true; Layout.fillHeight: true
                columns: 2; columnSpacing: 10; rowSpacing: 10
                Repeater {
                    model: [
                        { id: "lock",    icon: "lock",   label: "Заблокировать", danger: false },
                        { id: "suspend", icon: "moon",   label: "Сон",           danger: false },
                        { id: "reboot",  icon: "reboot", label: "Перезагрузка",  danger: true  },
                        { id: "power",   icon: "power",  label: "Выключение",    danger: true  }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true; Layout.fillHeight: true; radius: 20
                        color: pBtnMa.containsMouse ? (modelData.danger ? MusicState.m3ErrorContainer : MusicState.m3SecondaryContainer) : MusicState.m3SurfaceContainerHigh
                        Behavior on color { ColorAnimation { duration: 150 } }
                        ColumnLayout {
                            anchors.centerIn: parent; spacing: 6
                            SysIcon { Layout.alignment: Qt.AlignHCenter; name: modelData.icon; size: 22; color: pBtnMa.containsMouse ? (modelData.danger ? MusicState.m3OnErrorContainer : MusicState.m3OnSecondaryContainer) : (modelData.danger ? MusicState.m3Error : MusicState.m3OnSurface) }
                            Text { Layout.alignment: Qt.AlignHCenter; text: modelData.label; color: pBtnMa.containsMouse ? (modelData.danger ? MusicState.m3OnErrorContainer : MusicState.m3OnSecondaryContainer) : MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.Bold }
                        }
                        MouseArea {
                            id: pBtnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.id === "lock") SystemState.lockScreen()
                                else if (modelData.id === "suspend") SystemState.suspendSystem()
                                else if (modelData.id === "reboot") SystemState.rebootSystem()
                                else if (modelData.id === "power") SystemState.powerOffSystem()
                            }
                        }
                    }
                }
            }

            // Wi-Fi Password Bar
            ColumnLayout {
                visible: SystemState.quickSettingsSubmenu === "wifi" && (SystemState.wifiPasswordTarget !== "" || SystemState.wifiStatusMsg !== "")
                Layout.fillWidth: true; spacing: 6
                Text { visible: SystemState.wifiStatusMsg !== ""; Layout.fillWidth: true; text: SystemState.wifiStatusMsg; color: MusicState.m3Primary; font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.SemiBold; elide: Text.ElideRight }
                RowLayout {
                    visible: SystemState.wifiPasswordTarget !== ""; Layout.fillWidth: true; spacing: 6
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 36; radius: 18; color: MusicState.m3SurfaceContainerHigh; border.width: 1; border.color: MusicState.m3Primary
                        TextInput {
                            id: wifiPwInput; anchors { fill: parent; leftMargin: 12; rightMargin: 12 } verticalAlignment: Text.AlignVCenter; echoMode: TextInput.Password; color: MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 12
                            onAccepted: { if (text.length > 0) { SystemState.connectWifi(SystemState.wifiPasswordTarget, text, "wpa", false); text = "" } }
                            Text { anchors.verticalCenter: parent.verticalCenter; visible: wifiPwInput.text.length === 0; text: "Пароль для " + SystemState.wifiPasswordTarget; color: MusicState.m3OnSurfaceVariant; opacity: 0.7; font.family: MusicState.fontUi; font.pixelSize: 11 }
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: 58; Layout.preferredHeight: 36; radius: 18; color: MusicState.m3Primary
                        Text { anchors.centerIn: parent; text: "OK"; color: MusicState.m3OnPrimary; font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (wifiPwInput.text.length > 0) { SystemState.connectWifi(SystemState.wifiPasswordTarget, wifiPwInput.text, "wpa", false); wifiPwInput.text = "" } } }
                    }
                }
            }

            // Wi-Fi List
            ListView {
                visible: SystemState.quickSettingsSubmenu === "wifi"
                Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 6
                model: SystemState.wifiNetworks
                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view ? ListView.view.width : 360; height: 44; radius: 14
                    color: modelData.inUse ? MusicState.m3PrimaryContainer : (wItemMa.containsMouse ? MusicState.m3SurfaceContainerHighest : MusicState.m3SurfaceContainerHigh)
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                        SysIcon { name: "wifi"; size: 16; color: modelData.inUse ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface }
                        Text { Layout.fillWidth: true; text: modelData.ssid; color: modelData.inUse ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: modelData.inUse ? Font.Bold : Font.Medium; elide: Text.ElideRight }
                        SysIcon { visible: (modelData.security || "") !== "" && !modelData.inUse; name: "lock"; size: 12; color: MusicState.m3OnSurfaceVariant }
                        Text { text: modelData.inUse ? "Подкл." : (modelData.signal + "%"); color: modelData.inUse ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurfaceVariant; font.family: MusicState.fontUi; font.pixelSize: 11 }
                    }
                    MouseArea { id: wItemMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (modelData.inUse) return; SystemState.connectWifi(modelData.ssid, "", modelData.security, modelData.saved); if (SystemState.wifiPasswordTarget !== "") wifiPwInput.forceActiveFocus() } }
                }
            }

            // Bluetooth List
            ListView {
                visible: SystemState.quickSettingsSubmenu === "bt"
                Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 6
                model: SystemState.btDevices
                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view ? ListView.view.width : 360; height: 44; radius: 14
                    color: modelData.connected ? MusicState.m3PrimaryContainer : (bItemMa.containsMouse ? MusicState.m3SurfaceContainerHighest : MusicState.m3SurfaceContainerHigh)
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
                        SysIcon { name: "bluetooth"; size: 16; color: modelData.connected ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface }
                        Text { Layout.fillWidth: true; text: modelData.name; color: modelData.connected ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: modelData.connected ? Font.Bold : Font.Medium; elide: Text.ElideRight }
                        Text { text: modelData.connected ? "Подкл." : "Подключить"; color: modelData.connected ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurfaceVariant; font.family: MusicState.fontUi; font.pixelSize: 10 }
                    }
                    MouseArea { id: bItemMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: SystemState.toggleBtDevice(modelData.mac, modelData.connected) }
                }
            }

            // Audio Submenu: Output Devices + Per-Application Volume Mixer
            Flickable {
                visible: SystemState.quickSettingsSubmenu === "audio"
                Layout.fillWidth: true; Layout.fillHeight: true
                contentWidth: width; contentHeight: audioSubCol.implicitHeight + 12; clip: true

                ColumnLayout {
                    id: audioSubCol
                    width: parent.width
                    spacing: 8

                    Text { text: "Устройства вывода"; color: MusicState.m3OnSurfaceVariant; font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold }

                    Repeater {
                        model: SystemState.audioSinks
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true; Layout.preferredHeight: 40; radius: 14
                            color: modelData.active ? MusicState.m3PrimaryContainer : (aItemMa.containsMouse ? MusicState.m3SurfaceContainerHighest : MusicState.m3SurfaceContainerHigh)
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
                                SysIcon { name: "audio_out"; size: 15; color: modelData.active ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface }
                                Text { Layout.fillWidth: true; text: modelData.desc; color: modelData.active ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: modelData.active ? Font.Bold : Font.Medium; elide: Text.ElideRight }
                            }
                            MouseArea { id: aItemMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: SystemState.setAudioSink(modelData.id) }
                        }
                    }

                    Text { Layout.topMargin: 6; text: "Громкость отдельных приложений"; color: MusicState.m3OnSurfaceVariant; font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold }

                    Text {
                        visible: !SystemState.appStreams || SystemState.appStreams.length === 0
                        text: "Нет активных аудиопотоков (включи звук в приложении)"
                        color: MusicState.m3OnSurfaceVariant; opacity: 0.7
                        font.family: MusicState.fontUi; font.pixelSize: 11
                    }

                    Repeater {
                        model: SystemState.appStreams
                        delegate: Rectangle {
                            id: appTrack
                            required property var modelData
                            Layout.fillWidth: true; Layout.preferredHeight: 42; radius: 21
                            color: MusicState.m3SurfaceContainerHigh
                            clip: true

                            property int localVol: modelData.volume
                            readonly property real ratio: modelData.muted ? 0.0 : Math.min(1.0, localVol / 100.0)

                            Rectangle {
                                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                width: Math.max(40, Math.round(parent.width * appTrack.ratio))
                                radius: 21
                                color: appTrack.modelData.muted ? MusicState.m3SurfaceContainerHighest : MusicState.m3SecondaryContainer
                                Behavior on width { enabled: !appDrag.pressed; NumberAnimation { duration: 100 } }
                            }

                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 14; spacing: 10
                                Item {
                                    Layout.preferredWidth: 22; Layout.preferredHeight: 22; z: 5
                                    SysIcon { anchors.centerIn: parent; name: appTrack.modelData.muted ? "volume_mute" : "volume_high"; size: 15; color: appTrack.modelData.muted ? MusicState.m3OnSurfaceVariant : MusicState.m3OnSecondaryContainer }
                                    MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: SystemState.toggleAppMute(appTrack.modelData.id) }
                                }
                                Text {
                                    Layout.fillWidth: true; text: appTrack.modelData.name
                                    color: appTrack.ratio > 0.35 ? MusicState.m3OnSecondaryContainer : MusicState.m3OnSurface
                                    font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.SemiBold; elide: Text.ElideRight
                                }
                                Text {
                                    text: appTrack.modelData.muted ? "Выкл" : (appTrack.localVol + "%")
                                    color: appTrack.ratio > 0.85 ? MusicState.m3OnSecondaryContainer : MusicState.m3OnSurfaceVariant
                                    font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold
                                }
                            }

                            MouseArea {
                                id: appDrag; anchors.fill: parent; anchors.leftMargin: 38; cursorShape: Qt.PointingHandCursor
                                function applyAppVol(mx) {
                                    const pct = Math.max(0, Math.min(100, Math.round((mx / Math.max(1, appTrack.width - 38)) * 100)))
                                    appTrack.localVol = pct
                                    SystemState.setAppVolume(appTrack.modelData.id, pct)
                                }
                                onPressed: function(m) { applyAppVol(m.x) }
                                onPositionChanged: function(m) { if (pressed) applyAppVol(m.x) }
                            }
                        }
                    }
                }
            }
        }
    }
}
