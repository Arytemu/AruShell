import QtQuick
import QtMultimedia
import "../services"

/**
 * Built-in QtMultimedia Audio Player:
 * Plays Yandex Music / SoundCloud / YouTube Music tracks directly inside Quickshell
 * without opening a browser tab, while keeping progress bar, lyrics, and video synced.
 */
Item {
    id: root
    visible: false

    MediaPlayer {
        id: audioPlayer
        audioOutput: AudioOutput {
            volume: 1.0
            muted: false
        }

        onPlaybackStateChanged: {
            MusicState.internalPlaying = (playbackState === MediaPlayer.PlayingState)
        }
        onPositionChanged: {
            MusicState.internalPosition = position / 1000.0
        }
        onDurationChanged: {
            MusicState.internalDuration = duration / 1000.0
        }
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.EndOfMedia && MusicState.useInternalPlayer) {
                MusicState.nextTrack()
            }
        }
    }

    Connections {
        target: MusicState
        function onInternalPlayRequested(url) {
            audioPlayer.source = url
            audioPlayer.play()
        }
        function onInternalToggleRequested() {
            if (audioPlayer.playbackState === MediaPlayer.PlayingState) {
                audioPlayer.pause()
            } else {
                audioPlayer.play()
            }
        }
        function onInternalPauseRequested() {
            audioPlayer.pause()
        }
        function onInternalSeekRequested(seconds) {
            audioPlayer.position = Math.round(seconds * 1000)
        }
    }
}
