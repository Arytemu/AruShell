import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../services"

/**
 * Material 3 Expressive Wallpaper Carousel (SUPER + W):
 * - Smooth cover-flow horizontal carousel of local wallpapers
 * - Keyboard navigation (Left/Right/Enter/Esc), mouse wheel, click to preview & apply
 * - Random wallpaper button & live rescan
 */
PanelWindow {
    id: wpWin

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "arushell-wallpapers"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    property bool folderBarOpen: false

    Item {
        id: rootItem
        anchors.fill: parent
        focus: true
        Component.onCompleted: {
            forceActiveFocus()
            if (WallpaperState.wallpapers.length > 0) {
                carousel.currentIndex = WallpaperState.currentIndex
            }
        }

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                WallpaperState.open = false
                event.accepted = true
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_A) {
                if (WallpaperState.wallpapers.length > 0) {
                    carousel.currentIndex = (carousel.currentIndex - 1 + WallpaperState.wallpapers.length) % WallpaperState.wallpapers.length
                    WallpaperState.selectIndex(carousel.currentIndex)
                }
                event.accepted = true
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_D) {
                if (WallpaperState.wallpapers.length > 0) {
                    carousel.currentIndex = (carousel.currentIndex + 1) % WallpaperState.wallpapers.length
                    WallpaperState.selectIndex(carousel.currentIndex)
                }
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                WallpaperState.selectIndex(carousel.currentIndex)
                WallpaperState.open = false
                event.accepted = true
            }
        }

        // Click dimmed backdrop to close
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.45)
            MouseArea {
                anchors.fill: parent
                onClicked: WallpaperState.open = false
            }
        }

        // Floating Material You Carousel Container
        Rectangle {
            id: dockCard
            anchors {
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
                bottomMargin: 42
            }
            width: Math.min(parent.width - 80, 1120)
            height: wpWin.folderBarOpen ? 416 : 336
            Behavior on height { M3Anim { duration: 280 } }
            radius: 32
            color: MusicState.m3SurfaceContainer
            clip: true

            MouseArea { anchors.fill: parent }

            WheelHandler {
                onWheel: function(event) {
                    if (WallpaperState.wallpapers.length === 0) return
                    const step = event.angleDelta.y > 0 ? -1 : 1
                    carousel.currentIndex = (carousel.currentIndex + step + WallpaperState.wallpapers.length) % WallpaperState.wallpapers.length
                    WallpaperState.selectIndex(carousel.currentIndex)
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14

                // Header Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Item {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        M3Shape {
                            anchors.fill: parent
                            shape: "cookie6"
                            fillColor: MusicState.m3PrimaryContainer
                        }
                        SysIcon {
                            anchors.centerIn: parent
                            name: "palette"
                            size: 15
                            color: MusicState.m3OnPrimaryContainer
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            text: "Обои рабочего стола"
                            color: MusicState.m3OnSurface
                            font.family: MusicState.fontUi
                            font.pixelSize: 15
                            font.weight: Font.Bold
                        }
                        Text {
                            text: WallpaperState.wallpapers.length > 0
                                ? ((carousel.currentIndex + 1) + " из " + WallpaperState.wallpapers.length + " · " + (WallpaperState.wallpapers[carousel.currentIndex] ? WallpaperState.wallpapers[carousel.currentIndex].name : ""))
                                : "Положите картинки в ~/Pictures/Wallpapers"
                            color: MusicState.m3OnSurfaceVariant
                            font.family: MusicState.fontUi
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }

                    // Add Custom Folder Pill
                    Rectangle {
                        Layout.preferredHeight: 34
                        Layout.preferredWidth: fldBtnTxt.implicitWidth + 22
                        radius: 17
                        color: wpWin.folderBarOpen ? MusicState.m3Primary : (fldBtnMa.containsMouse ? MusicState.m3SurfaceContainerHighest : MusicState.m3SurfaceContainerHigh)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text {
                            id: fldBtnTxt
                            anchors.centerIn: parent
                            text: "+ Папка"
                            color: wpWin.folderBarOpen ? MusicState.m3OnPrimary : MusicState.m3OnSurface
                            font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.Bold
                        }
                        MouseArea {
                            id: fldBtnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: wpWin.folderBarOpen = !wpWin.folderBarOpen
                        }
                    }

                    // Random Wallpaper Pill
                    Rectangle {
                        visible: WallpaperState.wallpapers.length > 1
                        Layout.preferredHeight: 34
                        Layout.preferredWidth: rndTxt.implicitWidth + 22
                        radius: 17
                        color: rndMa.containsMouse ? MusicState.m3Primary : MusicState.m3PrimaryContainer
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text {
                            id: rndTxt
                            anchors.centerIn: parent
                            text: "Случайные"
                            color: rndMa.containsMouse ? MusicState.m3OnPrimary : MusicState.m3OnPrimaryContainer
                            font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.Bold
                        }
                        MouseArea {
                            id: rndMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                WallpaperState.pickRandom()
                                carousel.currentIndex = WallpaperState.currentIndex
                            }
                        }
                    }

                    // Rescan Button
                    Rectangle {
                        Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 17
                        color: rscMa.containsMouse ? MusicState.m3SurfaceContainerHighest : MusicState.m3SurfaceContainerHigh
                        SysIcon { anchors.centerIn: parent; name: "refresh"; size: 15; color: MusicState.m3OnSurface }
                        MouseArea { id: rscMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: WallpaperState.scan() }
                    }

                    // Close Button
                    Rectangle {
                        Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 17
                        color: clsMa.containsMouse ? MusicState.m3SurfaceContainerHighest : MusicState.m3SurfaceContainerHigh
                        SysIcon { anchors.centerIn: parent; name: "close"; size: 15; color: MusicState.m3OnSurface }
                        MouseArea { id: clsMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: WallpaperState.open = false }
                    }
                }

                // Custom Folders Manager Bar
                ColumnLayout {
                    visible: wpWin.folderBarOpen
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            radius: 18
                            color: MusicState.m3SurfaceContainerHigh

                            TextInput {
                                id: dirInput
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                verticalAlignment: TextInput.AlignVCenter
                                color: MusicState.m3OnSurface
                                font.family: MusicState.fontUi
                                font.pixelSize: 12
                                clip: true
                                onAccepted: {
                                    if (text.trim() !== "") {
                                        WallpaperState.addCustomFolder(text)
                                        text = ""
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Путь к папке (например ~/Wallpapers или /mnt/data/walls)..."
                                    color: MusicState.m3OnSurfaceVariant
                                    font.family: MusicState.fontUi
                                    font.pixelSize: 11
                                    visible: dirInput.text === ""
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredHeight: 36
                            Layout.preferredWidth: addOkTxt.implicitWidth + 20
                            radius: 18
                            color: MusicState.m3Primary
                            Text { id: addOkTxt; anchors.centerIn: parent; text: "Добавить"; color: MusicState.m3OnPrimary; font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (dirInput.text.trim() !== "") {
                                        WallpaperState.addCustomFolder(dirInput.text)
                                        dirInput.text = ""
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredHeight: 36
                            Layout.preferredWidth: brwTxt.implicitWidth + 20
                            radius: 18
                            color: MusicState.m3PrimaryContainer
                            Text { id: brwTxt; anchors.centerIn: parent; text: "Обзор..."; color: MusicState.m3OnPrimaryContainer; font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: WallpaperState.browseFolderDialog()
                            }
                        }
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: (ShellConfig.wallpaperDirs || []).length > 0

                        Repeater {
                            model: ShellConfig.wallpaperDirs || []
                            delegate: Rectangle {
                                required property string modelData
                                height: 26
                                width: chipRow.implicitWidth + 16
                                radius: 13
                                color: MusicState.m3SurfaceContainerHigh

                                RowLayout {
                                    id: chipRow
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text { text: modelData; color: MusicState.m3OnSurface; font.family: MusicState.fontUi; font.pixelSize: 11 }
                                    SysIcon { name: "close"; size: 11; color: MusicState.m3OnSurfaceVariant }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: WallpaperState.removeCustomFolder(modelData)
                                }
                            }
                        }
                    }
                }

                // Cover-Flow Horizontal Carousel
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                        id: carousel
                        anchors.fill: parent
                        orientation: ListView.Horizontal
                        spacing: 16
                        clip: true
                        highlightRangeMode: ListView.StrictlyEnforceRange
                        preferredHighlightBegin: (width - 340) / 2
                        preferredHighlightEnd: (width + 340) / 2
                        highlightMoveDuration: 340
                        model: WallpaperState.wallpapers

                        delegate: Item {
                            required property var modelData
                            required property int index
                            readonly property bool isCur: index === carousel.currentIndex

                            width: 340
                            height: carousel.height

                            Rectangle {
                                anchors.centerIn: parent
                                width: 332
                                height: 196
                                radius: 24
                                color: MusicState.m3SurfaceContainerHigh
                                scale: isCur ? 1.0 : 0.88
                                opacity: isCur ? 1.0 : 0.62
                                border.width: isCur ? 3 : 0
                                border.color: MusicState.m3Primary

                                Behavior on scale   { M3Anim { duration: 300 } }
                                Behavior on opacity { M3Anim { duration: 240 } }

                                ClippingRectangle {
                                    anchors.fill: parent
                                    anchors.margins: isCur ? 3 : 0
                                    radius: isCur ? 21 : 24
                                    color: MusicState.m3SurfaceContainer

                                    Image {
                                        anchors.fill: parent
                                        source: "file://" + modelData.path
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        sourceSize: Qt.size(640, 360)
                                    }

                                    // Filename pill at bottom of card
                                    Rectangle {
                                        anchors {
                                            bottom: parent.bottom
                                            left: parent.left
                                            right: parent.right
                                            margins: 10
                                        }
                                        height: 28
                                        radius: 14
                                        color: Qt.rgba(0, 0, 0, 0.62)

                                        Text {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 12
                                            verticalAlignment: Text.AlignVCenter
                                            text: modelData.name
                                            color: "#FFFFFF"
                                            font.family: MusicState.fontUi
                                            font.pixelSize: 11
                                            font.weight: Font.SemiBold
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (isCur) {
                                            WallpaperState.selectIndex(index)
                                            WallpaperState.open = false
                                        } else {
                                            carousel.currentIndex = index
                                            WallpaperState.selectIndex(index)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Left Arrow Button (Previous Wallpaper)
                    Rectangle {
                        id: prevWpBtn
                        visible: WallpaperState.wallpapers.length > 1
                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                            leftMargin: 6
                        }
                        width: 44
                        height: 44
                        radius: 22
                        z: 15
                        color: prevWpMa.containsMouse ? MusicState.m3Primary : MusicState.m3SurfaceContainerHigh
                        Behavior on color { ColorAnimation { duration: 150 } }

                        SysIcon {
                            anchors.centerIn: parent
                            name: "chevron_left"
                            size: 20
                            color: prevWpMa.containsMouse ? MusicState.m3OnPrimary : MusicState.m3OnSurface
                        }

                        MouseArea {
                            id: prevWpMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                carousel.currentIndex = (carousel.currentIndex - 1 + WallpaperState.wallpapers.length) % WallpaperState.wallpapers.length
                                WallpaperState.selectIndex(carousel.currentIndex)
                            }
                        }
                    }

                    // Right Arrow Button (Next Wallpaper)
                    Rectangle {
                        id: nextWpBtn
                        visible: WallpaperState.wallpapers.length > 1
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            rightMargin: 6
                        }
                        width: 44
                        height: 44
                        radius: 22
                        z: 15
                        color: nextWpMa.containsMouse ? MusicState.m3Primary : MusicState.m3SurfaceContainerHigh
                        Behavior on color { ColorAnimation { duration: 150 } }

                        SysIcon {
                            anchors.centerIn: parent
                            name: "chevron_right"
                            size: 20
                            color: nextWpMa.containsMouse ? MusicState.m3OnPrimary : MusicState.m3OnSurface
                        }

                        MouseArea {
                            id: nextWpMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                carousel.currentIndex = (carousel.currentIndex + 1) % WallpaperState.wallpapers.length
                                WallpaperState.selectIndex(carousel.currentIndex)
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: WallpaperState.wallpapers.length === 0 && !WallpaperState.scanning
                        text: "Обои не найдены — добавьте картинки в ~/Pictures/Wallpapers"
                        color: MusicState.m3OnSurfaceVariant
                        font.family: MusicState.fontUi
                        font.pixelSize: 13
                    }
                }
            }
        }
    }
}
