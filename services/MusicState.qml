pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Wayland

Singleton {
    id: root

    readonly property string rootDir: Quickshell.shellDir
    readonly property string pythonBin: rootDir + "/.venv/bin/python3"
    readonly property string backendScript: rootDir + "/services/backend.py"

    // --- Config ---
    property string layerMode: "bottom"
    property int topBarMargin: 44
    property string selectedPlatform: "yandex"
    property bool inAppPlayback: true
    property bool videoWallpaperEnabled: true
    property string videoEngine: "qtmultimedia"
    property int videoRotation: 0
    property string fallbackVideoPath: ""
    property bool clock24h: false
    property string fontClock: "Google Sans"
    property string fontUi: "Google Sans"
    property bool dockPinned: false
    property var dockApps: ["kitty", "org.gnome.Nautilus", "firefox", "org.telegram.desktop", "steam", "yandex-music"]
    property string launcherCmd: ""

    // --- Built-in In-App Audio Player State ---
    property bool useInternalPlayer: false
    property string internalAudioUrl: ""
    property bool internalPlaying: false
    property real internalPosition: 0
    property real internalDuration: 0
    property var internalTrack: ({})
    signal internalPlayRequested(string url)
    signal internalToggleRequested()
    signal internalPauseRequested()
    signal internalSeekRequested(real seconds)

    // --- Live Video Backdrop State ---
    property string videoStreamUrl: ""
    property bool videoLoading: false

    // --- UI Overlay States ---
    property bool platformMenuOpen: false
    property bool stageMinimizedToIsland: false
    property bool searchOpen: false
    property string searchQuery: ""
    property bool searchLoading: false
    property var searchTracks: []
    property var searchArtists: []

    property string statusBannerText: ""
    property string statusBannerIcon: ""
    property color statusBannerColor: "#FFCC00"

    // --- Queue / History (used for Next/Prev in built-in player) ---
    property var queueItems: []

    // --- Synced Lyrics ---
    property var lyricsLines: []
    property bool lyricsSynced: false
    property string lyricsSource: ""
    // Thematic genre-adaptive typography fonts (Rap / Rock / Electronic / Soul)
    FontLoader { id: genreFontRap;  source: "../assets/fonts/BebasNeue-Regular.ttf" }
    FontLoader { id: genreFontRock; source: "../assets/fonts/InterDisplay-BlackItalic.otf" }
    FontLoader { id: genreFontElec; source: "../assets/fonts/URWGothic-Demi.otf" }
    FontLoader { id: genreFontSoul; source: "../assets/fonts/P052-BoldItalic.otf" }

    property string trackGenre: "pop"
    property string _pendingGenre: "pop"
    property real moodFontOpacity: 1.0
    property real moodFontScale: 1.0

    Behavior on moodFontOpacity { NumberAnimation { duration: 190; easing.type: Easing.InOutCubic } }
    Behavior on moodFontScale   { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

    Timer {
        id: genreSwapTimer
        interval: 195
        repeat: false
        onTriggered: {
            root.trackGenre = root._pendingGenre
            root.moodFontOpacity = 1.0
            root.moodFontScale = 1.0
        }
    }

    function setTrackGenreSmooth(nextGenre) {
        const g = String(nextGenre || "pop")
        if (g === trackGenre && !genreSwapTimer.running) return
        _pendingGenre = g
        moodFontOpacity = 0.0
        moodFontScale = 0.94
        genreSwapTimer.restart()
    }

    readonly property string trackMoodFont: {
        if (trackGenre === "rap" && genreFontRap.status === FontLoader.Ready) return genreFontRap.name
        if (trackGenre === "rock" && genreFontRock.status === FontLoader.Ready) return genreFontRock.name
        if (trackGenre === "electronic" && genreFontElec.status === FontLoader.Ready) return genreFontElec.name
        if (trackGenre === "soul" && genreFontSoul.status === FontLoader.Ready) return genreFontSoul.name
        return fontUi
    }
    readonly property bool trackMoodItalic: trackGenre === "soul" || trackGenre === "rock"
    readonly property real trackMoodSpacing: trackGenre === "rap" ? 1.8 : (trackGenre === "electronic" ? 1.1 : (trackGenre === "rock" ? 0.5 : 0.0))

    property int lyricsAltIndex: 0
    property int lyricsTotalVariants: 0
    property int currentLyricIndex: -1
    property bool lyricsLoading: false

    // Generation counters to drop stale async responses
    property int _lyricsGen: 0
    property int _lyricsActiveGen: 0
    property int _videoGen: 0
    property int _videoActiveGen: 0
    property int _searchGen: 0
    property int _searchActiveGen: 0

    readonly property var platforms: [
        { id: "yandex",        name: "Яндекс Музыка",     accent: "#FFCC00", icon: "../assets/icons/platform_yandex.svg",        match: ["yandex", "yamusic", "яндекс"] },
        { id: "apple",         name: "Apple Music",       accent: "#FA243C", icon: "../assets/icons/platform_apple.svg",         match: ["apple", "cider", "music.apple"] },
        { id: "spotify",       name: "Spotify",           accent: "#1DB954", icon: "../assets/icons/platform_spotify.svg",       match: ["spotify"] },
        { id: "spotify_web",   name: "Spotify Web Player",accent: "#1ED760", icon: "../assets/icons/platform_spotify.svg",       match: ["chromium", "firefox", "brave", "zen"] },
        { id: "youtube_music", name: "YouTube Music",     accent: "#FF0033", icon: "../assets/icons/platform_youtube_music.svg", match: ["youtube", "ytm", "pear", "chromium", "firefox"] },
        { id: "soundcloud",    name: "SoundCloud",        accent: "#FF5500", icon: "../assets/icons/platform_soundcloud.svg",    match: ["soundcloud", "chromium", "firefox"] },
        { id: "amazon",        name: "Amazon Music",      accent: "#00A8E1", icon: "../assets/icons/platform_amazon.svg",        match: ["amazon"] },
        { id: "automatic",     name: "Automatic",         accent: "#A855F7", icon: "../assets/icons/platform_auto.svg",          match: [] }
    ]

    function platformInfo(pid) {
        for (let i = 0; i < platforms.length; i++) {
            if (platforms[i].id === pid) return platforms[i]
        }
        return platforms[0]
    }

    readonly property var currentPlatformObj: platformInfo(selectedPlatform)

    readonly property var _hardBrowserBlocklist: [
        "firefox", "brave", "vivaldi", "opera", "zen", "librewolf",
        "edge", "floorp", "waterfox", "thorium", "kdeconnect"
    ]

    readonly property var _messengerBlocklist: [
        "telegram", "discord", "vesktop", "whatsapp", "slack",
        "element", "vk мессенджер", "google meet", "zoom"
    ]

    readonly property var _nativeClientKeys: ({
        "yandex":  ["yandex", "yamusic", "яндекс"],
        "spotify": ["spotify", "ncspot", "spotify_player", "spotifyd"],
        "apple":   ["cider", "apple-music", "applemusic"],
        "ytmusic": ["youtube-music", "ytmdesktop", "pear", "th-ch", "ytm"],
        "tidal":   ["tidal"],
        "deezer":  ["deezer"],
        "mpd":     ["mpd", "mpdris", "rhythmbox", "lollypop", "amberol", "elisa", "strawberry", "clementine", "audacious", "deadbeef", "cmus", "feishin", "supersonic", "g4music", "gapless", "harmonoid", "nuclear", "vlc"]
    })

    function _playerHay(pl) {
        return ((pl.identity || "") + " " + (pl.dbusName || "") + " " + (pl.desktopEntry || "")).toLowerCase()
    }

    function _matchesAnyKey(hay, keys) {
        for (let i = 0; i < keys.length; i++) {
            if (keys[i] && hay.indexOf(keys[i]) !== -1) return true
        }
        return false
    }

    function _isMessenger(pl) {
        const txt = ((pl.identity || "") + " " + (pl.trackTitle || "") + " " + (pl.desktopEntry || "")).toLowerCase()
        return _matchesAnyKey(txt, _messengerBlocklist)
    }

    function _isElectronMusicPlayer(pl) {
        const hay = _playerHay(pl)
        if (_matchesAnyKey(hay, _hardBrowserBlocklist) || _isMessenger(pl)) return false
        if (hay.indexOf("chromium") === -1 && hay.indexOf("electron") === -1) return false
        const art = String(pl.trackArtUrl || "").toLowerCase()
        const artist = String(pl.trackArtist || "").trim()
        const title = String(pl.trackTitle || "").trim()
        if (art.indexOf("yandex") !== -1 || art.indexOf("music") !== -1 || art.indexOf("spotify") !== -1) return true
        return artist !== "" && title !== ""
    }

    readonly property string detectedMprisList: {
        const list = Mpris.players.values
        if (!list || list.length === 0) return "нет активных"
        const names = []
        for (let i = 0; i < list.length; i++) {
            const p = list[i]
            const lbl = (p.identity || p.desktopEntry || p.dbusName || "unknown")
            if (names.indexOf(lbl) === -1) names.push(lbl)
        }
        return names.join(", ")
    }

    readonly property var activeMprisPlayer: {
        const list = Mpris.players.values
        if (!list || list.length === 0) return null

        const mode = ShellConfig.musicClientMode || "auto"

        if (mode === "custom") {
            const raw = (ShellConfig.musicCustomClient || "").trim().toLowerCase()
            if (!raw) return null
            const keys = raw.split(",").map(function(s) { return s.trim() }).filter(function(s) { return s.length > 0 })
            let fallback = null
            for (let i = 0; i < list.length; i++) {
                const pl = list[i]
                if (_matchesAnyKey(_playerHay(pl), keys)) {
                    if (pl.isPlaying) return pl
                    if (!fallback) fallback = pl
                }
            }
            return fallback
        }

        if (mode !== "auto" && _nativeClientKeys[mode]) {
            const keys = _nativeClientKeys[mode]
            let fallback = null
            // Pass 1: direct identity / dbus / desktopEntry match
            for (let i = 0; i < list.length; i++) {
                const pl = list[i]
                const hay = _playerHay(pl)
                if (_isMessenger(pl)) continue
                if (_matchesAnyKey(hay, keys)) {
                    if (pl.isPlaying) return pl
                    if (!fallback) fallback = pl
                }
            }
            if (fallback) return fallback
            // Pass 2: Electron clients (e.g. Yandex Music / YT Music / Tidal) exposing chromium.instance*
            if (mode === "yandex" || mode === "ytmusic" || mode === "tidal" || mode === "deezer" || mode === "apple") {
                for (let i = 0; i < list.length; i++) {
                    const pl = list[i]
                    if (!_isElectronMusicPlayer(pl)) continue
                    const art = String(pl.trackArtUrl || "").toLowerCase()
                    if (mode === "yandex" && (art.indexOf("yandex") !== -1 || String(pl.trackArtist || "").trim() !== "")) {
                        if (pl.isPlaying) return pl
                        if (!fallback) fallback = pl
                    } else if (mode !== "yandex") {
                        if (pl.isPlaying) return pl
                        if (!fallback) fallback = pl
                    }
                }
            }
            return fallback
        }

        // Auto mode:
        // Pass 1: explicit native music clients (checked BEFORE browser filter)
        const allKeys = []
        const groups = Object.keys(_nativeClientKeys)
        for (let g = 0; g < groups.length; g++) {
            const arr = _nativeClientKeys[groups[g]]
            for (let j = 0; j < arr.length; j++) allKeys.push(arr[j])
        }
        allKeys.push("soundcloud", "zvuk", "vk-music", "music")

        let fallback = null
        for (let i = 0; i < list.length; i++) {
            const pl = list[i]
            const hay = _playerHay(pl)
            if (_isMessenger(pl) || _matchesAnyKey(hay, _hardBrowserBlocklist)) continue
            if (_matchesAnyKey(hay, allKeys)) {
                if (pl.isPlaying) return pl
                if (!fallback) fallback = pl
            }
        }
        if (fallback) return fallback

        // Pass 2: Electron music apps registered as chromium.instance* (Yandex Music, YT Music, etc.)
        for (let i = 0; i < list.length; i++) {
            const pl = list[i]
            if (_isElectronMusicPlayer(pl)) {
                if (pl.isPlaying) return pl
                if (!fallback) fallback = pl
            }
        }
        return fallback
    }
    Connections {
        target: root.activeMprisPlayer
        function onIsPlayingChanged() {
            if (root.activeMprisPlayer && root.activeMprisPlayer.isPlaying && root.useInternalPlayer) {
                root.useInternalPlayer = false
                root.internalPauseRequested()
            }
        }
    }

    readonly property bool hasTrack: useInternalPlayer
        ? ((internalTrack.title || "") !== "")
        : (activeMprisPlayer !== null && (activeMprisPlayer.trackTitle || "") !== "")
    readonly property bool isPlaying: useInternalPlayer
        ? internalPlaying
        : (activeMprisPlayer ? activeMprisPlayer.isPlaying : false)
    readonly property string trackTitle: useInternalPlayer
        ? (internalTrack.title || "")
        : (activeMprisPlayer ? (activeMprisPlayer.trackTitle || "") : "")
    readonly property string trackArtist: useInternalPlayer
        ? (internalTrack.artist || "")
        : (activeMprisPlayer ? (activeMprisPlayer.trackArtist || "") : "")
    readonly property string trackAlbum: useInternalPlayer
        ? (internalTrack.album || "")
        : (activeMprisPlayer ? (activeMprisPlayer.trackAlbum || "") : "")
    readonly property string artUrl: useInternalPlayer
        ? (internalTrack.cover || "")
        : (activeMprisPlayer ? (activeMprisPlayer.trackArtUrl || "") : "")
    readonly property real trackLength: useInternalPlayer
        ? (internalDuration > 0 ? internalDuration : (internalTrack.duration || 0))
        : (activeMprisPlayer && activeMprisPlayer.length > 0 ? activeMprisPlayer.length : 0)

    property real livePosition: 0
    property string _lastTrackKey: ""

    // =========================================================================
    // Material You (Material Design 3 Dynamic Color Palette from Album Art)
    // =========================================================================
    ColorQuantizer {
        id: wallQuantizer
        source: ShellConfig.wallpaperPath ? ("file://" + ShellConfig.wallpaperPath) : ""
        depth: 4
        rescaleSize: 64
    }

    ColorQuantizer {
        id: quantizer
        source: root.artUrl
        depth: 4
        rescaleSize: 64
    }

    function pickBestColor(cols) {
        if (!cols || cols.length === 0) return null
        let best = cols[0]
        let bestScore = -1
        for (let i = 0; i < cols.length; i++) {
            const c = cols[i]
            if (!c) continue
            const score = c.hslSaturation * 1.8 + (1.0 - Math.abs(c.hslLightness - 0.52))
            if (score > bestScore) {
                bestScore = score
                best = c
            }
        }
        return best
    }

    // Extracted vibrant dominant hex color from current wallpaper (populated by WallpaperState)
    property string wallSeedHex: ""

    // Dynamic Material You seed: manual override -> playing album art (when not minimized) -> wallpaper -> fallback
    readonly property color seedColor: {
        if (ShellConfig.accentOverride !== "") {
            return Qt.color(ShellConfig.accentOverride)
        }
        if (ShellConfig.hudFromAlbum && root.hasTrack && root.isPlaying && !root.stageMinimizedToIsland && ShellConfig.stageVisible) {
            const ac = pickBestColor(quantizer.colors)
            if (ac) return ac
        }
        if (ShellConfig.wallpaperPath !== "" && root.wallSeedHex !== "") {
            return Qt.color(root.wallSeedHex)
        }
        const wc = pickBestColor(wallQuantizer.colors)
        if (ShellConfig.wallpaperPath !== "" && wc) {
            return wc
        }
        return Qt.color(currentPlatformObj.accent || "#D0BCFF")
    }

    readonly property real _seedHue: seedColor.hslHue >= 0 ? seedColor.hslHue : 0.72
    readonly property real _seedSat: Math.max(0.28, Math.min(0.85, seedColor.hslSaturation))

    readonly property bool _dark: ShellConfig.darkTheme
    readonly property real _op: Math.max(0.65, Math.min(1.0, ShellConfig.panelOpacity))

    readonly property real _secSat: Math.max(0.14, Math.min(0.32, _seedSat * 0.44))
    readonly property real _tertHue: (_seedHue + 0.1667) % 1.0 // +60deg Material You tonal harmony
    readonly property real _tertSat: Math.max(0.26, Math.min(0.68, _seedSat * 0.82))

    // =========================================================================
    // Material Design 3 Semantic Token System (Dark & Light + Dynamic Color)
    // =========================================================================

    // Primary role (highest-emphasis branded actions — used selectively)
    property color m3Primary: _dark
        ? Qt.hsla(_seedHue, Math.min(0.78, _seedSat + 0.12), 0.79, 1.0)
        : Qt.hsla(_seedHue, Math.min(0.74, _seedSat + 0.10), 0.37, 1.0)
    property color m3OnPrimary: _dark
        ? Qt.hsla(_seedHue, Math.min(0.55, _seedSat), 0.14, 1.0)
        : Qt.hsla(_seedHue, 0.10, 0.99, 1.0)
    property color m3PrimaryContainer: _dark
        ? Qt.hsla(_seedHue, Math.min(0.54, _seedSat * 0.86), 0.27, Math.min(1.0, _op + 0.04))
        : Qt.hsla(_seedHue, Math.min(0.64, _seedSat * 0.84), 0.87, Math.min(1.0, _op + 0.04))
    property color m3OnPrimaryContainer: _dark
        ? Qt.hsla(_seedHue, Math.min(0.68, _seedSat), 0.92, 1.0)
        : Qt.hsla(_seedHue, Math.min(0.68, _seedSat), 0.15, 1.0)

    // Secondary role (supporting emphasis: active nav indicators, tonal pills, secondary toggles)
    property color m3Secondary: _dark
        ? Qt.hsla(_seedHue, _secSat, 0.78, 1.0)
        : Qt.hsla(_seedHue, _secSat, 0.40, 1.0)
    property color m3OnSecondary: _dark
        ? Qt.hsla(_seedHue, _secSat, 0.16, 1.0)
        : Qt.hsla(_seedHue, 0.08, 0.99, 1.0)
    property color m3SecondaryContainer: _dark
        ? Qt.hsla(_seedHue, _secSat + 0.04, 0.25, Math.min(1.0, _op + 0.03))
        : Qt.hsla(_seedHue, _secSat + 0.06, 0.86, Math.min(1.0, _op + 0.03))
    property color m3OnSecondaryContainer: _dark
        ? Qt.hsla(_seedHue, _secSat, 0.91, 1.0)
        : Qt.hsla(_seedHue, _secSat + 0.06, 0.16, 1.0)

    // Tertiary role (contrasting +60deg expressive accent: modes, media/weather highlights, DND)
    property color m3Tertiary: _dark
        ? Qt.hsla(_tertHue, _tertSat, 0.80, 1.0)
        : Qt.hsla(_tertHue, _tertSat, 0.39, 1.0)
    property color m3OnTertiary: _dark
        ? Qt.hsla(_tertHue, _tertSat * 0.7, 0.15, 1.0)
        : Qt.hsla(_tertHue, 0.10, 0.99, 1.0)
    property color m3TertiaryContainer: _dark
        ? Qt.hsla(_tertHue, _tertSat * 0.78, 0.26, Math.min(1.0, _op + 0.03))
        : Qt.hsla(_tertHue, _tertSat * 0.80, 0.87, Math.min(1.0, _op + 0.03))
    property color m3OnTertiaryContainer: _dark
        ? Qt.hsla(_tertHue, _tertSat * 0.85, 0.92, 1.0)
        : Qt.hsla(_tertHue, _tertSat * 0.85, 0.16, 1.0)

    // Surface hierarchy (5-step M3 tonal elevation from Lowest to Highest)
    property color m3Surface: _dark
        ? Qt.hsla(_seedHue, Math.min(0.20, _seedSat * 0.32), 0.08, _op)
        : Qt.hsla(_seedHue, Math.min(0.18, _seedSat * 0.26), 0.98, _op)
    property color m3SurfaceContainerLowest: _dark
        ? Qt.hsla(_seedHue, Math.min(0.18, _seedSat * 0.28), 0.06, _op)
        : Qt.hsla(_seedHue, Math.min(0.14, _seedSat * 0.20), 1.00, _op)
    property color m3SurfaceContainerLow: _dark
        ? Qt.hsla(_seedHue, Math.min(0.22, _seedSat * 0.36), 0.10, _op)
        : Qt.hsla(_seedHue, Math.min(0.20, _seedSat * 0.30), 0.96, _op)
    property color m3SurfaceContainer: _dark
        ? Qt.hsla(_seedHue, Math.min(0.25, _seedSat * 0.42), 0.13, _op)
        : Qt.hsla(_seedHue, Math.min(0.22, _seedSat * 0.34), 0.93, _op)
    property color m3SurfaceContainerHigh: _dark
        ? Qt.hsla(_seedHue, Math.min(0.27, _seedSat * 0.44), 0.18, Math.min(1.0, _op + 0.02))
        : Qt.hsla(_seedHue, Math.min(0.22, _seedSat * 0.34), 0.89, Math.min(1.0, _op + 0.02))
    property color m3SurfaceContainerHighest: _dark
        ? Qt.hsla(_seedHue, Math.min(0.24, _seedSat * 0.40), 0.24, Math.min(1.0, _op + 0.04))
        : Qt.hsla(_seedHue, Math.min(0.20, _seedSat * 0.30), 0.84, Math.min(1.0, _op + 0.04))

    // Content & Outline roles (WCAG AA >= 4.5:1 contrast)
    property color m3OnSurface: _dark
        ? Qt.hsla(_seedHue, 0.09, 0.94, 1.0)
        : Qt.hsla(_seedHue, 0.14, 0.11, 1.0)
    property color m3OnSurfaceVariant: _dark
        ? Qt.hsla(_seedHue, 0.12, 0.76, 1.0)
        : Qt.hsla(_seedHue, 0.12, 0.32, 1.0)
    property color m3Outline: _dark
        ? Qt.hsla(_seedHue, 0.14, 0.56, 0.65)
        : Qt.hsla(_seedHue, 0.14, 0.46, 0.62)
    property color m3OutlineVariant: _dark
        ? Qt.hsla(_seedHue, 0.16, 0.42, 0.28)
        : Qt.hsla(_seedHue, 0.16, 0.54, 0.30)

    // Error / Destructive role (Power off, Reboot, Clear, Urgent alerts)
    property color m3Error: _dark
        ? Qt.hsla(0.985, 0.82, 0.78, 1.0)
        : Qt.hsla(0.985, 0.72, 0.42, 1.0)
    property color m3OnError: _dark
        ? Qt.hsla(0.985, 0.68, 0.16, 1.0)
        : Qt.hsla(0.0, 0.0, 1.0, 1.0)
    property color m3ErrorContainer: _dark
        ? Qt.hsla(0.985, 0.62, 0.24, Math.min(1.0, _op + 0.04))
        : Qt.hsla(0.985, 0.78, 0.89, Math.min(1.0, _op + 0.04))
    property color m3OnErrorContainer: _dark
        ? Qt.hsla(0.985, 0.85, 0.92, 1.0)
        : Qt.hsla(0.985, 0.75, 0.16, 1.0)

    // Reusable M3 Shape Scale tokens (prevents arbitrary 11/13/15/17/26px drift)
    readonly property int shapeXs: 4
    readonly property int shapeSm: 8
    readonly property int shapeMd: 12
    readonly property int shapeLg: 16
    readonly property int shapeXl: 28
    readonly property int shapeFull: 999

    // Reusable M3 Spacing Scale (4dp rhythm)
    readonly property int spaceXs: 4
    readonly property int spaceSm: 8
    readonly property int spaceMd: 12
    readonly property int spaceLg: 16
    readonly property int spaceXl: 24

    // Reusable M3 Typography Scale (semantic sizes)
    readonly property int typeHeadlineSm: 22
    readonly property int typeTitleLg: 18
    readonly property int typeTitleMd: 15
    readonly property int typeTitleSm: 13
    readonly property int typeBodyMd: 13
    readonly property int typeBodySm: 12
    readonly property int typeLabelLg: 12
    readonly property int typeLabelMd: 11
    readonly property int typeLabelSm: 10

    // Backwards-compatible aliases
    readonly property color accentColor: m3Primary
    readonly property color secondaryAccentColor: m3PrimaryContainer

    function _hexNoHash(c) {
        const r = Math.max(0, Math.min(255, Math.round(c.r * 255))).toString(16).padStart(2, "0")
        const g = Math.max(0, Math.min(255, Math.round(c.g * 255))).toString(16).padStart(2, "0")
        const b = Math.max(0, Math.min(255, Math.round(c.b * 255))).toString(16).padStart(2, "0")
        return r + g + b
    }

    function syncHyprBorders() {
        if (!ShellConfig.hyprDynamicBorders) return
        const c1 = root._hexNoHash(root.m3Primary)
        const c2 = root._hexNoHash(root.m3PrimaryContainer)
        const ci = root._hexNoHash(root.m3SurfaceContainerHighest)
        const luaCmd = 'hl.config({ general = { col = { active_border = { colors = {"rgba(' + c1 + 'ee)", "rgba(' + c2 + 'cc)"}, angle = 45 }, inactive_border = "rgba(' + ci + '55)" } } })'
        const activeLegacy = "rgba(" + c1 + "ee) rgba(" + c2 + "cc) 45deg"
        const inactiveLegacy = "rgba(" + ci + "55)"
        Quickshell.execDetached([
            "bash", "-c",
            'SIG="${HYPRLAND_INSTANCE_SIGNATURE:-}"; if [ -z "$SIG" ] || [ ! -S "/run/user/$(id -u)/hypr/$SIG/.socket.sock" ]; then SIG="$(ls -t "/run/user/$(id -u)/hypr" 2>/dev/null | head -n 1)"; fi; export HYPRLAND_INSTANCE_SIGNATURE="$SIG"; if command -v hyprctl >/dev/null 2>&1 && [ -n "$SIG" ]; then hyprctl eval "$1" >/dev/null 2>&1 || { hyprctl keyword general:col.active_border "$2" >/dev/null 2>&1; hyprctl keyword general:col.inactive_border "$3" >/dev/null 2>&1; }; fi',
            "_", luaCmd, activeLegacy, inactiveLegacy
        ])
    }

    Timer {
        id: hyprBorderSyncTimer
        interval: 320
        repeat: false
        onTriggered: root.syncHyprBorders()
    }

    onM3PrimaryChanged: hyprBorderSyncTimer.restart()
    onSeedColorChanged: hyprBorderSyncTimer.restart()
    Component.onCompleted: hyprBorderSyncTimer.restart()

    Behavior on m3Primary               { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
    Behavior on m3OnPrimary             { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
    Behavior on m3PrimaryContainer      { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
    Behavior on m3OnPrimaryContainer    { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
    Behavior on m3Secondary             { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
    Behavior on m3OnSecondary           { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
    Behavior on m3SecondaryContainer    { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
    Behavior on m3OnSecondaryContainer  { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
    Behavior on m3Tertiary              { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
    Behavior on m3OnTertiary            { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
    Behavior on m3TertiaryContainer     { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
    Behavior on m3OnTertiaryContainer   { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
    Behavior on m3Surface               { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
    Behavior on m3SurfaceContainerLowest { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
    Behavior on m3SurfaceContainerLow   { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
    Behavior on m3SurfaceContainer      { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
    Behavior on m3SurfaceContainerHigh  { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
    Behavior on m3SurfaceContainerHighest { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
    Behavior on m3OnSurface             { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
    Behavior on m3OnSurfaceVariant      { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
    Behavior on m3Outline               { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
    Behavior on m3OutlineVariant        { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
    Behavior on m3Error                 { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
    Behavior on m3OnError               { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
    Behavior on m3ErrorContainer        { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
    Behavior on m3OnErrorContainer      { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }

    Timer {
        id: trackChangeDebounce
        interval: 180
        repeat: false
        onTriggered: root.applyTrackChange(false)
    }

    Timer {
        id: startupSync
        interval: 600
        running: true
        repeat: false
        onTriggered: root.applyTrackChange(true)
    }

    Timer {
        interval: 150
        running: root.hasTrack && root.isPlaying
        repeat: true
        onTriggered: {
            if (root.useInternalPlayer) {
                root.livePosition = root.internalPosition
                root.updateActiveLyric()
                return
            }
            if (!root.activeMprisPlayer) {
                root.livePosition = 0
                return
            }
            const pos = root.activeMprisPlayer.position
            if (Math.abs(pos - root.livePosition) > 1.0 || !root.isPlaying) {
                root.livePosition = pos
            } else if (root.isPlaying) {
                root.livePosition += 0.15
            }
            root.updateActiveLyric()
        }
    }

    function updateActiveLyric() {
        if (!lyricsSynced || !lyricsLines || lyricsLines.length === 0) {
            currentLyricIndex = -1
            return
        }
        const t = livePosition + 0.25
        let idx = -1
        for (let i = 0; i < lyricsLines.length; i++) {
            if (lyricsLines[i].time <= t) idx = i
            else break
        }
        if (idx !== currentLyricIndex) currentLyricIndex = idx
    }

    onTrackTitleChanged: trackChangeDebounce.restart()
    onTrackArtistChanged: trackChangeDebounce.restart()

    function applyTrackChange(force) {
        const key = (trackTitle + "|" + trackArtist).trim()
        if (!key || key === "|") return
        if (!force && key === _lastTrackKey) return
        _lastTrackKey = key

        lyricsAltIndex = 0
        lyricsLines = []
        setTrackGenreSmooth("pop")
        lyricsSynced = false
        currentLyricIndex = -1
        videoStreamUrl = ""

        fetchLyrics()
        if (videoWallpaperEnabled) {
            fetchVideoBackdrop()
        }
        refreshQueue()
    }

    function raiseActivePlayer() {
        // 1. Try native MPRIS Raise() first
        if (activeMprisPlayer && activeMprisPlayer.canRaise) {
            activeMprisPlayer.raise()
        }
        // 2. Also focus matching Wayland window via ToplevelManager so compositor switches workspace to it!
        const list = ToplevelManager.toplevels.values || []
        const keys = []
        if (activeMprisPlayer) {
            if (activeMprisPlayer.desktopEntry) keys.push(activeMprisPlayer.desktopEntry.toLowerCase())
            if (activeMprisPlayer.identity) keys.push(activeMprisPlayer.identity.toLowerCase())
        }
        const pObj = currentPlatformObj
        if (pObj && pObj.match) {
            for (let i = 0; i < pObj.match.length; i++) keys.push(pObj.match[i].toLowerCase())
        }
        for (let i = 0; i < list.length; i++) {
            const tl = list[i]
            const hay = ((tl.appId || "") + " " + (tl.title || "")).toLowerCase()
            for (let k = 0; k < keys.length; k++) {
                if (keys[k] && hay.indexOf(keys[k]) !== -1) {
                    tl.activate()
                    return
                }
            }
        }
    }

    function togglePlay() {
        if (useInternalPlayer) {
            internalToggleRequested()
        } else if (activeMprisPlayer && activeMprisPlayer.canTogglePlaying) {
            activeMprisPlayer.togglePlaying()
        }
    }

    function nextTrack() {
        if (useInternalPlayer && queueItems.length > 1) {
            let idx = 0
            for (let i = 0; i < queueItems.length; i++) {
                if ((queueItems[i].title || "").toLowerCase() === trackTitle.toLowerCase()) {
                    idx = (i + 1) % queueItems.length
                    break
                }
            }
            playItem(queueItems[idx])
        } else if (activeMprisPlayer && activeMprisPlayer.canGoNext) {
            activeMprisPlayer.next()
        }
    }

    function prevTrack() {
        if (useInternalPlayer && queueItems.length > 1) {
            let idx = 0
            for (let i = 0; i < queueItems.length; i++) {
                if ((queueItems[i].title || "").toLowerCase() === trackTitle.toLowerCase()) {
                    idx = (i - 1 + queueItems.length) % queueItems.length
                    break
                }
            }
            playItem(queueItems[idx])
        } else if (activeMprisPlayer && activeMprisPlayer.canGoPrevious) {
            activeMprisPlayer.previous()
        }
    }

    function seekTo(seconds) {
        if (useInternalPlayer) {
            internalSeekRequested(seconds)
            livePosition = seconds
            updateActiveLyric()
        } else if (activeMprisPlayer && activeMprisPlayer.canSeek) {
            activeMprisPlayer.position = seconds
            livePosition = seconds
            updateActiveLyric()
        }
    }

    function selectPlatform(pid) {
        selectedPlatform = pid
        platformMenuOpen = false
        refreshQueue()
        if (searchOpen && searchQuery.trim().length > 0) runSearch(searchQuery)
    }

    function nextLyricsVariant() {
        if (!hasTrack) return
        lyricsAltIndex += 1
        fetchLyrics()
    }

    function toggleVideoWallpaper() {
        videoWallpaperEnabled = !videoWallpaperEnabled
        if (videoWallpaperEnabled && hasTrack) {
            fetchVideoBackdrop()
        } else {
            videoProc.running = false
            videoStreamUrl = ""
            videoLoading = false
        }
    }

    FileView {
        id: configView
        path: root.rootDir + "/config.json"
        watchChanges: true
        onLoaded: {
            try {
                const cfg = JSON.parse(configView.text())
                if (cfg.layer) root.layerMode = cfg.layer
                if (cfg.respect_bar_margin_top !== undefined) root.topBarMargin = cfg.respect_bar_margin_top
                if (cfg.default_platform) root.selectedPlatform = cfg.default_platform
                if (cfg.in_app_playback !== undefined) root.inAppPlayback = cfg.in_app_playback
                if (cfg.video_wallpaper !== undefined) root.videoWallpaperEnabled = cfg.video_wallpaper
                if (cfg.video_engine) root.videoEngine = cfg.video_engine
                if (cfg.video_rotation !== undefined) root.videoRotation = cfg.video_rotation
                if (cfg.fallback_video_path) root.fallbackVideoPath = cfg.fallback_video_path
                if (cfg.clock_24h !== undefined) root.clock24h = cfg.clock_24h
                if (cfg.font_clock) root.fontClock = cfg.font_clock
                if (cfg.font_ui) root.fontUi = cfg.font_ui
                if (cfg.dock_pinned !== undefined) root.dockPinned = cfg.dock_pinned
                if (cfg.dock_apps && cfg.dock_apps.length > 0) root.dockApps = cfg.dock_apps
                if (cfg.launcher_cmd !== undefined) root.launcherCmd = cfg.launcher_cmd
            } catch (e) {
                console.warn("AmbientMusicShell: config.json parse error", e)
            }
            root.refreshQueue()
            root.applyTrackChange(true)
        }
    }

    function backendCmd(args) {
        return ["bash", "-c", "PY=\"$1\"; shift; [ -x \"$PY\" ] || PY=python3; exec \"$PY\" \"$@\"", "_", pythonBin, backendScript].concat(args)
    }

    function restartProc(proc, cmd) {
        proc.running = false
        proc.command = cmd
        Qt.callLater(function() {
            proc.running = true
        })
    }

    Timer {
        id: searchDebounce
        interval: 260
        repeat: false
        onTriggered: {
            if (root.searchQuery.trim().length >= 2) {
                root._searchGen += 1
                root._searchActiveGen = root._searchGen
                root.searchLoading = true
                root.restartProc(searchProc, root.backendCmd(["search", root.selectedPlatform, root.searchQuery.trim()]))
            } else {
                searchProc.running = false
                root.searchTracks = []
                root.searchArtists = []
                root.searchLoading = false
            }
        }
    }

    function runSearch(query) {
        searchQuery = query
        searchDebounce.restart()
    }

    Process {
        id: searchProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (root._searchActiveGen !== root._searchGen) return
                root.searchLoading = false
                try {
                    const data = JSON.parse(text)
                    root.searchTracks = data.tracks || []
                    root.searchArtists = data.artists || []
                } catch (e) {}
            }
        }
    }

    Timer {
        id: statusBannerTimer
        interval: 3800
        repeat: false
        onTriggered: {
            root.statusBannerText = ""
            root.statusBannerIcon = ""
        }
    }

    function playItem(item) {
        const pInfo = platformInfo(item.platform || selectedPlatform)
        statusBannerText = "Starting on " + pInfo.name
        statusBannerIcon = pInfo.icon
        statusBannerColor = Qt.color(pInfo.accent)
        statusBannerTimer.restart()
        searchOpen = false

        if (inAppPlayback) {
            internalTrack = item
            useInternalPlayer = true
            if (activeMprisPlayer && activeMprisPlayer.isPlaying && activeMprisPlayer.canPause) {
                activeMprisPlayer.pause()
            }
        }

        restartProc(playProc, backendCmd(["play", JSON.stringify(item)]))
    }

    Process {
        id: playProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.refreshQueue()
                try {
                    const data = JSON.parse(text)
                    if (data.ok && data.mode === "in_app" && data.audioUrl) {
                        root.internalTrack = data.item || root.internalTrack
                        root.internalAudioUrl = data.audioUrl
                        root.useInternalPlayer = true
                        root.internalPlayRequested(data.audioUrl)
                    } else if (!data.ok && data.error) {
                        root.statusBannerText = data.error
                        root.statusBannerIcon = ""
                        statusBannerTimer.restart()
                    }
                } catch (e) {}
            }
        }
    }

    function refreshQueue() {
        restartProc(queueProc, backendCmd(["queue", selectedPlatform]))
    }

    Process {
        id: queueProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    root.queueItems = data.items || []
                } catch (e) {}
            }
        }
    }

    function fetchLyrics() {
        if (!hasTrack) return
        _lyricsGen += 1
        _lyricsActiveGen = _lyricsGen
        lyricsLoading = true
        restartProc(lyricsProc, backendCmd([
            "lyrics",
            trackTitle,
            trackArtist,
            String(Math.round(trackLength)),
            String(lyricsAltIndex)
        ]))
    }

    Process {
        id: lyricsProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (root._lyricsActiveGen !== root._lyricsGen) return
                root.lyricsLoading = false
                try {
                    const data = JSON.parse(text)
                    root.lyricsSynced = !!data.synced
                    root.lyricsLines = data.lines || []
                    root.lyricsSource = data.source || ""
                    root.lyricsTotalVariants = data.total || 0
                    if (data.genre) root.setTrackGenreSmooth(String(data.genre))
                    root.updateActiveLyric()
                } catch (e) {
                    root.lyricsLines = []
                }
            }
        }
    }

    function fetchVideoBackdrop() {
        if (!hasTrack || !videoWallpaperEnabled) return
        _videoGen += 1
        _videoActiveGen = _videoGen
        videoLoading = true
        restartProc(videoProc, backendCmd(["video_url", trackTitle, trackArtist]))
    }

    Process {
        id: videoProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (root._videoActiveGen !== root._videoGen) return
                root.videoLoading = false
                try {
                    const data = JSON.parse(text)
                    if (data.ok && data.url) {
                        root.videoStreamUrl = data.url
                    } else if (root.fallbackVideoPath) {
                        root.videoStreamUrl = root.fallbackVideoPath
                    }
                } catch (e) {}
            }
        }
    }
}
