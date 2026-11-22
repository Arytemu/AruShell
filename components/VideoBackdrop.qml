import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import "../services"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property var monitorScreen: null

    readonly property var currentWs: {
        if (monitorScreen) {
            const mon = Hyprland.monitorFor(monitorScreen)
            if (mon && mon.activeWorkspace) return mon.activeWorkspace
        }
        return Hyprland.focusedWorkspace
    }
    readonly property bool desktopIsEmpty: !ShellConfig.videoEmptyDesktopOnly || !currentWs || !currentWs.toplevels || !currentWs.toplevels.values || currentWs.toplevels.values.length === 0
    readonly property bool hasTiledWindow: {
        if (!currentWs || !currentWs.toplevels || !currentWs.toplevels.values) return false
        const list = currentWs.toplevels.values
        for (let i = 0; i < list.length; i++) {
            const tl = list[i]
            if (!tl) continue
            const isFloat = (tl.lastIpcObject && tl.lastIpcObject.floating === true)
            if (!isFloat) return true
        }
        return false
    }
    readonly property bool hasCustomWall: ShellConfig.wallpaperPath !== ""

    Rectangle {
        anchors.fill: parent
        color: "#09090D"
    }

    // Unified always-visible backdrop content (Wallpaper + Fluid Art + Live Video)
    // Keeping this always visible eliminates ANY black flash when blur animates in/out!
    Item {
        id: backdropContent
        anchors.fill: parent

        // --- Layer 0: Crisp User Wallpaper ---
        Image {
            id: userWallpaper
            anchors.fill: parent
            source: root.hasCustomWall ? ("file://" + ShellConfig.wallpaperPath) : ""
            sourceSize: Qt.size(Math.max(1280, Math.round(root.width)), Math.max(720, Math.round(root.height)))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            opacity: (root.hasCustomWall && status === Image.Ready) ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.InOutCubic } }
        }

        // --- Layer A: Blurred Animated Album Art (only when music is playing & not minimized) ---
        Item {
            id: fluidArtLayer
            anchors.fill: parent
            opacity: (!MusicState.stageMinimizedToIsland && MusicState.hasTrack && MusicState.artUrl !== "") ? 1.0 : (root.hasCustomWall ? 0.0 : 1.0)
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 480; easing.type: Easing.InOutCubic } }

            Image {
                id: bgArt
                anchors.centerIn: parent
                width: parent.width * 1.28
                height: parent.height * 1.28
                source: MusicState.artUrl
                sourceSize: Qt.size(480, 480)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                visible: false

                property real driftX: 0
                x: (parent.width - width) / 2 + driftX
            }

            SequentialAnimation {
                running: MusicState.artUrl !== "" && MusicState.isPlaying && root.desktopIsEmpty
                loops: Animation.Infinite
                ParallelAnimation {
                    NumberAnimation { target: bgArt; property: "scale"; from: 1.0; to: 1.12; duration: 14000; easing.type: Easing.InOutSine }
                    NumberAnimation { target: bgArt; property: "driftX"; from: -22; to: 22; duration: 14000; easing.type: Easing.InOutSine }
                }
                ParallelAnimation {
                    NumberAnimation { target: bgArt; property: "scale"; from: 1.12; to: 1.0; duration: 14000; easing.type: Easing.InOutSine }
                    NumberAnimation { target: bgArt; property: "driftX"; from: 22; to: -22; duration: 14000; easing.type: Easing.InOutSine }
                }
            }

            MultiEffect {
                anchors.fill: parent
                source: bgArt
                visible: MusicState.hasTrack && bgArt.status === Image.Ready
                blurEnabled: true
                blur: 0.72
                blurMax: 64
                saturation: 0.35
                brightness: -0.18
                autoPaddingEnabled: false
            }

            Rectangle {
                id: orb1
                width: root.width * 0.65
                height: width
                radius: width / 2
                x: -width * 0.15
                y: -height * 0.25
                color: Qt.rgba(MusicState.accentColor.r, MusicState.accentColor.g, MusicState.accentColor.b, 0.24)
                Behavior on color { ColorAnimation { duration: 1000 } }
                visible: !root.hasCustomWall && (!MusicState.hasTrack || bgArt.status !== Image.Ready)
            }

            Rectangle {
                id: orb2
                width: root.width * 0.55
                height: width
                radius: width / 2
                x: root.width * 0.55
                y: root.height * 0.35
                color: Qt.rgba(MusicState.secondaryAccentColor.r, MusicState.secondaryAccentColor.g, MusicState.secondaryAccentColor.b, 0.22)
                Behavior on color { ColorAnimation { duration: 1000 } }
                visible: !root.hasCustomWall && (!MusicState.hasTrack || bgArt.status !== Image.Ready)
            }
        }

        // --- Layer B: Persistent Native QtMultimedia Live Video Player ---
        Loader {
            id: videoLoader
            anchors.fill: parent
            active: MusicState.videoWallpaperEnabled && MusicState.videoEngine === "qtmultimedia"
            opacity: MusicState.stageMinimizedToIsland ? 0.0 : 1.0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.InOutCubic } }
            source: "VideoPlayerCore.qml"
            onLoaded: {
                if (item) item.monitorScreen = Qt.binding(function() { return root.monitorScreen })
            }
        }
    }

    // --- Layer C: Smooth GPU Blur Overlay over BOTH Wallpaper & Live Video when Tiled Window is open ---
    readonly property bool _shouldBlurBg: ShellConfig.blurTiledBg && root.hasTiledWindow
    MultiEffect {
        anchors.fill: parent
        source: backdropContent
        visible: blur > 0.005
        blurEnabled: true
        blur: root._shouldBlurBg ? 0.80 : 0.0
        blurMax: 52
        brightness: root._shouldBlurBg ? -0.10 : 0.0
        autoPaddingEnabled: false
        Behavior on blur { NumberAnimation { duration: 340; easing.type: Easing.InOutCubic } }
        Behavior on brightness { NumberAnimation { duration: 340; easing.type: Easing.InOutCubic } }
    }

    // Subtle cinematic vignette
    Rectangle {
        anchors.fill: parent
        readonly property bool musicBgActive: MusicState.hasTrack && !MusicState.stageMinimizedToIsland
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.0, 0.0, 0.0, parent.musicBgActive ? 0.30 : 0.14) }
            GradientStop { position: 0.45; color: Qt.rgba(0.0, 0.0, 0.0, parent.musicBgActive ? 0.08 : 0.02) }
            GradientStop { position: 1.0; color: Qt.rgba(0.0, 0.0, 0.0, parent.musicBgActive ? 0.46 : 0.22) }
        }
    }
}
