pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

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
    property bool launcherOpen: false
    property string quickSettingsSubmenu: "" // "" | "wifi" | "bt" | "audio"

    // Network
    property bool wifiEnabled: false
    property string wifiSsid: ""
    property bool ethernetConnected: false
    property var wifiNetworks: []

    // Bluetooth
    property bool btEnabled: false
    property string btDevice: ""
    property var btDevices: []

    // Audio
    property int volume: 50
    property bool muted: false
    property var audioSinks: []

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

    // Daily-driver extras
    property string kbdLayout: "EN"
    property bool nightLight: false
    property string powerProfile: ""

    // Weather
    property string weatherTemp: ""
    property string weatherDesc: ""
    property string weatherCity: ""

    // OSD Pill State
    property bool osdVisible: false
    property string osdIcon: "volume_high"
    property string osdLabel: ""
    property real osdValue: 0.0
    property bool osdShowBar: true
    property string osdText: ""
    property bool _firstPollDone: false

    readonly property string sysScript: Qt.resolvedUrl("sysinfo.sh").toString().replace("file://", "")

    function showOsd(icon, label, valueRatio, textVal, showBar) {
        osdIcon = icon
        osdLabel = label
        osdValue = Math.max(0.0, Math.min(1.0, valueRatio))
        osdText = textVal
        osdShowBar = showBar !== false
        osdVisible = true
        osdHideTimer.restart()
    }

    Timer {
        id: osdHideTimer
        interval: 1800
        repeat: false
        onTriggered: root.osdVisible = false
    }

    function toggleLauncher() {
        launcherOpen = !launcherOpen
        if (launcherOpen) {
            quickSettingsOpen = false
            quickSettingsSubmenu = ""
            ClipboardState.open = false
            NotifState.closeAllPopups()
        }
    }

    function toggleQuickSettings() {
        launcherOpen = false
        ClipboardState.open = false
        quickSettingsOpen = !quickSettingsOpen
        if (quickSettingsOpen) {
            quickSettingsSubmenu = ""
            NotifState.closeAllPopups()
            refreshAll()
        }
    }

    function openSubmenu(name) {
        quickSettingsSubmenu = name
        if (name === "wifi") refreshWifiList()
        else if (name === "bt") refreshBtList()
        else if (name === "audio") refreshAudioSinks()
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

    function connectWifi(ssid) {
        if (!ssid) return
        runCmd("nmcli dev wifi connect " + JSON.stringify(ssid))
        quickSettingsSubmenu = ""
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

    function toggleNightLight() {
        nightLight = !nightLight
        if (nightLight) {
            Quickshell.execDetached(["bash", "-c", "pkill -x hyprsunset 2>/dev/null || true; hyprsunset -t 4200 >/dev/null 2>&1 &"])
        } else {
            Quickshell.execDetached(["bash", "-c", "pkill -x hyprsunset 2>/dev/null || true"])
        }
        delayedRefresh.restart()
    }

    function cyclePowerProfile() {
        if (!powerProfile) return
        const order = ["power-saver", "balanced", "performance"]
        const idx = order.indexOf(powerProfile)
        const next = order[(idx + 1) % order.length]
        powerProfile = next
        runCmd("powerprofilesctl set " + next)
    }

    function switchKeyboardLayout() {
        runCmd("bash " + JSON.stringify(sysScript) + " switch-layout")
    }

    function lockScreen() {
        quickSettingsOpen = false
        launcherOpen = false
        Quickshell.execDetached(["bash", "-c", "hyprlock 2>/dev/null || swaylock 2>/dev/null || loginctl lock-session"])
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

    function refreshWifiList() {
        if (!wifiListProc.running) {
            wifiListProc.command = ["bash", sysScript, "wifi-list"]
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
        interval: 1500
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
                    root.kbdLayout = d.kbdLayout || "EN"

                    // Auto-trigger OSD when hardware keys change volume, brightness, or layout!
                    if (root._firstPollDone) {
                        if (root.volume !== prevVol || root.muted !== prevMuted) {
                            const ic = (root.muted || root.volume === 0) ? "volume_mute" : (root.volume < 45 ? "volume_low" : "volume_high")
                            root.showOsd(ic, "Звук", root.muted ? 0 : (root.volume / 100.0), root.muted ? "Выкл" : (root.volume + "%"), true)
                        } else if (root.hasBrightness && root.brightness !== prevBr) {
                            root.showOsd("brightness", "Яркость", root.brightness / 100.0, root.brightness + "%", true)
                        } else if (root.kbdLayout !== prevKbd) {
                            root.showOsd("apps", "Раскладка", 1.0, root.kbdLayout, false)
                        }
                    } else {
                        root._firstPollDone = true
                    }
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
                } catch (e) {}
            }
        }
    }
}
