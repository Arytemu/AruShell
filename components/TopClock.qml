import QtQuick
import QtQuick.Effects
import Quickshell
import "../services"

/**
 * Material You (Pixel Lock Screen style) Expressive Clock:
 * - Tonal M3 date pill above clean, bold M3 Primary digits with soft elevation shadow
 * - Zero borders or outlines
 */
Item {
    id: root
    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    readonly property string dateStr: Qt.formatDate(clock.date, "ddd, MMM d")
    readonly property string timeStr: MusicState.clock24h
        ? Qt.formatTime(clock.date, "HH:mm")
        : Qt.formatTime(clock.date, "h:mm")

    Column {
        id: col
        anchors.centerIn: parent
        spacing: 2

        // Material 3 Tonal Date Chip
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            height: 28
            width: dateText.implicitWidth + 24
            radius: 14
            color: MusicState.m3SurfaceContainer

            Text {
                id: dateText
                anchors.centerIn: parent
                text: root.dateStr
                color: MusicState.m3OnSurface
                font.family: MusicState.fontUi
                font.pixelSize: 13
                font.weight: Font.SemiBold
                font.letterSpacing: 0.4
            }
        }

        // Bold Material You Expressive Digits
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
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
}
