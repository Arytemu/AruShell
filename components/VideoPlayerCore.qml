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
    readonly property bool shouldPlay: streamUrl !== "" && MusicState.hasTrack && MusicState.isPlaying && desktopIsEmpty && !MusicState.stageMinimizedToIsland

    function syncPlayback() {
        if (streamUrl === "" || !MusicState.hasTrack) {
            pauseBrakeAnim.stop()
            resumeRampAnim.stop()
            player.playbackRate = 1.0
            player.stop()
            player.source = ""
            return
        }
        if (String(player.source) !== streamUrl) {
            pauseBrakeAnim.stop()
            resumeRampAnim.stop()
            player.playbackRate = 1.0
            player.stop()
            player.source = streamUrl
        }
        if (shouldPlay) {
            pauseBrakeAnim.stop()
            if (player.playbackState !== MediaPlayer.PlayingState) {
                player.playbackRate = 0.25
                player.play()
                resumeRampAnim.restart()
            } else if (player.playbackRate < 0.99) {
                resumeRampAnim.restart()
            }
        } else {
            resumeRampAnim.stop()
            if (player.playbackState === MediaPlayer.PlayingState) {
                pauseBrakeAnim.restart()
            }
        }
    }

    // Smooth cinematic slow-down before pausing (no jarring freeze!)
    SequentialAnimation {
        id: pauseBrakeAnim
        NumberAnimation {
            target: player
            property: "playbackRate"
            to: 0.18
            duration: 440
            easing.type: Easing.OutCubic
        }
        ScriptAction {
            script: {
                if (!root.shouldPlay) player.pause()
            }
        }
    }

    // Smooth ramp-up when resuming playback
    NumberAnimation {
        id: resumeRampAnim
        target: player
        property: "playbackRate"
        to: 1.0
        duration: 360
        easing.type: Easing.OutCubic
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
        opacity: (root.streamUrl !== "" && MusicState.hasTrack && MusicState.isPlaying && root.desktopIsEmpty && !MusicState.stageMinimizedToIsland) ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 420; easing.type: Easing.InOutCubic }
        }
    }
}
