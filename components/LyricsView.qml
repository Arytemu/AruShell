import QtQuick
import QtQuick.Effects
import "../services"

/**
 * Material You Kinetic Synchronized Lyrics:
 * - Clean borderless typography (no jagged Text.Outline) with soft MultiEffect shadow
 * - Active line highlights in M3 Primary with spring pop
 * - Inactive lines softly blur and dim
 */
Item {
    id: root
    width: 480
    height: 360

    Connections {
        target: MusicState
        function onCurrentLyricIndexChanged() {
            if (MusicState.currentLyricIndex >= 0 && MusicState.currentLyricIndex < lyricsList.count) {
                lyricsList.positionViewAtIndex(MusicState.currentLyricIndex, ListView.Center)
            }
        }
    }

    ListView {
        id: lyricsList
        anchors.fill: parent
        opacity: MusicState.moodFontOpacity
        scale: MusicState.moodFontScale
        clip: true
        spacing: 16
        model: MusicState.lyricsLines
        highlightMoveDuration: 340
        preferredHighlightBegin: height * 0.36
        preferredHighlightEnd: height * 0.56
        highlightRangeMode: ListView.ApplyRange

        delegate: Item {
            width: lyricsList.width
            height: lyricText.implicitHeight + 12

            readonly property int dist: MusicState.lyricsSynced && MusicState.currentLyricIndex >= 0
                ? Math.abs(index - MusicState.currentLyricIndex)
                : 0
            readonly property bool isActive: MusicState.lyricsSynced && index === MusicState.currentLyricIndex

            Item {
                width: parent.width
                height: lyricText.implicitHeight
                scale: isActive ? 1.0 : 0.92
                transformOrigin: Item.Left

                Behavior on scale {
                    NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.08 }
                }

                Text {
                    id: lyricText
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: modelData.text || ""
                    font.family: MusicState.trackMoodFont
                    font.italic: MusicState.trackMoodItalic
                    font.letterSpacing: MusicState.trackMoodSpacing
                    font.pixelSize: MusicState.trackGenre === "rap" ? (isActive ? 34 : (dist === 1 ? 23 : 19)) : (isActive ? 28 : (dist === 1 ? 19 : 16))
                    font.weight: isActive ? Font.Black : Font.DemiBold
                    color: isActive
                        ? MusicState.m3Primary
                        : Qt.rgba(MusicState.m3OnSurface.r, MusicState.m3OnSurface.g, MusicState.m3OnSurface.b, dist === 1 ? 0.62 : 0.28)
                    visible: false

                    Behavior on font.pixelSize { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 240 } }
                }

                MultiEffect {
                    anchors.fill: lyricText
                    source: lyricText
                    shadowEnabled: true
                    shadowColor: Qt.rgba(0.0, 0.0, 0.0, isActive ? 0.65 : 0.42)
                    shadowBlur: 0.55
                    shadowVerticalOffset: 3
                    blurEnabled: !isActive
                    blur: dist === 1 ? 0.16 : 0.38
                    blurMax: 12
                    autoPaddingEnabled: true
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: MusicState.lyricsSynced && modelData.time >= 0
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: MusicState.seekTo(modelData.time)
            }
        }

    }
}
