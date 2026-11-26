pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * Reactive System State Service:
 * - Wi-Fi (toggle + scan/connect), Bluetooth (toggle + paired devices), Audio Sinks (switch output)
 * - Volume & Brightness with automatic Material You Wavy OSD notifications
 * - Keyboard Layout (RU/EN), Night Light (hyprsunset), Power Profiles, Live Weather
 * - Battery, CPU, RAM, Disk, Uptime & Launcher/QuickSettings popup coordination
 */
Singleton {
    id: root

    property bool quickSettingsOpen: false
    property bool langMenuOpen: false
    property var kbdLayouts: [
        { index: 0, code: "EN", name: "English (US)" },
        { index: 1, code: "RU", name: "Русский" }
    ]
    property bool launcherOpen: false
    property string quickSettingsSubmenu: "" // "" | "wifi" | "bt" | "audio"

    // Network
    property bool wifiEnabled: false
    property string wifiSsid: ""
    property bool ethernetConnected: false
    property var wifiNetworks: []
    property string wifiPasswordTarget: ""
    property string wifiStatusMsg: ""
    property bool wifiConnecting: false

    // Bluetooth
    property bool btEnabled: false
    property string btDevice: ""
    property var btDevices: []

    // Audio
    property int volume: 50
    property bool muted: false
    property var audioSinks: []
    property var appStreams: []

    // Brightness
    property bool hasBrightness: false
    property int brightness: 100

    // Battery
    property bool hasBattery: false
    property int batteryPercent: 100
    property bool batteryCharging: false

    // Performance & Info
    property int cpuPercent: 0
    property int ramPercent: 0
    property string ramText: ""
    property int diskPercent: 0
    property string diskText: ""
    property string uptimeText: ""
    property string userName: "user"
    property string hostName: ""
    property string kernelVer: ""
    property string distroName: "CachyOS"
    property string netDown: "0 KB/s"
    property string netUp: "0 KB/s"
    property bool gameMode: false
    property bool keepAwake: false
    property bool hasCava: true

    // Daily-driver extras
    property string kbdLayout: "EN"
    property bool nightLight: false
    property string powerProfile: ""
    property var powerProfiles: []

    // Weather
    property string weatherTemp: ""
    property string weatherDesc: ""
    property string weatherCity: ""
    property string weatherFeels: ""
    property string weatherHumidity: ""
    property string weatherWind: ""
    property string weatherSunrise: ""
    property string weatherSunset: ""
    property var weatherForecast: []

    // OSD Pill State
    property bool osdVisible: false
    property string osdIcon: "volume_high"
    property string osdLabel: ""
    property real osdValue: 0.0
    property bool osdShowBar: true
    property string osdText: ""
    property bool _firstPollDone: false

    readonly property string sysScript: Qt.resolvedUrl("sysinfo.sh").toString().replace("file://", "")
    readonly property string hyprAnimsScript: Qt.resolvedUrl("hypr_anims.py").toString().replace("file://", "")
    readonly property string audioMixerScript: Qt.resolvedUrl("audio_mixer.py").toString().replace("file://", "")

    function refreshAppStreams() {
        if (appStreamProc.running) return
        appStreamProc.command = ["python3", root.audioMixerScript, "list"]
        appStreamProc.running = true
    }

    function setAppVolume(streamId, pct) {
        Quickshell.execDetached(["python3", root.audioMixerScript, "set", String(streamId), String(Math.round(pct))])
    }

    function toggleAppMute(streamId) {
        Quickshell.execDetached(["python3", root.audioMixerScript, "mute", String(streamId)])
        appStreamRefreshDelay.restart()
    }

    function applyHyprAnims() {
        ShellConfig.save()
        Quickshell.execDetached([
            "python3", root.hyprAnimsScript,
            ShellConfig.hyprAnimStyle,
            ShellConfig.hyprAnimWinStyle,
            ShellConfig.hyprAnimWsStyle,
            String(ShellConfig.hyprAnimSpeed)
        ])
        const labels = { smooth: "Плавные M3", snappy: "Быстрые", bounce: "Пружина", minimal: "Минимум", off: "Выкл" }
        showOsd("sliders", "Анимации", 1.0, labels[ShellConfig.hyprAnimStyle] || ShellConfig.hyprAnimStyle, false)
    }


    function showOsd(icon, label, valueRatio, textVal, showBar) {
        osdIcon = icon
        osdLabel = label
        osdValue = Math.max(0.0, Math.min(1.0, valueRatio))
        osdText = textVal
        osdShowBar = showBar !== false
        osdVisible = true
        osdHideTimer.restart()
    }


    function _parseLayoutCode(layoutName) {
        const low = String(layoutName || "").trim().toLowerCase()
        if (!low) return ""
        if (low.indexOf("russian") !== -1 || low.indexOf("рус") !== -1 || low === "ru" || low.startsWith("ru ")) return "RU"
        if (low.indexOf("english") !== -1 || low.indexOf("us") !== -1 || low === "en" || low.startsWith("en ")) return "EN"
        if (low.indexOf("ukrain") !== -1) return "UK"
        if (low.indexOf("german") !== -1) return "DE"
        if (low.indexOf("french") !== -1) return "FR"
        return String(layoutName).trim().slice(0, 2).toUpperCase()
    }

    readonly property string kittyAutofontScript: Qt.resolvedUrl("kitty_autofont.py").toString().replace("file://", "")

    Timer {
        id: kittyAutofontDebounce
        interval: 160
        repeat: false
        onTriggered: if (ShellConfig.kittyAutoFont) Quickshell.execDetached(["python3", root.kittyAutofontScript])
    }

    // Instant 0ms keyboard layout detection + responsive Kitty font sizing on Hyprland events
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (!ev) return
            if (ev.name === "openwindow" || ev.name === "closewindow" || ev.name === "movewindow" || ev.name === "changefloatingmode" || ev.name === "fullscreen" || ev.name === "activewindow") {
                kittyAutofontDebounce.restart()
            }
            if (ev.name !== "activelayout") return
            const raw = String(ev.data || "")
            const comma = raw.lastIndexOf(",")
            const layoutName = comma !== -1 ? raw.slice(comma + 1).trim() : raw.trim()
            const code = root._parseLayoutCode(layoutName)
            if (code && code !== root.kbdLayout) {
                root.kbdLayout = code
                root.showOsd("keyboard", "Раскладка", 1.0, code, false)
            }
        }
    }

    Timer {
        id: osdHideTimer
        interval: 1800
        repeat: false
        onTriggered: root.osdVisible = false
    }

    function toggleLangMenu() {
        langMenuOpen = !langMenuOpen
        if (langMenuOpen) {
            quickSettingsOpen = false
            quickSettingsSubmenu = ""
            wifiPasswordTarget = ""
            launcherOpen = false
            ClipboardState.open = false
            NotifState.closeAllPopups()
            refreshLayouts()
        }
    }

    function refreshLayouts() {
        if (!layoutListProc.running) {
            layoutListProc.command = ["bash", sysScript, "list-layouts"]
            layoutListProc.running = true
        }
    }

    function setKeyboardLayout(idx, code) {
        if (code) root.kbdLayout = code
        runCmd("bash " + JSON.stringify(sysScript) + " set-layout " + String(idx))
        langMenuOpen = false
    }

    function toggleLauncher() {
        launcherOpen = !launcherOpen
        if (launcherOpen) {
            quickSettingsOpen = false
            langMenuOpen = false
            quickSettingsSubmenu = ""
        wifiPasswordTarget = ""
        wifiStatusMsg = ""
            ClipboardState.open = false
            NotifState.closeAllPopups()
        }
    }

    function toggleQuickSettings() {
        langMenuOpen = false
        launcherOpen = false
        ClipboardState.open = false
        quickSettingsOpen = !quickSettingsOpen
        if (quickSettingsOpen) {
            quickSettingsSubmenu = ""
        wifiPasswordTarget = ""
        wifiStatusMsg = ""
            NotifState.closeAllPopups()
            refreshAll()
        }
    }

    function openSubmenu(name) {
        quickSettingsSubmenu = name
        if (name === "wifi") refreshWifiList()
        else if (name === "bt") refreshBtList()
        else if (name === "audio") { refreshAudioSinks(); refreshAppStreams() }
    }

    function runCmd(cmd) {
        Quickshell.execDetached(["bash", "-c", cmd])
        delayedRefresh.restart()
    }

    function toggleWifi() {
        const next = wifiEnabled ? "off" : "on"
        wifiEnabled = !wifiEnabled
        runCmd("nmcli radio wifi " + next)
    }

    function connectWifi(ssid, password, security, saved) {
        if (!ssid || wifiConnecting) return
        const pw = String(password || "")
        const needsPw = !!security && !saved && pw === ""
        if (needsPw) {
            wifiPasswordTarget = ssid
            wifiStatusMsg = ""
            return
        }
        wifiConnecting = true
        wifiStatusMsg = "Подключение к " + ssid + "..."
        wifiConnectProc.targetSsid = ssid
        wifiConnectProc.command = pw !== ""
            ? ["bash", sysScript, "wifi-connect", ssid, pw]
            : ["bash", sysScript, "wifi-connect", ssid]
        wifiConnectProc.running = true
    }

    function cancelWifiPassword() {
        wifiPasswordTarget = ""
        wifiStatusMsg = ""
    }

    function toggleBluetooth() {
        const next = btEnabled ? "off" : "on"
        btEnabled = !btEnabled
        runCmd("bluetoothctl power " + next)
    }

    function toggleBtDevice(mac, connected) {
        if (!mac) return
        const act = connected ? "disconnect" : "connect"
        runCmd("bluetoothctl " + act + " " + mac)
    }

    function setAudioSink(sinkId) {
        if (!sinkId) return
        runCmd("bash " + JSON.stringify(sysScript) + " audio-set " + JSON.stringify(sinkId))
        delayedSubRefresh.restart()
    }

    function setVolume(pct) {
        const clamped = Math.max(0, Math.min(100, Math.round(pct)))
        volume = clamped
        muted = clamped === 0
        const ic = (muted || clamped === 0) ? "volume_mute" : (clamped < 45 ? "volume_low" : "volume_high")
        showOsd(ic, "Звук", clamped / 100.0, clamped + "%", true)
        runCmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + (clamped / 100.0).toFixed(2) + " 2>/dev/null || pactl set-sink-volume @DEFAULT_SINK@ " + clamped + "%")
    }

    function adjustVolume(delta) {
        setVolume(volume + delta)
    }

    function toggleMute() {
        muted = !muted
        const ic = muted ? "volume_mute" : (volume < 45 ? "volume_low" : "volume_high")
        showOsd(ic, "Звук", muted ? 0 : (volume / 100.0), muted ? "Выкл" : (volume + "%"), true)
        runCmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle 2>/dev/null || pactl set-sink-mute @DEFAULT_SINK@ toggle")
    }

    function setBrightness(pct) {
        const clamped = Math.max(5, Math.min(100, Math.round(pct)))
        brightness = clamped
        showOsd("brightness", "Яркость", clamped / 100.0, clamped + "%", true)
        runCmd("brightnessctl set " + clamped + "%")
    }

    function _hyprExec(luaCode, legacyBatch) {
        const script =
            'SIG="${HYPRLAND_INSTANCE_SIGNATURE:-}"; ' +
            'if [ -z "$SIG" ] || [ ! -S "/run/user/$(id -u)/hypr/$SIG/.socket.sock" ]; then ' +
            'SIG="$(ls -t "/run/user/$(id -u)/hypr" 2>/dev/null | head -n 1)"; fi; ' +
            'export HYPRLAND_INSTANCE_SIGNATURE="$SIG"; ' +
            'if command -v hyprctl >/dev/null 2>&1 && [ -n "$SIG" ]; then ' +
            'hyprctl eval "$1" >/dev/null 2>&1 || hyprctl --batch "$2" >/dev/null 2>&1; fi'
        Quickshell.execDetached(["bash", "-c", script, "_", luaCode, legacyBatch || ""])
    }

    function toggleNightLight() {
        if (!nightLight) {
            nightLight = true
            Quickshell.execDetached(["bash", "-c",
                "pkill -x hyprsunset 2>/dev/null || true; pkill -x wlsunset 2>/dev/null || true; pkill -x gammastep 2>/dev/null || true; " +
                "if command -v hyprsunset >/dev/null 2>&1; then setsid -f hyprsunset -t 4200 >/dev/null 2>&1; " +
                "elif command -v wlsunset >/dev/null 2>&1; then setsid -f wlsunset -T 4200 -t 4200 >/dev/null 2>&1; " +
                "elif command -v gammastep >/dev/null 2>&1; then setsid -f gammastep -O 4200 >/dev/null 2>&1; " +
                "else exit 1; fi"
            ])
            showOsd("nightlight", "Ночной свет", 1.0, "4200K", false)
        } else {
            nightLight = false
            Quickshell.execDetached(["bash", "-c", "pkill -x hyprsunset 2>/dev/null || true; pkill -x wlsunset 2>/dev/null || true; pkill -x gammastep 2>/dev/null || true"])
            showOsd("nightlight", "Ночной свет", 0.0, "Выкл", false)
        }
        delayedRefresh.restart()
    }

    function toggleGameMode() {
        gameMode = !gameMode
        if (gameMode) {
            _hyprExec(
                "hl.config({ animations = { enabled = false }, decoration = { blur = { enabled = false }, shadow = { enabled = false }, rounding = 0 }, general = { gaps_in = 0, gaps_out = 0 } })",
                "keyword animations:enabled 0; keyword decoration:blur:enabled 0; keyword decoration:shadow:enabled 0; keyword decoration:rounding 0; keyword general:gaps_in 0; keyword general:gaps_out 0"
            )
            showOsd("apps", "Игровой режим", 1.0, "Вкл", false)
        } else {
            const reloadScript =
                'SIG="${HYPRLAND_INSTANCE_SIGNATURE:-}"; ' +
                'if [ -z "$SIG" ] || [ ! -S "/run/user/$(id -u)/hypr/$SIG/.socket.sock" ]; then ' +
                'SIG="$(ls -t "/run/user/$(id -u)/hypr" 2>/dev/null | head -n 1)"; fi; ' +
                'export HYPRLAND_INSTANCE_SIGNATURE="$SIG"; ' +
                'hyprctl reload >/dev/null 2>&1'
            Quickshell.execDetached(["bash", "-c", reloadScript])
            showOsd("apps", "Игровой режим", 0.0, "Выкл", false)
        }
    }

    function toggleKeepAwake() {
        keepAwake = !keepAwake
        if (keepAwake) {
            Quickshell.execDetached(["bash", "-c", "pkill -x hypridle 2>/dev/null || true"])
            showOsd("brightness", "Не засыпать", 1.0, "Вкл", false)
        } else {
            Quickshell.execDetached(["bash", "-c", "command -v hypridle >/dev/null 2>&1 && (pgrep -x hypridle >/dev/null || nohup hypridle >/dev/null 2>&1 &)"])
            showOsd("brightness", "Не засыпать", 0.0, "Выкл", false)
        }
    }

    function cyclePowerProfile() {
        if (!powerProfile) {
            showOsd("performance", "Питание", 0.0, "Нужен power-profiles-daemon", false)
            return
        }
        const avail = (powerProfiles && powerProfiles.length > 0) ? powerProfiles : ["power-saver", "balanced", "performance"]
        const idx = avail.indexOf(powerProfile)
        const next = avail[(idx + 1) % avail.length]
        if (powerSetProc.running) return
        powerSetProc.targetProfile = next
        powerSetProc.errBuf = ""
        powerSetProc.command = ["powerprofilesctl", "set", next]
        powerSetProc.running = true
    }

    function switchKeyboardLayout() {
        runCmd("bash " + JSON.stringify(sysScript) + " switch-layout")
    }

    function lockScreen() {
        quickSettingsOpen = false
        launcherOpen = false
        LockState.lock()
    }

    function suspendSystem() {
        quickSettingsOpen = false
        launcherOpen = false
        Quickshell.execDetached(["systemctl", "suspend"])
    }

    function rebootSystem() {
        quickSettingsOpen = false
        launcherOpen = false
        Quickshell.execDetached(["systemctl", "reboot"])
    }

    function powerOffSystem() {
        quickSettingsOpen = false
        launcherOpen = false
        Quickshell.execDetached(["systemctl", "poweroff"])
    }

    function refreshAll() {
        if (!pollProc.running) {
            pollProc.command = ["bash", sysScript, "status"]
            pollProc.running = true
        }
    }

    function refreshWifiList(rescan) {
        if (!wifiListProc.running) {
            wifiListProc.command = rescan
                ? ["bash", sysScript, "wifi-list", "rescan"]
                : ["bash", sysScript, "wifi-list"]
            wifiListProc.running = true
        }
    }

    function refreshBtList() {
        if (!btListProc.running) {
            btListProc.command = ["bash", sysScript, "bt-list"]
            btListProc.running = true
        }
    }

    function refreshAudioSinks() {
        if (!audioListProc.running) {
            audioListProc.command = ["bash", sysScript, "audio-list"]
            audioListProc.running = true
        }
    }

    function refreshWeather() {
        if (!weatherProc.running) {
            weatherProc.command = ["bash", sysScript, "weather"]
            weatherProc.running = true
        }
    }

    Timer {
        id: delayedRefresh
        interval: 450
        repeat: false
        onTriggered: root.refreshAll()
    }

    Timer {
        id: delayedSubRefresh
        interval: 450
        repeat: false
        onTriggered: {
            if (root.quickSettingsSubmenu === "wifi") root.refreshWifiList()
            else if (root.quickSettingsSubmenu === "bt") root.refreshBtList()
            else if (root.quickSettingsSubmenu === "audio") root.refreshAudioSinks()
        }
    }


    Timer {
        interval: (root.quickSettingsOpen || NotifState.islandExpanded) ? 2000 : 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshAll()
    }

    Timer {
        interval: 1800000 // 30 minutes
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshWeather()
    }

    Timer {
        id: appStreamRefreshDelay
        interval: 220
        repeat: false
        onTriggered: root.refreshAppStreams()
    }

    Process {
        id: appStreamProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                const s = line.trim()
                if (!s.startsWith("[")) return
                try { root.appStreams = JSON.parse(s) } catch (e) {}
            }
        }
    }

    Process {
        id: powerSetProc
        property string targetProfile: ""
        property string errBuf: ""
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: function(line) { powerSetProc.errBuf += line + " " }
        }
        onExited: function(code) {
            const labels = { "power-saver": "Экономия", "balanced": "Баланс", "performance": "Максимум" }
            if (code === 0) {
                root.powerProfile = targetProfile
                root.showOsd("performance", "Питание", 1.0, labels[targetProfile] || targetProfile, false)
            } else {
                // Profile rejected by kernel/daemon (e.g. degraded/unsupported) — remove from cycle & notify honestly
                const filtered = (root.powerProfiles || []).filter(function(x) { return x !== targetProfile })
                if (filtered.length > 0) root.powerProfiles = filtered
                root.showOsd("performance", "Питание", 0.0, (labels[targetProfile] || targetProfile) + " недоступен", false)
            }
            delayedRefresh.restart()
        }
    }

    Process {
        id: pollProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                const s = line.trim()
                if (!s.startsWith("{")) return
                try {
                    const d = JSON.parse(s)
                    const prevVol = root.volume
                    const prevMuted = root.muted
                    const prevBr = root.brightness
                    const prevKbd = root.kbdLayout

                    root.wifiEnabled = !!d.wifiEnabled
                    root.wifiSsid = d.wifiSsid || ""
                    root.ethernetConnected = !!d.ethernetConnected
                    root.btEnabled = !!d.btEnabled
                    root.btDevice = d.btDevice || ""
                    root.volume = Number(d.volume || 0)
                    root.muted = !!d.muted
                    root.hasBrightness = !!d.hasBrightness
                    root.brightness = Number(d.brightness || 100)
                    root.hasBattery = !!d.hasBattery
                    root.batteryPercent = Number(d.batteryPercent || 100)
                    root.batteryCharging = !!d.batteryCharging
                    root.cpuPercent = Number(d.cpuPercent || 0)
                    root.ramPercent = Number(d.ramPercent || 0)
                    root.ramText = d.ramText || ""
                    root.diskPercent = Number(d.diskPercent || 0)
                    root.diskText = d.diskText || ""
                    root.uptimeText = d.uptimeText || ""
                    root.userName = d.userName || "user"
                    root.nightLight = !!d.nightLight
                    root.powerProfile = d.powerProfile || ""
                    if (Array.isArray(d.powerProfiles)) root.powerProfiles = d.powerProfiles
                    if (d.hasCava !== undefined) root.hasCava = !!d.hasCava
                    root.kbdLayout = d.kbdLayout || "EN"
                    if (d.hostName) root.hostName = d.hostName
                    if (d.kernelVer) root.kernelVer = d.kernelVer
                    if (d.distroName) root.distroName = d.distroName
                    if (d.netDown) root.netDown = d.netDown
                    if (d.netUp) root.netUp = d.netUp

                    // Auto-trigger OSD when hardware keys change volume, brightness, or layout!
                    if (root._firstPollDone) {
                        if (root.volume !== prevVol || root.muted !== prevMuted) {
                            const ic = (root.muted || root.volume === 0) ? "volume_mute" : (root.volume < 45 ? "volume_low" : "volume_high")
                            root.showOsd(ic, "Звук", root.muted ? 0 : (root.volume / 100.0), root.muted ? "Выкл" : (root.volume + "%"), true)
                        } else if (root.hasBrightness && root.brightness !== prevBr) {
                            root.showOsd("brightness", "Яркость", root.brightness / 100.0, root.brightness + "%", true)
                        } else if (root.kbdLayout !== prevKbd) {
                            root.showOsd("keyboard", "Раскладка", 1.0, root.kbdLayout, false)
                        }
                    } else {
                        root._firstPollDone = true
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: layoutListProc
        stdout: SplitParser {
            splitMarker: "
"
            onRead: function(line) {
                const s = line.trim()
                if (!s.startsWith("[")) return
                try {
                    const arr = JSON.parse(s)
                    if (arr && arr.length > 0) root.kbdLayouts = arr
                } catch (e) {}
            }
        }
    }

    Process {
        id: wifiListProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                const s = line.trim()
                if (!s.startsWith("[")) return
                try { root.wifiNetworks = JSON.parse(s) } catch (e) {}
            }
        }
    }

    Process {
        id: wifiConnectProc
        property string targetSsid: ""
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                const s = line.trim()
                if (!s.startsWith("{")) return
                root.wifiConnecting = false
                try {
                    const res = JSON.parse(s)
                    if (res.ok) {
                        root.wifiPasswordTarget = ""
                        root.wifiStatusMsg = "Подключено!"
                        root.refreshAll()
                        root.refreshWifiList(false)
                    } else if (res.needPassword) {
                        root.wifiPasswordTarget = wifiConnectProc.targetSsid
                        root.wifiStatusMsg = "Введите пароль сети"
                    } else {
                        root.wifiStatusMsg = res.error || "Ошибка подключения"
                    }
                } catch (e) {
                    root.wifiStatusMsg = "Ошибка подключения"
                }
            }
        }
        onExited: root.wifiConnecting = false
    }

    Process {
        id: btListProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                const s = line.trim()
                if (!s.startsWith("[")) return
                try { root.btDevices = JSON.parse(s) } catch (e) {}
            }
        }
    }

    Process {
        id: audioListProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                const s = line.trim()
                if (!s.startsWith("[")) return
                try { root.audioSinks = JSON.parse(s) } catch (e) {}
            }
        }
    }

    Process {
        id: weatherProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                const s = line.trim()
                if (!s.startsWith("{")) return
                try {
                    const d = JSON.parse(s)
                    if (d.temp) root.weatherTemp = d.temp
                    if (d.desc) root.weatherDesc = d.desc
                    if (d.city) root.weatherCity = d.city
                    if (d.feels) root.weatherFeels = d.feels
                    if (d.humidity) root.weatherHumidity = d.humidity
                    if (d.wind) root.weatherWind = d.wind
                    if (d.sunrise) root.weatherSunrise = d.sunrise
                    if (d.sunset) root.weatherSunset = d.sunset
                    if (Array.isArray(d.forecast)) root.weatherForecast = d.forecast
                } catch (e) {}
            }
        }
    }
}
