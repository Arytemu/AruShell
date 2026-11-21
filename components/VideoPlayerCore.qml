import QtQuick
import QtMultimedia
import Quickshell.Hyprland
import "../services"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property var monitorScreen: null

    readonly property string streamUrl: MusicState.videoStreamUrl

    readonly property var currentWs: {
        if (monitorScreen) {
            const mon = Hyprland.monitorFor(monitorScreen)
            if (mon && mon.activeWorkspace) return mon.activeWorkspace
        }
        return Hyprland.focusedWorkspace
    }

    readonly property int openWindowCount: (currentWs && currentWs.toplevels && currentWs.toplevels.values)
        ? currentWs.toplevels.values.length
        : 0

    readonly property bool desktopIsEmpty: !ShellConfig.videoEmptyDesktopOnly || openWindowCount === 0
    readonly property bool shouldPlay: streamUrl !== "" && MusicState.hasTrack && MusicState.isPlaying && desktopIsEmpty

    function syncPlayback() {
        if (streamUrl === "" || !MusicState.hasTrack) {
            player.stop()
            player.source = ""
            return
        }
        if (String(player.source) !== streamUrl) {
            player.stop()
            player.source = streamUrl
        }
        if (shouldPlay) {
            player.play()
        } else {
            player.pause()
        }
    }

    onStreamUrlChanged: syncPlayback()
    onShouldPlayChanged: syncPlayback()
    Component.onCompleted: syncPlayback()

    Connections {
        target: MusicState
        function onHasTrackChanged() { root.syncPlayback() }
    }

    MediaPlayer {
        id: player
        loops: MediaPlayer.Infinite
        videoOutput: videoOut
        audioOutput: AudioOutput {
            muted: true
            volume: 0.0
        }

        onErrorOccurred: function(error, errorString) {
            console.warn("AruShell VideoPlayerCore error:", error, errorString)
        }
    }

    VideoOutput {
        id: videoOut
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        orientation: MusicState.videoRotation
        opacity: (root.streamUrl !== "" && MusicState.hasTrack && player.playbackState !== MediaPlayer.StoppedState) ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 420; easing.type: Easing.InOutCubic }
        }
    }
}
