import QtQuick
import QtQuick.Effects
import Quickshell
import "../services"

/**
 * Material You Expressive Desktop Clock:
 * - Clean, bold M3 Primary digits with soft elevation shadow (date lives in Dynamic Island)
 */
Item {
    id: root
    implicitWidth: clockBox.width
    implicitHeight: clockBox.height

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    readonly property string timeStr: MusicState.clock24h
        ? Qt.formatTime(clock.date, "HH:mm")
        : Qt.formatTime(clock.date, "h:mm")

    Item {
        id: clockBox
        anchors.centerIn: parent
        width: timeText.implicitWidth + 24
        height: timeText.implicitHeight + 12

        Text {
            id: timeText
            anchors.centerIn: parent
            text: root.timeStr
            font.family: MusicState.fontClock
            font.pixelSize: 148
            font.weight: Font.Bold
            font.letterSpacing: 2
            color: MusicState.m3Primary
            visible: false
        }

        MultiEffect {
            anchors.fill: timeText
            source: timeText
            shadowEnabled: true
            shadowColor: Qt.rgba(0.0, 0.0, 0.0, 0.48)
            shadowBlur: 0.7
            shadowVerticalOffset: 6
            shadowHorizontalOffset: 0
            autoPaddingEnabled: true
        }
    }
}
