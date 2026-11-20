import QtQuick
import QtQuick.Effects
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
    readonly property bool desktopIsEmpty: !currentWs || !currentWs.toplevels || !currentWs.toplevels.values || currentWs.toplevels.values.length === 0

    Rectangle {
        anchors.fill: parent
        color: "#09090D"
    }

    // --- Layer A: Cinematic Animated Album Art + Fluid Color Orbs ---
    Item {
        id: fluidArtLayer
        anchors.fill: parent

        Image {
            id: bgArt
            anchors.centerIn: parent
            width: parent.width * 1.28
            height: parent.height * 1.28
            source: MusicState.artUrl
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
            visible: bgArt.status === Image.Ready
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
            color: Qt.rgba(MusicState.accentColor.r, MusicState.accentColor.g, MusicState.accentColor.b, 0.28)
            Behavior on color { ColorAnimation { duration: 1000 } }
            visible: bgArt.status !== Image.Ready

            SequentialAnimation on x {
                running: orb1.visible && root.desktopIsEmpty
                loops: Animation.Infinite
                NumberAnimation { from: -orb1.width * 0.18; to: root.width * 0.25; duration: 12000; easing.type: Easing.InOutSine }
                NumberAnimation { from: root.width * 0.25; to: -orb1.width * 0.18; duration: 12000; easing.type: Easing.InOutSine }
            }
        }

        Rectangle {
            id: orb2
            width: root.width * 0.55
            height: width
            radius: width / 2
            x: root.width * 0.55
            y: root.height * 0.35
            color: Qt.rgba(MusicState.secondaryAccentColor.r, MusicState.secondaryAccentColor.g, MusicState.secondaryAccentColor.b, 0.25)
            Behavior on color { ColorAnimation { duration: 1000 } }
            visible: bgArt.status !== Image.Ready

            SequentialAnimation on y {
                running: orb2.visible && root.desktopIsEmpty
                loops: Animation.Infinite
                NumberAnimation { from: root.height * 0.15; to: root.height * 0.45; duration: 10000; easing.type: Easing.InOutSine }
                NumberAnimation { from: root.height * 0.45; to: root.height * 0.15; duration: 10000; easing.type: Easing.InOutSine }
            }
        }
    }

    // --- Layer B: Persistent Native QtMultimedia Live Video Player ---
    Loader {
        id: videoLoader
        anchors.fill: parent
        active: MusicState.videoWallpaperEnabled && MusicState.videoEngine === "qtmultimedia"
        source: "VideoPlayerCore.qml"
        onLoaded: {
            if (item) item.monitorScreen = Qt.binding(function() { return root.monitorScreen })
        }
    }

    // Subtle cinematic vignette
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.0, 0.0, 0.0, 0.30) }
            GradientStop { position: 0.45; color: Qt.rgba(0.0, 0.0, 0.0, 0.08) }
            GradientStop { position: 1.0; color: Qt.rgba(0.0, 0.0, 0.0, 0.46) }
        }
    }
}
