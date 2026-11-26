import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../services"

Item {
    id: root
    anchors.fill: parent

    property var parentPanel: null
    readonly property int islandHitWidth: island.width
    readonly property int islandHitHeight: island.height

    MouseArea {
        anchors.fill: parent
        enabled: NotifState.centerOpen || NotifState.islandExpanded || SystemState.quickSettingsOpen || SystemState.langMenuOpen || SystemState.launcherOpen || ClipboardState.open
        onClicked: {
            NotifState.closeAllPopups()
            SystemState.quickSettingsOpen = false
            SystemState.langMenuOpen = false
            SystemState.launcherOpen = false
            ClipboardState.open = false
        }
    }

    // Left slot: App Launcher (36x36, matches all topbar pills!) + Pac-Man Workspace Switcher
    RowLayout {
        id: leftSlot
        anchors {
            left: parent.left
            top: parent.top
            leftMargin: 12
            topMargin: 6
        }
        height: 36
        spacing: 8
        z: 10

        // Material 3 Expressive App Launcher Button (unified 36x36 height + outlineVariant border)
        Item {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            Layout.alignment: Qt.AlignVCenter

            M3Shape {
                anchors.fill: parent
                visible: ShellConfig.launcherImagePath === ""
                shape: ShellConfig.launcherShape
                morphFactor: 1.0
                fillColor: SystemState.launcherOpen
                    ? MusicState.m3PrimaryContainer
                    : (appBtnMa.containsMouse ? MusicState.m3SurfaceContainerHigh : MusicState.m3SurfaceContainer)
                strokeWidth: 1.1
                strokeColor: SystemState.launcherOpen ? MusicState.m3Primary : MusicState.m3OutlineVariant
                rotation: SystemState.launcherOpen ? 360 : 0
                scale: SystemState.launcherOpen ? 1.05 : (appBtnMa.containsMouse ? 1.03 : 1.0)
                Behavior on rotation { M3Anim { duration: 480 } }
                Behavior on scale    { M3Anim { duration: 240 } }
            }

            SysIcon {
                anchors.centerIn: parent
                visible: ShellConfig.launcherImagePath === ""
                name: "apps"
                size: 15
                color: SystemState.launcherOpen ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface
            }

            ClippingRectangle {
                anchors.fill: parent
                anchors.margins: 2
                visible: ShellConfig.launcherImagePath !== ""
                radius: 11
                color: MusicState.m3SurfaceContainer
                rotation: SystemState.launcherOpen ? 360 : 0
                scale: SystemState.launcherOpen ? 1.06 : (appBtnMa.containsMouse ? 1.04 : 1.0)
                Behavior on rotation { M3Anim { duration: 480 } }
                Behavior on scale    { M3Anim { duration: 240 } }

                Image {
                    anchors.fill: parent
                    source: ShellConfig.launcherImagePath !== "" ? ("file://" + ShellConfig.launcherImagePath) : ""
                    sourceSize: Qt.size(96, 96)
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    asynchronous: true
                }
            }

            MouseArea {
                id: appBtnMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: SystemState.toggleLauncher()
            }
        }

        PacmanWorkspaces {
            Layout.alignment: Qt.AlignVCenter
        }
    }

    // App Launcher Dropdown (anchored below left slot)
    Item {
        anchors {
            left: parent.left
            top: parent.top
            leftMargin: 10
            topMargin: 50
        }
        width: 440
        height: 490
        z: 20

        AppLauncher {
            anchors.left: parent.left
        }
    }

    // Center slot: Floating Pill Dynamic Island (aligned at topMargin: 6 with all other pills!)
    DynamicIsland {
        id: island
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            topMargin: 6
        }
        z: 10
    }

    // Right slot: Expandable System Tray + System Controls Pill + Notification Bell
    SystemTrayWidget {
        id: rightTray
        parentPanel: root.parentPanel
        anchors {
            right: parent.right
            top: parent.top
            rightMargin: 12
            topMargin: 6
        }
        z: 10
    }

    // Clipboard History Overlay (SUPER + V, centered)
    Item {
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            topMargin: 54
        }
        width: 420
        height: 440
        z: 25

        ClipboardOverlay {
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // Language / Keyboard Layout Dropdown (anchored below merged right pill)
    Item {
        anchors {
            right: parent.right
            top: parent.top
            rightMargin: 92
            topMargin: 52
        }
        width: 220
        height: 240
        z: 21

        LanguageMenu {
            anchors.right: parent.right
        }
    }

    // Quick Settings Dropdown (anchored below right cluster)
    Item {
        anchors {
            right: parent.right
            top: parent.top
            rightMargin: 12
            topMargin: 52
        }
        width: 360
        height: 420
        z: 20

        QuickSettings {
            anchors.right: parent.right
        }
    }

    // Notification Center Dropdown (anchored below bell)
    Item {
        anchors {
            right: parent.right
            top: parent.top
            rightMargin: 12
            topMargin: 52
        }
        width: 360
        height: 410
        z: 20

        NotificationCenter {
            anchors.right: parent.right
        }
    }
}
