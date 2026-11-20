pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Persistent Shell Settings & Desktop Widget Layout Manager.
 * Reads & writes ~/.config/quickshell/ambient-music-shell/settings.json.
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
    property string accentOverride: "" // "" = dynamic from album art
    property string launcherShape: "ghost"
    property string notifShape: "gem"

    // Behavior & Modules
    property bool videoWallpaperEnabled: true
    property bool videoEmptyDesktopOnly: true
    property bool dockPinned: false
    property bool islandAutoClose: true
    property int toastDurationMs: 3000
    property bool osdEnabled: true
    property bool showWeatherInIsland: true

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
        if (accentOverride !== "") {
            MusicState.accentColor = accentOverride
        }
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
            launcherShape: launcherShape,
            notifShape: notifShape,
            videoWallpaperEnabled: videoWallpaperEnabled,
            videoEmptyDesktopOnly: videoEmptyDesktopOnly,
            dockPinned: dockPinned,
            islandAutoClose: islandAutoClose,
            toastDurationMs: toastDurationMs,
            osdEnabled: osdEnabled,
            showWeatherInIsland: showWeatherInIsland
        }, null, 2)
        Quickshell.execDetached(["python3", "-c", "import sys; open(sys.argv[1], 'w', encoding='utf-8').write(sys.argv[2])", settingsPath, payload])
    }

    function load() {
        loadProc.command = ["bash", "-c", "cat " + JSON.stringify(settingsPath) + " 2>/dev/null || echo '{}'"]
        loadProc.running = true
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
                if (d.launcherShape) root.launcherShape = String(d.launcherShape)
                if (d.notifShape) root.notifShape = String(d.notifShape)
                if (d.videoWallpaperEnabled !== undefined) root.videoWallpaperEnabled = !!d.videoWallpaperEnabled
                if (d.videoEmptyDesktopOnly !== undefined) root.videoEmptyDesktopOnly = !!d.videoEmptyDesktopOnly
                if (d.dockPinned !== undefined) root.dockPinned = !!d.dockPinned
                if (d.islandAutoClose !== undefined) root.islandAutoClose = !!d.islandAutoClose
                if (d.toastDurationMs !== undefined) root.toastDurationMs = Math.max(1500, Math.min(8000, Number(d.toastDurationMs)))
                if (d.osdEnabled !== undefined) root.osdEnabled = !!d.osdEnabled
                if (d.showWeatherInIsland !== undefined) root.showWeatherInIsland = !!d.showWeatherInIsland
            } catch (e) {}
            loadProc.buf = ""
            root._loaded = true
            root.applyToServices()
        }
    }
}
