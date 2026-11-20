import QtQuick
import QtQuick.Effects

/**
 * Crisp modern Material/Lucide SVG icon with automatic Material You tinting.
 */
Item {
    id: root
    property string name: ""
    property int size: 17
    property color color: "#FFFFFF"

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    Image {
        id: img
        anchors.fill: parent
        source: root.name ? ("../assets/sys/" + root.name + ".svg") : ""
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        smooth: true
        visible: false
    }

    MultiEffect {
        anchors.fill: img
        source: img
        colorization: 1.0
        colorizationColor: root.color
    }
}
