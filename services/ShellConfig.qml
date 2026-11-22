pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Persistent Shell Settings & Desktop Widget Layout Manager.
 * Reads & writes ~/.config/quickshell/AruShell/settings.json.
 */
Singleton {
    id: root

    // UI Overlay States
    property bool settingsOpen: false
    property bool editMode: false
    property bool desktopMenuOpen: false
    property real desktopMenuX: 200
    property real desktopMenuY: 200

    // Desktop Widget Positions & Visibility
    property real clockOffsetX: 0
    property real clockOffsetY: 0
    property bool clockVisible: true

    property real stageOffsetX: 0
    property real stageOffsetY: 0
    property bool stageVisible: true

    // Appearance
    property string fontFamily: "Google Sans"
    property bool clock24h: true
    property string accentOverride: "" // "" = dynamic from album art / wallpaper
    property bool darkTheme: true
    property real panelOpacity: 0.92
    property string wallpaperPath: ""
    property var wallpaperDirs: []
    property string launcherShape: "ghost"
    property string launcherImagePath: ""
    property string notifShape: "gem"

    // Behavior & Modules
    property bool videoWallpaperEnabled: true
    property bool videoEmptyDesktopOnly: true
    property bool dockPinned: false
    property bool islandAutoClose: true
    property int toastDurationMs: 3000
    property bool osdEnabled: true
    property bool showWeatherInIsland: true
    property string musicClientMode: "auto"
    property string musicCustomClient: ""
    property var qsItems: ["wifi", "bt", "nightLight", "powerProfile", "volume", "brightness", "modes", "actions"]
    property var pillItems: ["wifi", "bt", "volume", "battery"]
    property var qsWideItems: []
    property int qsWidth: 360
    property int qsTileHeight: 58
    property int qsSpacing: 12
    property int pillIconSize: 16
    property int pillSpacing: 10
    property int pillPadding: 24
    property var recentApps: []
    property bool hudFromAlbum: true
    property bool hyprDynamicBorders: true
    property bool blurTiledBg: true
    property bool kittyAutoFont: true

    function recordRecentApp(appKey) {
        const k = String(appKey || "").trim()
        if (!k) return
        const list = (recentApps || []).filter(function(x) { return x !== k })
        list.unshift(k)
        recentApps = list.slice(0, 8)
        save()
    }

    readonly property string settingsPath: Qt.resolvedUrl("../settings.json").toString().replace("file://", "")
    property bool _loaded: false

    function openDesktopMenu(mx, my) {
        desktopMenuX = mx
        desktopMenuY = my
        desktopMenuOpen = true
        NotifState.closeAllPopups()
        SystemState.quickSettingsOpen = false
        SystemState.launcherOpen = false
        ClipboardState.open = false
    }

    function closeDesktopMenu() {
        desktopMenuOpen = false
    }

    function openSettings() {
        desktopMenuOpen = false
        editMode = false
        NotifState.closeAllPopups()
        SystemState.quickSettingsOpen = false
        SystemState.launcherOpen = false
        ClipboardState.open = false
        settingsOpen = true
    }

    function toggleSettings() {
        if (settingsOpen) settingsOpen = false
        else openSettings()
    }


    function hasQsItem(id) {
        return (qsItems || []).indexOf(id) !== -1
    }

    function toggleQsItem(id) {
        const list = (qsItems || []).slice()
        const idx = list.indexOf(id)
        if (idx !== -1) {
            if (list.length <= 1) return
            list.splice(idx, 1)
        } else {
            list.push(id)
        }
        qsItems = list
        save()
    }


    function isQsWide(id) {
        return (qsWideItems || []).indexOf(id) !== -1
    }

    function toggleQsWide(id) {
        const list = (qsWideItems || []).slice()
        const idx = list.indexOf(id)
        if (idx !== -1) list.splice(idx, 1)
        else list.push(id)
        qsWideItems = list
        save()
    }

    function resetQsLayout() {
        qsItems = ["wifi", "bt", "nightLight", "powerProfile", "volume", "brightness", "modes", "actions"]
        pillItems = ["wifi", "bt", "volume", "battery"]
        qsWideItems = []
        qsWidth = 360
        qsTileHeight = 58
        qsSpacing = 12
        pillIconSize = 16
        pillSpacing = 10
        pillPadding = 24
        save()
    }

    function hasPillItem(id) {
        return (pillItems || []).indexOf(id) !== -1
    }

    function togglePillItem(id) {
        const list = (pillItems || []).slice()
        const idx = list.indexOf(id)
        if (idx !== -1) {
            if (list.length <= 1) return
            list.splice(idx, 1)
        } else {
            list.push(id)
        }
        pillItems = list
        save()
    }

    function resetWidgetPositions() {
        clockOffsetX = 0
        clockOffsetY = 0
        stageOffsetX = 0
        stageOffsetY = 0
        clockVisible = true
        stageVisible = true
        save()
    }

    function applyToServices() {
        MusicState.fontUi = fontFamily
        MusicState.fontClock = fontFamily
        MusicState.clock24h = clock24h
        MusicState.videoWallpaperEnabled = videoWallpaperEnabled
        MusicState.dockPinned = dockPinned
    }

    function save() {
        if (!_loaded) return
        applyToServices()
        const payload = JSON.stringify({
            clockOffsetX: Math.round(clockOffsetX),
            clockOffsetY: Math.round(clockOffsetY),
            clockVisible: clockVisible,
            stageOffsetX: Math.round(stageOffsetX),
            stageOffsetY: Math.round(stageOffsetY),
            stageVisible: stageVisible,
            fontFamily: fontFamily,
            clock24h: clock24h,
            accentOverride: accentOverride,
            darkTheme: darkTheme,
            panelOpacity: Number(panelOpacity.toFixed(2)),
            wallpaperPath: wallpaperPath,
            wallpaperDirs: wallpaperDirs,
            launcherShape: launcherShape,
            launcherImagePath: launcherImagePath,
            notifShape: notifShape,
            videoWallpaperEnabled: videoWallpaperEnabled,
            videoEmptyDesktopOnly: videoEmptyDesktopOnly,
            dockPinned: dockPinned,
            islandAutoClose: islandAutoClose,
            toastDurationMs: toastDurationMs,
            osdEnabled: osdEnabled,
            showWeatherInIsland: showWeatherInIsland,
            musicClientMode: musicClientMode,
            musicCustomClient: musicCustomClient,
            qsItems: qsItems,
            pillItems: pillItems,
            qsWideItems: qsWideItems,
            qsWidth: qsWidth,
            qsTileHeight: qsTileHeight,
            qsSpacing: qsSpacing,
            pillIconSize: pillIconSize,
            pillSpacing: pillSpacing,
            pillPadding: pillPadding,
            recentApps: recentApps,
            hudFromAlbum: hudFromAlbum,
            hyprDynamicBorders: hyprDynamicBorders,
            blurTiledBg: blurTiledBg,
            kittyAutoFont: kittyAutoFont
        }, null, 2)
        Quickshell.execDetached(["python3", "-c", "import sys; open(sys.argv[1], 'w', encoding='utf-8').write(sys.argv[2])", settingsPath, payload])
    }

    function load() {
        loadProc.command = ["bash", "-c", "cat " + JSON.stringify(settingsPath) + " 2>/dev/null || echo '{}'"]
        loadProc.running = true
    }


    function browseLauncherImage() {
        if (imgBrowseProc.running) return
        imgBrowseProc.command = ["bash", "-c",
            "if command -v zenity >/dev/null 2>&1; then zenity --file-selection --title='Выберите иконку меню приложений' --file-filter='Изображения | *.png *.jpg *.jpeg *.webp *.svg *.gif' 2>/dev/null; " +
            "elif command -v kdialog >/dev/null 2>&1; then kdialog --getopenfilename \"$HOME\" '*.png *.jpg *.jpeg *.webp *.svg *.gif' 2>/dev/null; " +
            "else echo ''; fi"
        ]
        imgBrowseProc.running = true
    }

    Process {
        id: imgBrowseProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                const p = line.trim()
                if (p !== "") {
                    root.launcherImagePath = p
                    root.save()
                }
            }
        }
    }

    Component.onCompleted: load()

    Process {
        id: loadProc
        property string buf: ""
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) { loadProc.buf += line + "\n" }
        }
        onExited: {
            try {
                const d = JSON.parse(loadProc.buf || "{}")
                if (d.clockOffsetX !== undefined) root.clockOffsetX = Number(d.clockOffsetX)
                if (d.clockOffsetY !== undefined) root.clockOffsetY = Number(d.clockOffsetY)
                if (d.clockVisible !== undefined) root.clockVisible = !!d.clockVisible
                if (d.stageOffsetX !== undefined) root.stageOffsetX = Number(d.stageOffsetX)
                if (d.stageOffsetY !== undefined) root.stageOffsetY = Number(d.stageOffsetY)
                if (d.stageVisible !== undefined) root.stageVisible = !!d.stageVisible
                if (d.fontFamily) root.fontFamily = String(d.fontFamily)
                if (d.clock24h !== undefined) root.clock24h = !!d.clock24h
                if (d.accentOverride !== undefined) root.accentOverride = String(d.accentOverride)
                if (d.darkTheme !== undefined) root.darkTheme = !!d.darkTheme
                if (d.panelOpacity !== undefined) root.panelOpacity = Math.max(0.65, Math.min(1.0, Number(d.panelOpacity)))
                if (d.wallpaperPath !== undefined) root.wallpaperPath = String(d.wallpaperPath)
                if (Array.isArray(d.wallpaperDirs)) root.wallpaperDirs = d.wallpaperDirs
                if (d.launcherShape) root.launcherShape = String(d.launcherShape)
                if (d.launcherImagePath !== undefined) root.launcherImagePath = String(d.launcherImagePath)
                if (d.notifShape) root.notifShape = String(d.notifShape)
                if (d.videoWallpaperEnabled !== undefined) root.videoWallpaperEnabled = !!d.videoWallpaperEnabled
                if (d.videoEmptyDesktopOnly !== undefined) root.videoEmptyDesktopOnly = !!d.videoEmptyDesktopOnly
                if (d.dockPinned !== undefined) root.dockPinned = !!d.dockPinned
                if (d.islandAutoClose !== undefined) root.islandAutoClose = !!d.islandAutoClose
                if (d.toastDurationMs !== undefined) root.toastDurationMs = Math.max(1500, Math.min(8000, Number(d.toastDurationMs)))
                if (d.osdEnabled !== undefined) root.osdEnabled = !!d.osdEnabled
                if (d.showWeatherInIsland !== undefined) root.showWeatherInIsland = !!d.showWeatherInIsland
                if (d.musicClientMode !== undefined) root.musicClientMode = String(d.musicClientMode)
                if (d.musicCustomClient !== undefined) root.musicCustomClient = String(d.musicCustomClient)
                if (Array.isArray(d.qsItems) && d.qsItems.length > 0) root.qsItems = d.qsItems
                if (Array.isArray(d.pillItems) && d.pillItems.length > 0) root.pillItems = d.pillItems
                if (Array.isArray(d.qsWideItems)) root.qsWideItems = d.qsWideItems
                if (d.qsWidth !== undefined) root.qsWidth = Math.max(300, Math.min(460, Number(d.qsWidth)))
                if (d.qsTileHeight !== undefined) root.qsTileHeight = Math.max(46, Math.min(82, Number(d.qsTileHeight)))
                if (d.qsSpacing !== undefined) root.qsSpacing = Math.max(6, Math.min(20, Number(d.qsSpacing)))
                if (d.pillIconSize !== undefined) root.pillIconSize = Math.max(13, Math.min(22, Number(d.pillIconSize)))
                if (d.pillSpacing !== undefined) root.pillSpacing = Math.max(6, Math.min(20, Number(d.pillSpacing)))
                if (d.pillPadding !== undefined) root.pillPadding = Math.max(16, Math.min(48, Number(d.pillPadding)))
                if (Array.isArray(d.recentApps)) root.recentApps = d.recentApps
                if (d.hudFromAlbum !== undefined) root.hudFromAlbum = !!d.hudFromAlbum
                if (d.hyprDynamicBorders !== undefined) root.hyprDynamicBorders = !!d.hyprDynamicBorders
                if (d.blurTiledBg !== undefined) root.blurTiledBg = !!d.blurTiledBg
                if (d.kittyAutoFont !== undefined) root.kittyAutoFont = !!d.kittyAutoFont
            } catch (e) {}
            loadProc.buf = ""
            root._loaded = true
            root.applyToServices()
        }
    }
}
