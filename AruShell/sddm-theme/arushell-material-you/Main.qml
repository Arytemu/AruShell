import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#0C0D12"

    readonly property string fontMain: config.FontFamily || "Google Sans"
    readonly property color accentCol: config.AccentColor || "#D0BCFF"
    readonly property color onAccentCol: config.OnAccentColor || "#381E72"
    readonly property color surfaceCol: config.SurfaceColor || "#16171E"
    readonly property color surfaceHighCol: config.SurfaceHighColor || "#22242E"
    readonly property color onSurfaceCol: config.OnSurfaceColor || "#E6E1E5"
    readonly property color onSurfaceVarCol: config.OnSurfaceVariantColor || "#CAC4D0"

    property int userIdx: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIdx: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property string errorMsg: ""
    property date nowDate: new Date()

    function currentUserName() {
        if (!userModel || userModel.count <= 0) return ""
        return userModel.data(userModel.index(userIdx, 0), Qt.UserRole + 1) || userModel.lastUser || ""
    }

    function currentSessionName() {
        if (!sessionModel || sessionModel.count <= 0) return "Hyprland"
        return sessionModel.data(sessionModel.index(sessionIdx, 0), Qt.UserRole + 4) || "Session"
    }

    function doLogin() {
        errorMsg = ""
        sddm.login(currentUserName(), passInput.text, sessionIdx)
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.errorMsg = "Неверный пароль"
            passInput.text = ""
            passInput.forceActiveFocus()
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.nowDate = new Date()
    }

    // Background Gradient + Optional Wallpaper
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#13121C" }
            GradientStop { position: 0.55; color: "#0D0E14" }
            GradientStop { position: 1.0; color: "#090A0F" }
        }
    }

    Image {
        anchors.fill: parent
        visible: config.Background && config.Background !== ""
        source: config.Background || ""
        fillMode: Image.PreserveAspectCrop
        opacity: 0.55
    }

    // Subtle Material You Ambient Glow Orbs
    Rectangle {
        width: root.width * 0.45
        height: width
        radius: width / 2
        x: -width * 0.15
        y: -height * 0.25
        color: root.accentCol
        opacity: 0.10
    }
    Rectangle {
        width: root.width * 0.40
        height: width
        radius: width / 2
        x: root.width * 0.65
        y: root.height * 0.55
        color: root.accentCol
        opacity: 0.08
    }

    // Top Clock & Date (Google Sans)
    Column {
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: 86
        }
        spacing: 6

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(root.nowDate, "HH:mm")
            color: root.onSurfaceCol
            font.family: root.fontMain
            font.pixelSize: 96
            font.weight: Font.Black
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(root.nowDate, "dddd, d MMMM")
            color: root.onSurfaceVarCol
            font.family: root.fontMain
            font.pixelSize: 20
            font.weight: Font.Medium
        }
    }

    // Center Material You Login Card
    Rectangle {
        id: loginCard
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 44
        width: 380
        height: cardCol.implicitHeight + 48
        radius: 30
        color: root.surfaceCol

        ColumnLayout {
            id: cardCol
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 24
            }
            spacing: 16

            // Avatar + User Selector
            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Rectangle {
                    Layout.preferredWidth: 52
                    Layout.preferredHeight: 52
                    radius: 26
                    color: root.accentCol

                    Text {
                        anchors.centerIn: parent
                        text: root.currentUserName() ? root.currentUserName().slice(0, 1).toUpperCase() : "U"
                        color: root.onAccentCol
                        font.family: root.fontMain
                        font.pixelSize: 22
                        font.weight: Font.Bold
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: root.currentUserName() || "User"
                        color: root.onSurfaceCol
                        font.family: root.fontMain
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }

                    Text {
                        text: userModel.count > 1 ? "Нажмите для смены пользователя" : "Вход в систему"
                        color: root.onSurfaceVarCol
                        font.family: root.fontMain
                        font.pixelSize: 12
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    visible: userModel.count > 1
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.userIdx = (root.userIdx + 1) % userModel.count
                }
            }

            // Password Input Pill
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                radius: 24
                color: root.surfaceHighCol
                border.width: passInput.activeFocus ? 2 : 0
                border.color: root.accentCol

                TextInput {
                    id: passInput
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    color: root.onSurfaceCol
                    selectionColor: root.accentCol
                    font.family: root.fontMain
                    font.pixelSize: 15
                    focus: true
                    onAccepted: root.doLogin()

                    Component.onCompleted: forceActiveFocus()

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Пароль..."
                        color: root.onSurfaceVarCol
                        opacity: 0.7
                        font.family: root.fontMain
                        font.pixelSize: 14
                        visible: passInput.text === ""
                    }
                }
            }

            // Error Message
            Text {
                visible: root.errorMsg !== ""
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.errorMsg
                color: "#F2B8B5"
                font.family: root.fontMain
                font.pixelSize: 12
                font.weight: Font.SemiBold
            }

            // Login Button Pill
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                radius: 23
                color: loginMa.containsMouse ? Qt.lighter(root.accentCol, 1.07) : root.accentCol

                Text {
                    anchors.centerIn: parent
                    text: "Войти"
                    color: root.onAccentCol
                    font.family: root.fontMain
                    font.pixelSize: 14
                    font.weight: Font.Bold
                }

                MouseArea {
                    id: loginMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.doLogin()
                }
            }

            // Session Switcher Pill
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: 32
                Layout.preferredWidth: sessTxt.implicitWidth + 24
                radius: 16
                color: sessMa.containsMouse ? root.surfaceHighCol : "transparent"

                Text {
                    id: sessTxt
                    anchors.centerIn: parent
                    text: "Сессия: " + root.currentSessionName()
                    color: root.onSurfaceVarCol
                    font.family: root.fontMain
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: sessMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (sessionModel.count > 0) {
                            root.sessionIdx = (root.sessionIdx + 1) % sessionModel.count
                        }
                    }
                }
            }
        }
    }

    // Bottom Power Bar (Suspend / Reboot / Power Off)
    Rectangle {
        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
            bottomMargin: 32
        }
        height: 46
        width: pwrRow.implicitWidth + 20
        radius: 23
        color: root.surfaceCol

        Row {
            id: pwrRow
            anchors.centerIn: parent
            spacing: 8

            Repeater {
                model: [
                    { label: "Сон",         act: "suspend",  en: sddm.canSuspend },
                    { label: "Перезагрузка", act: "reboot",   en: sddm.canReboot },
                    { label: "Выключить",    act: "poweroff", en: sddm.canPowerOff }
                ]

                delegate: Rectangle {
                    required property var modelData
                    visible: modelData.en
                    height: 34
                    width: pTxt.implicitWidth + 24
                    radius: 17
                    color: pMa.containsMouse ? (modelData.act === "poweroff" ? "#B3261E" : root.surfaceHighCol) : "transparent"

                    Text {
                        id: pTxt
                        anchors.centerIn: parent
                        text: modelData.label
                        color: root.onSurfaceCol
                        font.family: root.fontMain
                        font.pixelSize: 12
                        font.weight: Font.SemiBold
                    }

                    MouseArea {
                        id: pMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.act === "suspend") sddm.suspend()
                            else if (modelData.act === "reboot") sddm.reboot()
                            else if (modelData.act === "poweroff") sddm.powerOff()
                        }
                    }
                }
            }
        }
    }
}
