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
    property var pillItems: ["wifi", "bt", "volume", "battery"]
    property var qsGridLayout: [
        { id: "wifi",       col: 0, row: 0, w: 2, h: 1 },
        { id: "bt",         col: 2, row: 0, w: 2, h: 1 },
        { id: "audio",      col: 0, row: 1, w: 2, h: 1 },
        { id: "power",      col: 2, row: 1, w: 2, h: 1 },
        { id: "night",      col: 0, row: 2, w: 1, h: 1 },
        { id: "dnd",        col: 1, row: 2, w: 1, h: 1 },
        { id: "game",       col: 2, row: 2, w: 1, h: 1 },
        { id: "awake",      col: 3, row: 2, w: 1, h: 1 },
        { id: "volume",     col: 0, row: 3, w: 4, h: 1 },
        { id: "screenshot", col: 0, row: 4, w: 2, h: 1 },
        { id: "clipboard",  col: 2, row: 4, w: 1, h: 1 },
        { id: "wallpaper",  col: 3, row: 4, w: 1, h: 1 }
    ]

    function _overlaps(a, b) {
        return !(a.col + a.w <= b.col || b.col + b.w <= a.col || a.row + a.h <= b.row || b.row + b.h <= a.row)
    }

    function _findFreeSpot(list, w, h, ignoreId) {
        for (let r = 0; r < 10; r++) {
            for (let c = 0; c <= 4 - w; c++) {
                const cand = { col: c, row: r, w: w, h: h }
                let hit = false
                for (let i = 0; i < list.length; i++) {
                    if (list[i].id === ignoreId) continue
                    if (_overlaps(cand, list[i])) { hit = true; break }
                }
                if (!hit) return { col: c, row: r }
            }
        }
        return { col: 0, row: 5 }
    }

    function updateGridTile(id, col, row, w, h) {
        const list = (qsGridLayout || []).map(function(t) { return Object.assign({}, t) })
        let target = null
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === id) { target = list[i]; break }
        }
        if (!target) return
        const oldPos = { col: target.col, row: target.row }
        target.w = Math.max(1, Math.min(4, Math.round(w)))
        target.h = Math.max(1, Math.min(2, Math.round(h)))
        target.col = Math.max(0, Math.min(4 - target.w, Math.round(col)))
        target.row = Math.max(0, Math.min(7 - target.h, Math.round(row)))

        // Push any colliding tiles to old position or next free slot
        for (let i = 0; i < list.length; i++) {
            const other = list[i]
            if (other.id === id) continue
            if (_overlaps(target, other)) {
                const tryOld = { col: Math.min(4 - other.w, oldPos.col), row: oldPos.row, w: other.w, h: other.h }
                let oldBlocked = _overlaps(target, tryOld)
                if (!oldBlocked) {
                    for (let j = 0; j < list.length; j++) {
                        if (list[j].id !== id && list[j].id !== other.id && _overlaps(tryOld, list[j])) { oldBlocked = true; break }
                    }
                }
                if (!oldBlocked) {
                    other.col = tryOld.col
                    other.row = tryOld.row
                } else {
                    const spot = _findFreeSpot(list, other.w, other.h, other.id)
                    other.col = spot.col
                    other.row = spot.row
                }
            }
        }
        qsGridLayout = list
        save()
    }

    function removeGridTile(id) {
        const list = (qsGridLayout || []).filter(function(t) { return t && t.id !== id })
        if (list.length < 1) return
        qsGridLayout = list
        save()
    }

    function addGridTile(id, defW, defH) {
        const list = (qsGridLayout || []).map(function(t) { return Object.assign({}, t) })
        for (let i = 0; i < list.length; i++) if (list[i].id === id) return
        const w = defW || 1
        const h = defH || 1
        const spot = _findFreeSpot(list, w, h, "")
        list.push({ id: id, col: spot.col, row: spot.row, w: w, h: h })
        qsGridLayout = list
        save()
    }

    function resetQsGrid() {
        qsGridLayout = [
            { id: "wifi",       col: 0, row: 0, w: 2, h: 1 },
            { id: "bt",         col: 2, row: 0, w: 2, h: 1 },
            { id: "audio",      col: 0, row: 1, w: 2, h: 1 },
            { id: "power",      col: 2, row: 1, w: 2, h: 1 },
            { id: "night",      col: 0, row: 2, w: 1, h: 1 },
            { id: "dnd",        col: 1, row: 2, w: 1, h: 1 },
            { id: "game",       col: 2, row: 2, w: 1, h: 1 },
            { id: "awake",      col: 3, row: 2, w: 1, h: 1 },
            { id: "volume",     col: 0, row: 3, w: 4, h: 1 },
            { id: "screenshot", col: 0, row: 4, w: 2, h: 1 },
            { id: "clipboard",  col: 2, row: 4, w: 1, h: 1 },
            { id: "wallpaper",  col: 3, row: 4, w: 1, h: 1 }
        ]
        save()
    }
    // QuickSettings grid dimensions are managed dynamically by qsGridLayout
    property int pillIconSize: 16
    property int pillSpacing: 10
    property int pillPadding: 24
    property var recentApps: []
    property bool hudFromAlbum: true
    property bool hyprDynamicBorders: true
    property bool blurTiledBg: true
    property bool kittyAutoFont: true
    property bool syncSystemTheme: true
    property bool inhibitWhenAudio: true
    property bool audioVisualizer: false
    property bool visFullWidth: true
    property int visBars: 48
    property int visHeight: 84
    property int visSpacing: 4
    property string visStyle: "bars"
    property string hyprAnimStyle: "smooth"
    property string hyprAnimWinStyle: "popin"
    property string hyprAnimWsStyle: "slide"
    property real hyprAnimSpeed: 1.0

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



    function hasPillItem(id) {
        return (pillItems || []).indexOf(id) !== -1
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
            pillItems: pillItems,
            qsGridLayout: qsGridLayout,
            pillIconSize: pillIconSize,
            pillSpacing: pillSpacing,
            pillPadding: pillPadding,
            recentApps: recentApps,
            hudFromAlbum: hudFromAlbum,
            hyprDynamicBorders: hyprDynamicBorders,
            blurTiledBg: blurTiledBg,
            kittyAutoFont: kittyAutoFont,
            syncSystemTheme: syncSystemTheme,
            inhibitWhenAudio: inhibitWhenAudio,
            audioVisualizer: audioVisualizer,
            visFullWidth: visFullWidth,
            visBars: visBars,
            visHeight: visHeight,
            visSpacing: visSpacing,
            visStyle: visStyle,
            hyprAnimStyle: hyprAnimStyle,
            hyprAnimWinStyle: hyprAnimWinStyle,
            hyprAnimWsStyle: hyprAnimWsStyle,
            hyprAnimSpeed: Number(hyprAnimSpeed.toFixed(2))
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
                if (Array.isArray(d.pillItems) && d.pillItems.length > 0) root.pillItems = d.pillItems
                if (Array.isArray(d.qsGridLayout) && d.qsGridLayout.length > 0) root.qsGridLayout = d.qsGridLayout
                if (d.pillIconSize !== undefined) root.pillIconSize = Math.max(13, Math.min(22, Number(d.pillIconSize)))
                if (d.pillSpacing !== undefined) root.pillSpacing = Math.max(6, Math.min(20, Number(d.pillSpacing)))
                if (d.pillPadding !== undefined) root.pillPadding = Math.max(16, Math.min(48, Number(d.pillPadding)))
                if (Array.isArray(d.recentApps)) root.recentApps = d.recentApps
                if (d.hudFromAlbum !== undefined) root.hudFromAlbum = !!d.hudFromAlbum
                if (d.hyprDynamicBorders !== undefined) root.hyprDynamicBorders = !!d.hyprDynamicBorders
                if (d.blurTiledBg !== undefined) root.blurTiledBg = !!d.blurTiledBg
                if (d.kittyAutoFont !== undefined) root.kittyAutoFont = !!d.kittyAutoFont
                if (d.syncSystemTheme !== undefined) root.syncSystemTheme = !!d.syncSystemTheme
                if (d.inhibitWhenAudio !== undefined) root.inhibitWhenAudio = !!d.inhibitWhenAudio
                if (d.audioVisualizer !== undefined) root.audioVisualizer = !!d.audioVisualizer
                if (d.visFullWidth !== undefined) root.visFullWidth = !!d.visFullWidth
                if (d.visBars !== undefined) root.visBars = Math.max(16, Math.min(96, Number(d.visBars)))
                if (d.visHeight !== undefined) root.visHeight = Math.max(40, Math.min(200, Number(d.visHeight)))
                if (d.visSpacing !== undefined) root.visSpacing = Math.max(2, Math.min(12, Number(d.visSpacing)))
                if (d.visStyle) root.visStyle = String(d.visStyle)
                if (d.hyprAnimStyle) root.hyprAnimStyle = String(d.hyprAnimStyle)
                if (d.hyprAnimWinStyle) root.hyprAnimWinStyle = String(d.hyprAnimWinStyle)
                if (d.hyprAnimWsStyle) root.hyprAnimWsStyle = String(d.hyprAnimWsStyle)
                if (d.hyprAnimSpeed !== undefined) root.hyprAnimSpeed = Math.max(0.5, Math.min(2.0, Number(d.hyprAnimSpeed)))
            } catch (e) {}
            loadProc.buf = ""
            root._loaded = true
            root.applyToServices()
        }
    }
}
