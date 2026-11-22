import QtQuick
import QtQuick.Layouts
import "../services"

/**
 * Floating Material You Wavy OSD Pill (Volume / Brightness / Keyboard Layout / Modes):
 * Dynamically sizes to fit text cleanly with zero overlap.
 */
Item {
    id: root
    width: SystemState.osdShowBar
        ? 264
        : Math.max(156, Math.round(osdLabelTxt.implicitWidth + osdValTxt.implicitWidth + 84))
    height: 48

    visible: ShellConfig.osdEnabled && opacity > 0.01
    opacity: SystemState.osdVisible ? 1.0 : 0.0
    scale: SystemState.osdVisible ? 1.0 : 0.90
    y: SystemState.osdVisible ? 0 : 12

    Behavior on opacity { M3Anim { duration: 220 } }
    Behavior on scale   { M3Anim { duration: 300 } }
    Behavior on y       { M3Anim { duration: 300 } }
    Behavior on width   { M3Anim { duration: 240 } }

    Rectangle {
        anchors.fill: parent
        radius: 24
        color: MusicState.m3SurfaceContainerHigh
        border.width: 1
        border.color: MusicState.m3OutlineVariant

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 10

            SysIcon {
                name: SystemState.osdIcon
                size: 18
                color: SystemState.osdShowBar ? MusicState.m3Primary : MusicState.m3Tertiary
                Layout.alignment: Qt.AlignVCenter
            }

            M3WavyBar {
                visible: SystemState.osdShowBar
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter
                value: SystemState.osdValue
                activeColor: MusicState.m3Primary
                trackColor: MusicState.m3SurfaceContainerHigh
                lineWidth: 5.5
                amplitude: 3.4
                showThumb: false
                interactive: false
                animated: SystemState.osdVisible && SystemState.osdValue > 0.01
            }

            Text {
                id: osdLabelTxt
                visible: !SystemState.osdShowBar
                text: SystemState.osdLabel
                color: MusicState.m3OnSurfaceVariant
                font.family: MusicState.fontUi
                font.pixelSize: 12
                font.weight: Font.Medium
                Layout.alignment: Qt.AlignVCenter
            }

            Item {
                visible: !SystemState.osdShowBar
                Layout.fillWidth: true
            }

            Text {
                id: osdValTxt
                text: SystemState.osdText
                color: MusicState.m3OnSurface
                font.family: MusicState.fontUi
                font.pixelSize: 13
                font.weight: Font.Bold
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
