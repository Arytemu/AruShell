import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import SddmComponents 2.0

/**
 * AruShell Material You SDDM Theme — 1-to-1 match with AruShell Caelestia LockScreen (Super+L):
 * - Guaranteed soft high-contrast light typography on dark Material You surfaces (never black text!)
 * - Left column: Time-of-day greeting card with spinning cookie6 emblem + arushellfetch.sh with official
 *   CachyOS faceted logo + interactive session pills card
 * - Center column: Giant Bebas Neue clock (HHmm), date, Cookie8 avatar (~/.face), animated password pill
 * - Right column: Crisp SVG Sleep / Reboot / Power Off trio + Users list card
 */
Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#090B10"

    FontLoader {
        id: lockClockFont
        source: "BebasNeue-Regular.ttf"
    }

    readonly property string fontMain: config.FontFamily || "Google Sans"
    readonly property color _rawAccent: config.AccentColor || "#9AE6C8"
    readonly property color accentCol: _rawAccent.hslLightness < 0.45 ? Qt.lighter(_rawAccent, 1.8) : _rawAccent
    readonly property color textOnAccentCol: "#101C17"
    readonly property color primaryContCol: config.PrimaryContainerColor || "#1E4739"
    readonly property color textOnPrimaryContCol: "#F0FBF6"
    readonly property color surfaceCol: config.SurfaceColor || "#141A18"
    readonly property color surfaceHighCol: config.SurfaceHighColor || "#1E2623"
    // Always soft light typography so text & clock NEVER turn dark/black on blurred dark backdrop
    readonly property color textCol: "#F2F5F3"
    readonly property color textMutedCol: "#B9C5BF"
    readonly property color outlineCol: config.OutlineColor || "#35423D"

    property int userIdx: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIdx: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property string errorMsg: ""
    property date nowDate: new Date()
    property int animStage: 0

    readonly property real cardTargetW: Math.min(1200, Math.max(920, root.width * 0.72))
    readonly property real cardTargetH: Math.min(680, Math.max(540, root.height * 0.70))
    readonly property string hrStr: Qt.formatTime(nowDate, "HH")
    readonly property string minStr: Qt.formatTime(nowDate, "mm")
    readonly property string dateStr: Qt.formatDate(nowDate, "dddd · d MMM").toUpperCase()
    readonly property int curHour: nowDate.getHours()
    readonly property string greetingStr: curHour < 6 ? "Доброй ночи" : (curHour < 12 ? "Доброе утро" : (curHour < 18 ? "Добрый день" : "Добрый вечер"))

    function currentUserName() {
        if (!userModel || userModel.count <= 0) return ""
        return userModel.data(userModel.index(userIdx, 0), Qt.UserRole + 1) || userModel.lastUser || ""
    }

    function currentSessionName() {
        if (!sessionModel || sessionModel.count <= 0) return "Hyprland"
        return sessionModel.data(sessionModel.index(sessionIdx, 0), Qt.UserRole + 4) || "Hyprland"
    }

    function currentLayoutCode() {
        try {
            if (keyboard && keyboard.layouts && keyboard.layouts.length > 0) {
                var idx = keyboard.currentLayout >= 0 ? keyboard.currentLayout : 0
                var sn = keyboard.layouts[idx].shortName || "EN"
                return String(sn).slice(0, 2).toUpperCase()
            }
        } catch (e) {}
        return "EN"
    }

    function doLogin() {
        if (passInput.text.length === 0) return
        errorMsg = ""
        sddm.login(currentUserName(), passInput.text, sessionIdx)
    }

    Timer {
        interval: 30
        running: true
        repeat: false
        onTriggered: {
            root.animStage = 1
            stage2Timer.restart()
            passInput.forceActiveFocus()
        }
    }

    Timer {
        id: stage2Timer
        interval: 340
        repeat: false
        onTriggered: {
            root.animStage = 2
            passInput.forceActiveFocus()
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.nowDate = new Date()
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.errorMsg = "Неверный пароль"
            passInput.text = ""
            shakeAnim.restart()
            passInput.forceActiveFocus()
        }
    }

    // =========================================================================
    // 1. BLURRED WALLPAPER BACKDROP WITH ANIMATED ZOOM
    // =========================================================================
    Item {
        id: bgSource
        anchors.fill: parent
        visible: false

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#13151F" }
                GradientStop { position: 1.0; color: "#090B10" }
            }
        }

        Image {
            anchors.fill: parent
            source: config.Background && config.Background !== "" ? config.Background : "background.jpg"
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: bgSource
        blurEnabled: true
        blurMax: 64
        blur: root.animStage >= 1 ? 0.86 : 0.0
        brightness: root.animStage >= 1 ? -0.18 : 0.0
        scale: root.animStage >= 1 ? 1.05 : 1.0
        autoPaddingEnabled: false

        Behavior on blur       { NumberAnimation { duration: 480; easing.type: Easing.OutCubic } }
        Behavior on brightness { NumberAnimation { duration: 460; easing.type: Easing.InOutCubic } }
        Behavior on scale      { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.34)
        opacity: root.animStage >= 1 ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 420 } }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: passInput.forceActiveFocus()
    }

    TextInput {
        id: passInput
        width: 1; height: 1
        opacity: 0
        focus: true
        echoMode: TextInput.Password
        onAccepted: root.doLogin()
        Component.onCompleted: forceActiveFocus()
    }

    // =========================================================================
    // 2. STAGE-1 TILTED CENTER LOCK SQUIRCLE BADGE
    // =========================================================================
    Rectangle {
        anchors.centerIn: parent
        width: 112
        height: 112
        radius: 30
        color: root.surfaceCol
        border.width: 1.5
        border.color: root.outlineCol
        z: 20

        opacity: root.animStage === 1 ? 1.0 : 0.0
        scale: root.animStage === 0 ? 0.35 : (root.animStage === 1 ? 1.0 : 1.35)
        rotation: root.animStage === 0 ? -24 : (root.animStage === 1 ? -10 : 0)
        visible: opacity > 0.01

        Behavior on opacity  { NumberAnimation { duration: root.animStage === 1 ? 240 : 180; easing.type: Easing.OutCubic } }
        Behavior on scale    { NumberAnimation { duration: root.animStage === 1 ? 340 : 220; easing.type: root.animStage === 1 ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.3 } }
        Behavior on rotation { NumberAnimation { duration: 320; easing.type: Easing.OutBack } }

        Image {
            id: badgeLockIc
            anchors.centerIn: parent
            width: 42; height: 42
            source: "icons/lock.svg"
            sourceSize: Qt.size(84, 84)
            visible: false
        }
        MultiEffect {
            anchors.fill: badgeLockIc
            source: badgeLockIc
            colorization: 1.0
            colorizationColor: root.textCol
        }
    }

    // =========================================================================
    // 3. STAGE-2 FLOATING 3-COLUMN CAELESTIA BENTO CARD
    // =========================================================================
    Rectangle {
        id: lockCard
        anchors.centerIn: parent
        width: root.animStage >= 2 ? root.cardTargetW : 120
        height: root.animStage >= 2 ? root.cardTargetH : 120
        radius: root.animStage >= 2 ? 34 : 30
        color: Qt.rgba(root.surfaceCol.r, root.surfaceCol.g, root.surfaceCol.b, 0.94)
        border.width: 1
        border.color: root.outlineCol
        clip: true
        opacity: root.animStage >= 2 ? 1.0 : 0.0

        Behavior on width   { NumberAnimation { duration: 460; easing.type: Easing.OutExpo } }
        Behavior on height  { NumberAnimation { duration: 460; easing.type: Easing.OutExpo } }
        Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 22
            opacity: root.animStage >= 2 ? 1.0 : 0.0
            scale: root.animStage >= 2 ? 1.0 : 0.94
            Behavior on opacity { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
            Behavior on scale   { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

            // -----------------------------------------------------------------
            // LEFT COLUMN (~300px): Greeting Card + arushellfetch.sh + Session Selector Card
            // -----------------------------------------------------------------
            ColumnLayout {
                Layout.preferredWidth: 300
                Layout.fillHeight: true
                spacing: 14

                // 1. Time-of-Day Greeting Card with Spinning Cookie6 Emblem
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 122
                    Layout.maximumHeight: 122
                    radius: 24
                    color: root.surfaceHighCol

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 14

                        Item {
                            Layout.preferredWidth: 56
                            Layout.preferredHeight: 56

                            Canvas {
                                anchors.fill: parent
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    var cx = width / 2, cy = height / 2
                                    var baseR = width * 0.43, amp = baseR * 0.11
                                    ctx.beginPath()
                                    for (var i = 0; i <= 120; i++) {
                                        var a = (i / 120) * Math.PI * 2
                                        var r = baseR + amp * Math.cos(6 * a)
                                        var px = cx + r * Math.cos(a)
                                        var py = cy + r * Math.sin(a)
                                        if (i === 0) ctx.moveTo(px, py)
                                        else ctx.lineTo(px, py)
                                    }
                                    ctx.closePath()
                                    var c = root.primaryContCol
                                    ctx.fillStyle = "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + ",1)"
                                    ctx.fill()
                                }
                                NumberAnimation on rotation {
                                    from: 0; to: 360; duration: 24000; loops: Animation.Infinite; running: visible
                                }
                            }

                            Image {
                                id: greetIc
                                anchors.centerIn: parent
                                width: 22; height: 22
                                source: "icons/moon.svg"
                                sourceSize: Qt.size(44, 44)
                                visible: false
                            }
                            MultiEffect {
                                anchors.fill: greetIc
                                source: greetIc
                                colorization: 1.0
                                colorizationColor: root.accentCol
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            Text {
                                text: root.greetingStr
                                color: root.textMutedCol
                                font.family: root.fontMain
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }
                            Text {
                                Layout.fillWidth: true
                                text: root.currentUserName() || "User"
                                color: root.textCol
                                font.family: root.fontMain
                                font.pixelSize: 22
                                font.weight: Font.Black
                                elide: Text.ElideRight
                            }
                            Text {
                                text: sddm.hostName || "AruShell"
                                color: root.accentCol
                                font.family: root.fontMain
                                font.pixelSize: 11
                                font.weight: Font.Bold
                            }
                        }
                    }
                }

                // 2. arushellfetch.sh Card with Official Faceted CachyOS Logo
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 214
                    Layout.maximumHeight: 214
                    radius: 24
                    color: root.surfaceHighCol

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Rectangle {
                                Layout.preferredWidth: 24; Layout.preferredHeight: 24; radius: 12
                                color: root.primaryContCol
                                Text { anchors.centerIn: parent; text: ">_"; color: root.textOnPrimaryContCol; font.family: "monospace"; font.pixelSize: 10; font.weight: Font.Bold }
                            }
                            Text { text: "arushellfetch.sh"; color: root.textCol; font.family: "monospace"; font.pixelSize: 13; font.weight: Font.Bold }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 14

                            Canvas {
                                id: cachyLogo
                                Layout.preferredWidth: 64
                                Layout.preferredHeight: 64
                                Layout.alignment: Qt.AlignVCenter
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    var c = root.accentCol
                                    var mainCol = "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + ",1)"
                                    var darkCol = "rgba(" + Math.round(c.r * 195) + "," + Math.round(c.g * 195) + "," + Math.round(c.b * 195) + ",0.92)"
                                    var lightCol = "rgba(" + Math.min(255, Math.round(c.r * 255 + 45)) + "," + Math.min(255, Math.round(c.g * 255 + 45)) + "," + Math.min(255, Math.round(c.b * 255 + 45)) + ",1)"

                                    ctx.fillStyle = lightCol
                                    ctx.beginPath()
                                    ctx.moveTo(20, 10); ctx.lineTo(44, 10); ctx.lineTo(39, 19); ctx.lineTo(25, 19)
                                    ctx.closePath(); ctx.fill()

                                    ctx.fillStyle = mainCol
                                    ctx.beginPath()
                                    ctx.moveTo(20, 10); ctx.lineTo(25, 19); ctx.lineTo(16, 32); ctx.lineTo(7, 32)
                                    ctx.closePath(); ctx.fill()

                                    ctx.fillStyle = darkCol
                                    ctx.beginPath()
                                    ctx.moveTo(7, 32); ctx.lineTo(16, 32); ctx.lineTo(25, 45); ctx.lineTo(20, 54)
                                    ctx.closePath(); ctx.fill()

                                    ctx.fillStyle = mainCol
                                    ctx.beginPath()
                                    ctx.moveTo(20, 54); ctx.lineTo(25, 45); ctx.lineTo(44, 45); ctx.lineTo(49, 54)
                                    ctx.closePath(); ctx.fill()

                                    ctx.fillStyle = lightCol
                                    ctx.beginPath(); ctx.arc(51, 20, 4.2, 0, Math.PI * 2); ctx.fill()
                                    ctx.fillStyle = mainCol
                                    ctx.beginPath(); ctx.arc(56, 32, 3.2, 0, Math.PI * 2); ctx.fill()
                                    ctx.fillStyle = darkCol
                                    ctx.beginPath(); ctx.arc(46, 36, 5.2, 0, Math.PI * 2); ctx.fill()
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 5

                                Repeater {
                                    model: [
                                        { k: "OS",   v: "CachyOS" },
                                        { k: "WM",   v: root.currentSessionName() },
                                        { k: "USER", v: root.currentUserName() || "user" },
                                        { k: "HOST", v: sddm.hostName || "linux" }
                                    ]
                                    delegate: RowLayout {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Text { Layout.preferredWidth: 40; text: modelData.k; color: root.accentCol; font.family: "monospace"; font.pixelSize: 12; font.weight: Font.Bold }
                                        Text { text: ":"; color: root.textMutedCol; font.family: "monospace"; font.pixelSize: 12 }
                                        Text { Layout.fillWidth: true; text: modelData.v; color: root.textCol; font.family: "monospace"; font.pixelSize: 12; elide: Text.ElideRight }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 11
                            Repeater {
                                model: [root.textCol, root.accentCol, root.textOnPrimaryContCol, root.primaryContCol, root.textMutedCol, root.surfaceHighCol, root.surfaceCol]
                                delegate: Rectangle {
                                    required property color modelData
                                    width: 15; height: 15; radius: 7.5
                                    color: modelData
                                    border.width: 1; border.color: root.outlineCol
                                }
                            }
                        }
                    }
                }

                // 3. Interactive Sessions List Card (fills bottom of left column cleanly!)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 24
                    color: root.surfaceHighCol

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8

                        Text {
                            text: "Рабочая сессия"
                            color: root.textMutedCol
                            font.family: root.fontMain
                            font.pixelSize: 12
                            font.weight: Font.SemiBold
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 6
                            model: sessionModel

                            delegate: Rectangle {
                                required property int index
                                required property string name
                                readonly property bool isSel: index === root.sessionIdx
                                width: ListView.view ? ListView.view.width : 260
                                height: 38
                                radius: 14
                                color: isSel ? root.primaryContCol : root.surfaceCol
                                Behavior on color { ColorAnimation { duration: 140 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12; anchors.rightMargin: 12
                                    spacing: 8

                                    Rectangle {
                                        width: 8; height: 8; radius: 4
                                        color: isSel ? root.accentCol : root.outlineCol
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: name
                                        color: isSel ? root.textOnPrimaryContCol : root.textCol
                                        font.family: root.fontMain
                                        font.pixelSize: 12
                                        font.weight: isSel ? Font.Bold : Font.Medium
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.sessionIdx = index
                                        passInput.forceActiveFocus()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // -----------------------------------------------------------------
            // CENTER COLUMN: Giant Light Bebas Neue Clock + Date + Cookie8 Avatar + Password Pill
            // -----------------------------------------------------------------
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                Item { Layout.fillHeight: true }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.hrStr + root.minStr
                    color: root.textCol
                    font.family: lockClockFont.status === FontLoader.Ready ? lockClockFont.name : root.fontMain
                    font.pixelSize: 138
                    font.letterSpacing: 2
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: -16
                    text: root.dateStr
                    color: root.textMutedCol
                    font.family: root.fontMain
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    font.letterSpacing: 1.6
                }

                Item { Layout.preferredHeight: 14 }

                // Material 3 Expressive Cookie8 Avatar
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 192
                    Layout.preferredHeight: 192

                    Canvas {
                        id: cookieMask
                        anchors.fill: parent
                        layer.enabled: true
                        visible: avatarImg.status !== Image.Ready
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cx = width / 2, cy = height / 2
                            var baseR = Math.min(width, height) * 0.445
                            var amp = baseR * 0.088
                            ctx.beginPath()
                            var steps = 160
                            for (var i = 0; i <= steps; i++) {
                                var a = (i / steps) * Math.PI * 2
                                var r = baseR + amp * Math.cos(8 * a)
                                var px = cx + r * Math.cos(a)
                                var py = cy + r * Math.sin(a)
                                if (i === 0) ctx.moveTo(px, py)
                                else ctx.lineTo(px, py)
                            }
                            ctx.closePath()
                            var c = avatarImg.status === Image.Ready ? Qt.rgba(1, 1, 1, 1) : root.primaryContCol
                            ctx.fillStyle = "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + ",1)"
                            ctx.fill()
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: avatarImg.status !== Image.Ready
                        text: root.currentUserName() ? root.currentUserName().slice(0, 1).toUpperCase() : "A"
                        color: root.textOnPrimaryContCol
                        font.family: root.fontMain
                        font.pixelSize: 68
                        font.weight: Font.Black
                    }

                    Image {
                        id: avatarImg
                        anchors.fill: parent
                        source: "avatar.png"
                        fillMode: Image.PreserveAspectCrop
                        visible: false
                        onStatusChanged: cookieMask.requestPaint()
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: avatarImg
                        visible: avatarImg.status === Image.Ready
                        maskEnabled: true
                        maskSource: cookieMask
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: userModel.count > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (userModel.count > 1) root.userIdx = (root.userIdx + 1) % userModel.count
                            passInput.forceActiveFocus()
                        }
                    }
                }

                Item { Layout.preferredHeight: 16 }

                // Caelestia Password Pill
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 332
                    Layout.preferredHeight: 56

                    Rectangle {
                        id: passBox
                        width: parent.width
                        height: parent.height
                        x: 0
                        radius: 28
                        color: root.surfaceHighCol
                        border.width: root.errorMsg !== "" ? 2 : 1
                        border.color: root.errorMsg !== "" ? "#F2B8B5" : (passInput.text.length > 0 ? root.accentCol : root.outlineCol)
                        Behavior on border.color { ColorAnimation { duration: 160 } }

                        SequentialAnimation {
                            id: shakeAnim
                            NumberAnimation { target: passBox; property: "x"; to: -13; duration: 45; easing.type: Easing.OutQuad }
                            NumberAnimation { target: passBox; property: "x"; to:  13; duration: 60; easing.type: Easing.InOutQuad }
                            NumberAnimation { target: passBox; property: "x"; to:  -9; duration: 50; easing.type: Easing.InOutQuad }
                            NumberAnimation { target: passBox; property: "x"; to:   9; duration: 50; easing.type: Easing.InOutQuad }
                            NumberAnimation { target: passBox; property: "x"; to:   0; duration: 45; easing.type: Easing.OutQuad }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 10
                            spacing: 10

                            Item {
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                Layout.alignment: Qt.AlignVCenter
                                Image {
                                    id: pwLockIc
                                    anchors.fill: parent
                                    source: "icons/lock.svg"
                                    sourceSize: Qt.size(32, 32)
                                    visible: false
                                }
                                MultiEffect {
                                    anchors.fill: pwLockIc
                                    source: pwLockIc
                                    colorization: 1.0
                                    colorizationColor: root.errorMsg !== "" ? "#F2B8B5" : root.textMutedCol
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true

                                Text {
                                    anchors.centerIn: parent
                                    visible: passInput.text.length === 0
                                    text: "Введите пароль"
                                    color: root.textMutedCol
                                    opacity: 0.78
                                    font.family: root.fontMain
                                    font.pixelSize: 14
                                }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    visible: passInput.text.length > 0

                                    Repeater {
                                        model: Math.min(12, passInput.text.length)
                                        delegate: Rectangle {
                                            required property int index
                                            width: 16
                                            height: 16
                                            radius: (index % 3 === 0) ? 8 : ((index % 3 === 1) ? 5 : 3)
                                            rotation: (index % 3 === 2) ? 45 : 0
                                            color: root.accentCol
                                            scale: 0.15
                                            opacity: 0.0
                                            Component.onCompleted: { scale = 1.0; opacity = 1.0 }
                                            Behavior on scale   { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
                                            Behavior on opacity { NumberAnimation { duration: 120 } }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.preferredHeight: 28
                                Layout.preferredWidth: kbdChipTxt.implicitWidth + 16
                                radius: 14
                                color: root.surfaceCol
                                Text {
                                    id: kbdChipTxt
                                    anchors.centerIn: parent
                                    text: root.currentLayoutCode()
                                    color: root.textCol
                                    font.family: root.fontMain
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 36; Layout.preferredHeight: 36
                                radius: subMa.containsMouse ? 12 : 18
                                color: root.accentCol
                                Behavior on radius { NumberAnimation { duration: 160 } }

                                Image {
                                    id: subArrowIc
                                    anchors.centerIn: parent
                                    width: 16; height: 16
                                    source: "icons/chevron_right.svg"
                                    sourceSize: Qt.size(32, 32)
                                    visible: false
                                }
                                MultiEffect {
                                    anchors.fill: subArrowIc
                                    source: subArrowIc
                                    colorization: 1.0
                                    colorizationColor: root.textOnAccentCol
                                }

                                MouseArea { id: subMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.doLogin() }
                            }
                        }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.errorMsg !== ""
                    text: root.errorMsg
                    color: "#F2B8B5"
                    font.family: root.fontMain
                    font.pixelSize: 13
                    font.weight: Font.Bold
                }

                Item { Layout.fillHeight: true }
            }

            // -----------------------------------------------------------------
            // RIGHT COLUMN (~300px): Crisp SVG Power Cards + Users List
            // -----------------------------------------------------------------
            ColumnLayout {
                Layout.preferredWidth: 300
                Layout.fillHeight: true
                spacing: 14

                // 1. Power Actions Trio (always visible cleanly even in --test-mode!)
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.preferredHeight: 118
                    Layout.minimumHeight: 118
                    Layout.maximumHeight: 118
                    spacing: 10

                    Repeater {
                        model: [
                            { label: "Сон",   icon: "icons/moon.svg",   act: "suspend",  en: sddm.canSuspend },
                            { label: "Ребут", icon: "icons/reboot.svg", act: "reboot",   en: sddm.canReboot },
                            { label: "Выкл",  icon: "icons/power.svg",  act: "poweroff", en: sddm.canPowerOff }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 118
                            Layout.maximumHeight: 118
                            opacity: modelData.en ? 1.0 : 0.72
                            radius: pwrMa.containsMouse ? 16 : 22
                            color: pwrMa.containsMouse
                                ? (modelData.act === "poweroff" ? "#B3261E" : root.primaryContCol)
                                : root.surfaceHighCol
                            Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Behavior on color  { ColorAnimation  { duration: 160 } }

                            Column {
                                anchors.centerIn: parent
                                spacing: 10

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 42; height: 42; radius: 21
                                    color: pwrMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : root.surfaceCol

                                    Image {
                                        id: pwrSvg
                                        anchors.centerIn: parent
                                        width: 20; height: 20
                                        source: modelData.icon
                                        sourceSize: Qt.size(40, 40)
                                        visible: false
                                    }
                                    MultiEffect {
                                        anchors.fill: pwrSvg
                                        source: pwrSvg
                                        colorization: 1.0
                                        colorizationColor: pwrMa.containsMouse ? "#FFFFFF" : root.accentCol
                                    }
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.label
                                    color: pwrMa.containsMouse ? "#FFFFFF" : root.textCol
                                    font.family: root.fontMain
                                    font.pixelSize: 12
                                    font.weight: Font.SemiBold
                                }
                            }

                            MouseArea {
                                id: pwrMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.act === "suspend" && sddm.canSuspend) sddm.suspend()
                                    else if (modelData.act === "reboot" && sddm.canReboot) sddm.reboot()
                                    else if (modelData.act === "poweroff" && sddm.canPowerOff) sddm.powerOff()
                                }
                            }
                        }
                    }
                }

                // 2. Users & Session Info Card
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 24
                    color: root.surfaceHighCol

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10

                        Text {
                            text: "Учётные записи"
                            color: root.textMutedCol
                            font.family: root.fontMain
                            font.pixelSize: 13
                            font.weight: Font.SemiBold
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 8
                            model: userModel

                            delegate: Rectangle {
                                required property int index
                                required property string name
                                readonly property bool isSel: index === root.userIdx
                                width: ListView.view ? ListView.view.width : 240
                                height: 48
                                radius: 16
                                color: isSel ? root.primaryContCol : root.surfaceCol
                                Behavior on color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12; anchors.rightMargin: 12
                                    spacing: 10

                                    Rectangle {
                                        Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: 15
                                        color: isSel ? root.accentCol : root.surfaceHighCol
                                        Text { anchors.centerIn: parent; text: name ? name.slice(0, 1).toUpperCase() : "U"; color: isSel ? root.textOnAccentCol : root.textCol; font.family: root.fontMain; font.pixelSize: 13; font.weight: Font.Bold }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: name
                                        color: isSel ? root.textOnPrimaryContCol : root.textCol
                                        font.family: root.fontMain
                                        font.pixelSize: 13
                                        font.weight: isSel ? Font.Bold : Font.Medium
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.userIdx = index
                                        passInput.forceActiveFocus()
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "AruShell · Material You"
                            color: root.textMutedCol
                            opacity: 0.65
                            font.family: root.fontMain
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }
}
