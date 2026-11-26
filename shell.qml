//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "./services"
import "./components"

ShellRoot {
    id: shellRoot

    Loader {
        id: audioLoader
        active: MusicState.inAppPlayback
        source: "components/AudioPlayerCore.qml"
    }

    // DarkShadowShell-style Frozen-Screen Screenshot Overlay
    Loader {
        id: screenshotLoader
        active: ScreenshotState.active
        source: "components/ScreenshotOverlay.qml"
    }

    Loader {
        id: settingsLoader
        active: ShellConfig.settingsOpen
        source: "components/SettingsWindow.qml"
    }

    Loader {
        id: wallpaperLoader
        active: WallpaperState.open
        source: "components/WallpaperCarousel.qml"
    }

    Loader {
        id: globeLoader
        active: GlobeSearchState.open
        source: "components/GlobeSearchOverlay.qml"
    }

    // Caelestia-style Native Wayland Lock Screen (lazy-loaded: 0 VRAM/GPU cost when unlocked)
    Loader {
        id: lockLoader
        active: LockState.locked || LockState.unlocking
        source: "components/LockScreen.qml"
    }

    // Global IPC for Hyprland keybinds:
    //   quickshell ipc -c AruShell call screenshot open
    //   quickshell ipc -c AruShell call screenshot full
    IpcHandler {
        target: "screenshot"
        function open(): void { ScreenshotState.open("region") }
        function region(): void { ScreenshotState.open("region") }
        function window(): void { ScreenshotState.open("window") }
        function screen(): void { ScreenshotState.open("screen") }
        function full(): void { ScreenshotState.captureFullNow() }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { SystemState.toggleLauncher() }
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void { ClipboardState.toggle() }
    }

    IpcHandler {
        target: "settings"
        function toggle(): void { ShellConfig.toggleSettings() }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void { WallpaperState.toggle() }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { LockState.lock() }
    }

    IpcHandler {
        target: "globe"
        function toggle(): void { GlobeSearchState.toggle() }
    }

    // =========================================================================
    // 1. Desktop Layer (Live Video + Material You Clock + Album Card + Lyrics)
    // =========================================================================
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            WlrLayershell.layer: MusicState.layerMode === "background" ? WlrLayer.Background : WlrLayer.Bottom
            WlrLayershell.namespace: "arushell"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            VideoBackdrop {
                id: liveBackdrop
                monitorScreen: modelData
                anchors.fill: parent
                z: 0
            }

            AudioVisualizer {
                z: 4
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                z: 1
                onClicked: function(mouse) {
                    if (mouse.button === Qt.RightButton) {
                        ShellConfig.openDesktopMenu(mouse.x, mouse.y)
                        return
                    }
                    ShellConfig.closeDesktopMenu()
                    MusicState.platformMenuOpen = false
                    MusicState.searchOpen = false
                    NotifState.closeAllPopups()
                    SystemState.quickSettingsOpen = false
                    SystemState.launcherOpen = false
                    ClipboardState.open = false
                }
            }

            // Draggable Desktop Clock Widget
            Item {
                id: clockContainer
                visible: ShellConfig.clockVisible
                width: clockWidget.implicitWidth + 24
                height: clockWidget.implicitHeight + 16
                x: Math.round((parent.width - width) / 2 + ShellConfig.clockOffsetX)
                y: Math.round(20 + MusicState.topBarMargin + ShellConfig.clockOffsetY)
                z: 6

                Rectangle {
                    anchors.fill: parent
                    radius: 22
                    visible: ShellConfig.editMode
                    color: Qt.rgba(MusicState.m3Primary.r, MusicState.m3Primary.g, MusicState.m3Primary.b, 0.14)
                    border.width: 2
                    border.color: MusicState.m3Primary
                }

                TopClock {
                    id: clockWidget
                    anchors.centerIn: parent
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: ShellConfig.editMode
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    property real startX: 0
                    property real startY: 0
                    property real origOffX: 0
                    property real origOffY: 0
                    onPressed: function(mouse) {
                        const pt = mapToItem(parent.parent, mouse.x, mouse.y)
                        startX = pt.x; startY = pt.y
                        origOffX = ShellConfig.clockOffsetX; origOffY = ShellConfig.clockOffsetY
                    }
                    onPositionChanged: function(mouse) {
                        if (!pressed) return
                        const pt = mapToItem(parent.parent, mouse.x, mouse.y)
                        ShellConfig.clockOffsetX = origOffX + (pt.x - startX)
                        ShellConfig.clockOffsetY = origOffY + (pt.y - startY)
                    }
                    onReleased: ShellConfig.save()
                }
            }

            // Draggable Desktop Music Stage (auto-hides cleanly when music is NOT playing!)
            Item {
                id: musicStage
                readonly property bool _minimized: MusicState.stageMinimizedToIsland && !ShellConfig.editMode
                readonly property bool _hasStage: ShellConfig.stageVisible && (MusicState.hasTrack || ShellConfig.editMode)
                readonly property real _restY: Math.round((parent.height - height) / 2 + 38 + ShellConfig.stageOffsetY)

                // Telegram-style liquid suction progress (0.0 = desktop center, 1.0 = absorbed inside Dynamic Island)
                property real suction: _minimized ? 1.0 : 0.0
                Behavior on suction {
                    NumberAnimation {
                        duration: 580
                        easing.type: Easing.InOutQuart
                    }
                }

                // Droplet stretch factor peaks mid-flight (sin(pi * suction))
                readonly property real _stretch: Math.sin(Math.PI * suction)
                readonly property real _xScale: Math.max(0.05, 1.0 - suction * 0.94 - _stretch * 0.14)
                readonly property real _yScale: Math.max(0.05, 1.0 - suction * 0.92 + _stretch * 0.18)

                opacity: !_hasStage ? 0.0 : (suction < 0.68 ? 1.0 : Math.max(0.0, 1.0 - (suction - 0.68) / 0.30))
                visible: opacity > 0.01
                Behavior on opacity { enabled: !_minimized; M3Anim { duration: 320 } }

                width: parent.width
                height: 400
                x: Math.round(ShellConfig.stageOffsetX)
                y: Math.round(_restY * (1.0 - suction) + 10 * suction)
                z: 5

                transform: Scale {
                    origin.x: musicStage.width / 2
                    origin.y: 0
                    xScale: musicStage._xScale
                    yScale: musicStage._yScale
                }

                readonly property bool hasLyrics: MusicState.lyricsLines && MusicState.lyricsLines.length > 0
                readonly property real gap: 48
                readonly property real combinedWidth: albumCardItem.width + gap + lyricsViewItem.width

                AlbumCard {
                    id: albumCardItem
                    anchors.verticalCenter: parent.verticalCenter
                    x: musicStage.hasLyrics
                        ? Math.round((musicStage.width - musicStage.combinedWidth) / 2)
                        : Math.round((musicStage.width - width) / 2)

                    Behavior on x { M3Anim { duration: 520 } }
                }

                // Edit-Mode Drag Overlay (sibling of AlbumCard so Column layout is NEVER disturbed!)
                Rectangle {
                    visible: ShellConfig.editMode
                    x: albumCardItem.x - 10
                    y: albumCardItem.y - 10
                    width: musicStage.hasLyrics ? (musicStage.combinedWidth + 20) : (albumCardItem.width + 20)
                    height: Math.max(albumCardItem.height, lyricsViewItem.height) + 20
                    radius: 30
                    color: Qt.rgba(MusicState.m3Primary.r, MusicState.m3Primary.g, MusicState.m3Primary.b, 0.12)
                    border.width: 2
                    border.color: MusicState.m3Primary
                    z: 20

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        property real startX: 0
                        property real startY: 0
                        property real origOffX: 0
                        property real origOffY: 0
                        onPressed: function(mouse) {
                            const pt = mapToItem(musicStage.parent, mouse.x, mouse.y)
                            startX = pt.x; startY = pt.y
                            origOffX = ShellConfig.stageOffsetX; origOffY = ShellConfig.stageOffsetY
                        }
                        onPositionChanged: function(mouse) {
                            if (!pressed) return
                            const pt = mapToItem(musicStage.parent, mouse.x, mouse.y)
                            ShellConfig.stageOffsetX = origOffX + (pt.x - startX)
                            ShellConfig.stageOffsetY = origOffY + (pt.y - startY)
                        }
                        onReleased: ShellConfig.save()
                    }
                }

                LyricsView {
                    id: lyricsViewItem
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.round((musicStage.width - musicStage.combinedWidth) / 2) + albumCardItem.width + musicStage.gap + (musicStage.hasLyrics ? 0 : 28)
                    opacity: musicStage.hasLyrics ? 1.0 : 0.0
                    visible: opacity > 0.01

                    Behavior on x       { M3Anim { duration: 520 } }
                    Behavior on opacity { M3Anim { duration: 380 } }
                }
            }

            // Floating Edit-Mode Banner Pill
            Rectangle {
                visible: ShellConfig.editMode
                anchors {
                    top: parent.top
                    horizontalCenter: parent.horizontalCenter
                    topMargin: 58
                }
                height: 42
                width: editBarRow.implicitWidth + 24
                radius: 21
                color: MusicState.m3SurfaceContainer
                z: 25

                Row {
                    id: editBarRow
                    anchors.centerIn: parent
                    spacing: 10

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Перетаскивайте виджеты на рабочем столе"
                        color: MusicState.m3OnSurface
                        font.family: MusicState.fontUi
                        font.pixelSize: 12
                        font.weight: Font.SemiBold
                    }

                    Rectangle {
                        height: 28; width: rstTxt.implicitWidth + 18; radius: 14
                        anchors.verticalCenter: parent.verticalCenter
                        color: MusicState.m3SurfaceContainerHigh
                        Text { id: rstTxt; anchors.centerIn: parent; text: "Сбросить"; color: MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.SemiBold }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ShellConfig.resetWidgetPositions() }
                    }

                    Rectangle {
                        height: 28; width: dnTxt.implicitWidth + 18; radius: 14
                        anchors.verticalCenter: parent.verticalCenter
                        color: MusicState.m3Primary
                        Text { id: dnTxt; anchors.centerIn: parent; text: "Готово"; color: MusicState.m3OnPrimary; font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ShellConfig.editMode = false; ShellConfig.save() } }
                    }
                }
            }

            // Right-Click Desktop Context Menu
            DesktopContextMenu {
                z: 30
            }
        }
    }

    // =========================================================================
    // 2. Full-Width Top Bar (FIXED GPU surface + Wayland Region mask -> 120Hz silky!)
    //    Never resizes wl_surface during animations (same technique as Caelestia & end-4)
    // =========================================================================
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: topBarWin
            required property var modelData
            screen: modelData

            readonly property bool anyTopPopupOpen: NotifState.centerOpen || SystemState.quickSettingsOpen || SystemState.langMenuOpen || SystemState.launcherOpen || ClipboardState.open

            anchors {
                top: true
                left: true
                right: true
            }

            // Constant height: zero Wayland surface reallocations during animations!
            implicitHeight: 740
            exclusiveZone: 48
            exclusionMode: ExclusionMode.Normal

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "arushell-topbar"
            WlrLayershell.keyboardFocus: (topBarWin.anyTopPopupOpen || SystemState.wifiPasswordTarget !== "") ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            color: "transparent"

            // Input mask: only captures clicks in top 48px strip + exact Dynamic Island / Toast rect (never blocks sides!)
            mask: Region {
                item: topInputZone
                regions: [
                    Region {
                        item: islandMaskZone
                    }
                ]
            }

            Item {
                id: topInputZone
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: topBarWin.anyTopPopupOpen ? parent.height : 48
            }

            Item {
                id: islandMaskZone
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: parent.top
                    topMargin: 6
                }
                width: (NotifState.islandExpanded || NotifState.activeToast !== null) ? topBarItem.islandHitWidth : 0
                height: (NotifState.islandExpanded || NotifState.activeToast !== null) ? topBarItem.islandHitHeight : 0
            }

            Item {
                id: topPopupEscCatcher
                focus: (SystemState.quickSettingsOpen || NotifState.centerOpen || SystemState.langMenuOpen) && SystemState.wifiPasswordTarget === ""
                Keys.onEscapePressed: {
                    SystemState.quickSettingsOpen = false
                    SystemState.quickSettingsSubmenu = ""
                    NotifState.centerOpen = false
                    SystemState.langMenuOpen = false
                }
            }

            TopBar {
                id: topBarItem
                parentPanel: topBarWin
            }
        }
    }

    // =========================================================================
    // 3. Auto-Hiding / Pinnable Bottom Dock (FIXED GPU surface + Region mask -> 120Hz silky!)
    // =========================================================================
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dockWin
            required property var modelData
            screen: modelData

            property bool hovered: false
            readonly property bool dockVisible: MusicState.dockPinned || hovered || MusicState.searchOpen || MusicState.platformMenuOpen

            anchors {
                bottom: true
                left: true
                right: true
            }

            // Constant height: zero Wayland surface reallocations during slide-in/out!
            implicitHeight: 540

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "arushell-dock"
            WlrLayershell.keyboardFocus: MusicState.searchOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            // Input mask: thin 8px edge strip when hidden, dock height when shown, full area when search/menu open!
            mask: Region {
                item: dockInputZone
            }

            Item {
                id: dockInputZone
                anchors {
                    bottom: parent.bottom
                    left: parent.left
                    right: parent.right
                }
                height: (MusicState.searchOpen || MusicState.platformMenuOpen)
                    ? parent.height
                    : (dockWin.dockVisible ? 98 : 8)

                HoverHandler {
                    id: dockHover
                    onHoveredChanged: dockWin.updateDockHover()
                }
            }

            function updateDockHover() {
                if (dockHover.hovered || dockItemHover.hovered) {
                    hideDelay.stop()
                    dockWin.hovered = true
                } else {
                    hideDelay.restart()
                }
            }

            Timer {
                id: hideDelay
                interval: 520
                repeat: false
                onTriggered: {
                    if (!dockHover.hovered && !dockItemHover.hovered) {
                        dockWin.hovered = false
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: MusicState.searchOpen || MusicState.platformMenuOpen
                onClicked: {
                    MusicState.searchOpen = false
                    MusicState.platformMenuOpen = false
                }
            }

            SearchOverlay {
                anchors {
                    bottom: dockItem.top
                    horizontalCenter: parent.horizontalCenter
                    bottomMargin: 12
                }
                z: 20
            }

            PlatformMenu {
                anchors {
                    bottom: dockItem.top
                    horizontalCenter: dockItem.horizontalCenter
                    bottomMargin: 12
                }
                z: 25
            }

            ControlDock {
                id: dockItem
                anchors.horizontalCenter: parent.horizontalCenter
                y: dockWin.dockVisible ? (dockWin.height - height - 14) : (dockWin.height + 16)
                opacity: dockWin.dockVisible ? 1.0 : 0.0
                z: 15

                Behavior on y { M3Anim { duration: 380 } }
                Behavior on opacity { M3Anim { duration: 280 } }

                // Passive HoverHandler stays true even over child MouseAreas (icons/buttons) so dock never runs away!
                HoverHandler {
                    id: dockItemHover
                    onHoveredChanged: dockWin.updateDockHover()
                }
            }
        }
    }

    // =========================================================================
    // 4. Floating Wavy OSD Indicator (Volume / Brightness / Keyboard Layout)
    //    Empty Region mask so it NEVER intercepts mouse clicks!
    // =========================================================================
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            anchors {
                bottom: true
                left: true
                right: true
            }
            implicitHeight: 160
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            visible: ShellConfig.osdEnabled && SystemState.osdVisible
            WlrLayershell.namespace: "arushell-osd"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            color: "transparent"

            mask: Region {}

            OsdPill {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 96
            }
        }
    }
}
