import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../services"

/**
 * 1-to-1 Caelestia Shell Lock Screen (WlSessionLock + PAM):
 * - Stage 1 (Lock-in): Desktop smoothly blurs (0 -> 0.86) while a tilted rounded-square Lock Badge
 *   pops in at center with spring overshoot.
 * - Stage 2 (Expand): The center Lock Badge morphs & expands directly into the floating rounded
 *   3-column Caelestia Bento Card (~74% screen), revealing Weather + arushellfetch.sh + Media on the left,
 *   giant Bebas Neue clock (HHmm) + Date + Circular Avatar + Password Pill in the center, and 3 vertical
 *   liquid Resource bars (CPU / RAM / BAT) + Notifications Dock on the right.
 * - Stage 3 (Unlock): Card collapses & fades smoothly while desktop unblurs back to live view.
 */
WlSessionLock {
    id: sessionLock
    locked: LockState.locked

    WlSessionLockSurface {
        id: surface

        FontLoader {
            id: lockClockFont
            source: "../assets/fonts/BebasNeue-Regular.ttf"
        }

        SystemClock {
            id: lockClock
            precision: SystemClock.Seconds
        }

        readonly property string hrStr: Qt.formatTime(lockClock.date, ShellConfig.clock24h ? "HH" : "hh")
        readonly property string minStr: Qt.formatTime(lockClock.date, "mm")
        readonly property string dateStr: Qt.formatDate(lockClock.date, "dddd · d MMM").toUpperCase()
        readonly property string homeDir: Quickshell.env("HOME") || ""

        Item {
            id: lockRoot
            anchors.fill: parent
            focus: true

            // Animation choreography:
            // 0 = initial frame (clear screen)
            // 1 = blur + center tilted lock squircle pops in
            // 2 = squircle expands into full floating Caelestia bento card
            property int animStage: 0
            readonly property bool isUnlocking: LockState.unlocking
            readonly property bool backdropActive: animStage >= 1 && !isUnlocking
            readonly property bool cardExpanded: animStage >= 2 && !isUnlocking

            readonly property real cardTargetW: Math.min(1240, Math.max(960, lockRoot.width * 0.74))
            readonly property real cardTargetH: Math.min(700, Math.max(560, lockRoot.height * 0.72))

            Timer {
                id: stage1Timer
                interval: 24
                running: true
                repeat: false
                onTriggered: {
                    lockRoot.animStage = 1
                    stage2Timer.restart()
                    passHidden.forceActiveFocus()
                }
            }

            Timer {
                id: stage2Timer
                interval: 340
                repeat: false
                onTriggered: {
                    if (!LockState.unlocking) {
                        lockRoot.animStage = 2
                        passHidden.forceActiveFocus()
                    }
                }
            }

            // =================================================================
            // 1. LIVE SCREEN CAPTURE + WALLPAPER FALLBACK + ANIMATED BLUR
            // =================================================================
            Item {
                id: backdropSource
                anchors.fill: parent
                visible: false

                Rectangle {
                    anchors.fill: parent
                    color: "#090B10"
                }

                Image {
                    anchors.fill: parent
                    source: ShellConfig.wallpaperPath ? ("file://" + ShellConfig.wallpaperPath) : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: false
                }

                ScreencopyView {
                    anchors.fill: parent
                    captureSource: Quickshell.screens.indexOf(surface.screen) !== -1 ? surface.screen : null
                    live: false
                }
            }

            MultiEffect {
                id: backdropBlur
                anchors.fill: parent
                source: backdropSource
                blurEnabled: true
                blurMax: 64
                blur: lockRoot.backdropActive ? 0.86 : 0.0
                brightness: lockRoot.backdropActive ? -0.14 : 0.0
                saturation: lockRoot.backdropActive ? 0.08 : 0.0
                scale: lockRoot.backdropActive ? 1.05 : 1.0
                autoPaddingEnabled: false

                Behavior on blur       { NumberAnimation { duration: lockRoot.backdropActive ? 480 : 320; easing.type: lockRoot.backdropActive ? Easing.OutCubic : Easing.InCubic } }
                Behavior on brightness { NumberAnimation { duration: lockRoot.backdropActive ? 460 : 320; easing.type: Easing.InOutCubic } }
                Behavior on scale      { NumberAnimation { duration: lockRoot.backdropActive ? 520 : 320; easing.type: lockRoot.backdropActive ? Easing.OutCubic : Easing.InCubic } }
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.28)
                opacity: lockRoot.backdropActive ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: lockRoot.backdropActive ? 420 : 280 } }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: passHidden.forceActiveFocus()
            }

            // Hidden real TextInput capturing keyboard
            TextInput {
                id: passHidden
                width: 1; height: 1
                opacity: 0
                focus: true
                echoMode: TextInput.Password
                text: LockState.passwordText
                onTextChanged: {
                    if (LockState.passwordText !== text) {
                        LockState.passwordText = text
                    }
                }
                onAccepted: LockState.submitPassword()

                Connections {
                    target: LockState
                    function onPasswordTextChanged() {
                        if (passHidden.text !== LockState.passwordText) {
                            passHidden.text = LockState.passwordText
                        }
                    }
                    function onWrongPasswordPulse() {
                        shakeAnim.restart()
                        passHidden.forceActiveFocus()
                    }
                }
            }

            // =================================================================
            // 2. STAGE-1 SIGNATURE CAELESTIA TILTED LOCK SQUIRCLE BADGE
            // =================================================================
            Rectangle {
                id: introLockBadge
                anchors.centerIn: parent
                width: 112
                height: 112
                radius: 30
                color: MusicState.m3SurfaceContainer
                border.width: 1.5
                border.color: MusicState.m3OutlineVariant
                z: 20

                opacity: (lockRoot.animStage === 1 && !lockRoot.isUnlocking) ? 1.0 : 0.0
                scale: lockRoot.animStage === 0 ? 0.35 : (lockRoot.animStage === 1 ? 1.0 : 1.35)
                rotation: lockRoot.animStage === 0 ? -24 : (lockRoot.animStage === 1 ? -10 : 0)
                visible: opacity > 0.01

                Behavior on opacity  { NumberAnimation { duration: lockRoot.animStage === 1 ? 240 : 180; easing.type: Easing.OutCubic } }
                Behavior on scale    { NumberAnimation { duration: lockRoot.animStage === 1 ? 340 : 220; easing.type: lockRoot.animStage === 1 ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.3 } }
                Behavior on rotation { NumberAnimation { duration: 320; easing.type: Easing.OutBack } }

                SysIcon {
                    anchors.centerIn: parent
                    name: "lock"
                    size: 46
                    color: MusicState.m3OnSurface
                }
            }

            // =================================================================
            // 3. STAGE-2 FLOATING CENTERED CAELESTIA BENTO CARD
            // =================================================================
            Rectangle {
                id: lockCard
                anchors.centerIn: parent
                width: lockRoot.cardExpanded ? lockRoot.cardTargetW : 120
                height: lockRoot.cardExpanded ? lockRoot.cardTargetH : 120
                radius: lockRoot.cardExpanded ? 34 : 30
                color: Qt.rgba(MusicState.m3SurfaceContainer.r, MusicState.m3SurfaceContainer.g, MusicState.m3SurfaceContainer.b, 0.94)
                border.width: 1
                border.color: MusicState.m3OutlineVariant
                clip: true

                opacity: lockRoot.cardExpanded ? 1.0 : 0.0
                scale: lockRoot.isUnlocking ? 0.84 : 1.0

                Behavior on width   { NumberAnimation { duration: lockRoot.cardExpanded ? 460 : 280; easing.type: lockRoot.cardExpanded ? Easing.OutExpo : Easing.InCubic } }
                Behavior on height  { NumberAnimation { duration: lockRoot.cardExpanded ? 460 : 280; easing.type: lockRoot.cardExpanded ? Easing.OutExpo : Easing.InCubic } }
                Behavior on opacity { NumberAnimation { duration: lockRoot.cardExpanded ? 260 : 220; easing.type: Easing.OutCubic } }
                Behavior on scale   { NumberAnimation { duration: 280; easing.type: Easing.InCubic } }

                RowLayout {
                    id: bentoGrid
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 22

                    opacity: lockRoot.cardExpanded ? 1.0 : 0.0
                    scale: lockRoot.cardExpanded ? 1.0 : 0.94
                    Behavior on opacity { NumberAnimation { duration: lockRoot.cardExpanded ? 360 : 140; easing.type: Easing.OutCubic } }
                    Behavior on scale   { NumberAnimation { duration: lockRoot.cardExpanded ? 420 : 160; easing.type: Easing.OutCubic } }

                    // ---------------------------------------------------------
                    // LEFT COLUMN (~300px): Weather + arushellfetch.sh + Media
                    // ---------------------------------------------------------
                    ColumnLayout {
                        Layout.preferredWidth: 300
                        Layout.fillHeight: true
                        spacing: 14

                        // 1. Caelestia Weather Card
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 152
                            Layout.maximumHeight: 152
                            radius: 24
                            color: MusicState.m3SurfaceContainerHigh

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 6

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: SystemState.weatherDesc !== "" ? SystemState.weatherDesc : "Погода"
                                    color: MusicState.m3OnSurfaceVariant
                                    font.family: MusicState.fontUi
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }

                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 12

                                    Text {
                                        text: SystemState.weatherTemp !== "" ? SystemState.weatherTemp : "—"
                                        color: MusicState.m3OnSurface
                                        font.family: MusicState.fontUi
                                        font.pixelSize: 38
                                        font.weight: Font.Black
                                    }

                                    Item {
                                        Layout.preferredWidth: 40
                                        Layout.preferredHeight: 40
                                        M3Shape {
                                            anchors.fill: parent
                                            shape: "cookie6"
                                            fillColor: MusicState.m3PrimaryContainer
                                            spin: true
                                            spinDuration: 24000
                                        }
                                        SysIcon {
                                            anchors.centerIn: parent
                                            name: "weather"
                                            size: 20
                                            color: MusicState.m3OnPrimaryContainer
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 1
                                    Layout.topMargin: 2
                                    color: MusicState.m3OutlineVariant
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: SystemState.weatherCity !== "" ? SystemState.weatherCity : "Локальный прогноз"
                                    color: MusicState.m3OnSurfaceVariant
                                    font.family: MusicState.fontUi
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        // 2. Caelestia Fetch Card (arushellfetch.sh + Logo + OS/WM/USER/UP + Palette Dots)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 186
                            radius: 24
                            color: MusicState.m3SurfaceContainerHigh

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Rectangle {
                                        Layout.preferredWidth: 24
                                        Layout.preferredHeight: 24
                                        radius: 12
                                        color: MusicState.m3PrimaryContainer
                                        Text {
                                            anchors.centerIn: parent
                                            text: ">_"
                                            color: MusicState.m3OnPrimaryContainer
                                            font.family: MusicState.fontUi
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                        }
                                    }

                                    Text {
                                        text: "arushellfetch.sh"
                                        color: MusicState.m3OnSurface
                                        font.family: MusicState.fontUi
                                        font.pixelSize: 13
                                        font.weight: Font.Bold
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 14

                                    Canvas {
                                        id: hexLogoCanvas
                                        Layout.preferredWidth: 58
                                        Layout.preferredHeight: 58
                                        Layout.alignment: Qt.AlignVCenter
                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.clearRect(0, 0, width, height)
                                            var cx = width / 2, cy = height / 2, r = 24
                                            var c = MusicState.m3Primary
                                            var mainCol = "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + ",1)"
                                            var darkCol = "rgba(" + Math.round(c.r * 195) + "," + Math.round(c.g * 195) + "," + Math.round(c.b * 195) + ",0.92)"
                                            var lightCol = "rgba(" + Math.min(255, Math.round(c.r * 255 + 45)) + "," + Math.min(255, Math.round(c.g * 255 + 45)) + "," + Math.min(255, Math.round(c.b * 255 + 45)) + ",1)"
                                            var sc = width / 64.0
                                            ctx.save(); ctx.scale(sc, sc)
                                            ctx.fillStyle = lightCol
                                            ctx.beginPath(); ctx.moveTo(20, 10); ctx.lineTo(44, 10); ctx.lineTo(39, 19); ctx.lineTo(25, 19); ctx.closePath(); ctx.fill()
                                            ctx.fillStyle = mainCol
                                            ctx.beginPath(); ctx.moveTo(20, 10); ctx.lineTo(25, 19); ctx.lineTo(16, 32); ctx.lineTo(7, 32); ctx.closePath(); ctx.fill()
                                            ctx.fillStyle = darkCol
                                            ctx.beginPath(); ctx.moveTo(7, 32); ctx.lineTo(16, 32); ctx.lineTo(25, 45); ctx.lineTo(20, 54); ctx.closePath(); ctx.fill()
                                            ctx.fillStyle = mainCol
                                            ctx.beginPath(); ctx.moveTo(20, 54); ctx.lineTo(25, 45); ctx.lineTo(44, 45); ctx.lineTo(49, 54); ctx.closePath(); ctx.fill()
                                            ctx.fillStyle = lightCol; ctx.beginPath(); ctx.arc(51, 20, 4.2, 0, Math.PI * 2); ctx.fill()
                                            ctx.fillStyle = mainCol; ctx.beginPath(); ctx.arc(56, 32, 3.2, 0, Math.PI * 2); ctx.fill()
                                            ctx.fillStyle = darkCol; ctx.beginPath(); ctx.arc(46, 36, 5.2, 0, Math.PI * 2); ctx.fill()
                                            ctx.restore()
                                        }
                                        Connections {
                                            target: MusicState
                                            function onM3PrimaryChanged() { hexLogoCanvas.requestPaint() }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 5

                                        Repeater {
                                            model: [
                                                { k: "OS",   v: "CachyOS" },
                                                { k: "WM",   v: "Hyprland" },
                                                { k: "USER", v: SystemState.userName || "user" },
                                                { k: "UP",   v: SystemState.uptimeText || "active" }
                                            ]
                                            delegate: RowLayout {
                                                required property var modelData
                                                Layout.fillWidth: true
                                                spacing: 6
                                                Text {
                                                    Layout.preferredWidth: 40
                                                    text: modelData.k
                                                    color: MusicState.m3Primary
                                                    font.family: MusicState.fontUi
                                                    font.pixelSize: 12
                                                    font.weight: Font.Bold
                                                }
                                                Text {
                                                    text: ":"
                                                    color: MusicState.m3OnSurfaceVariant
                                                    font.family: MusicState.fontUi
                                                    font.pixelSize: 12
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.v
                                                    color: MusicState.m3OnSurface
                                                    font.family: MusicState.fontUi
                                                    font.pixelSize: 12
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 11

                                    Repeater {
                                        model: [
                                            MusicState.m3OnSurface,
                                            MusicState.m3Primary,
                                            MusicState.m3OnPrimaryContainer,
                                            MusicState.m3PrimaryContainer,
                                            MusicState.m3OnSurfaceVariant,
                                            MusicState.m3SurfaceContainerHighest,
                                            MusicState.m3SurfaceContainer
                                        ]
                                        delegate: Rectangle {
                                            required property color modelData
                                            width: 15
                                            height: 15
                                            radius: 7.5
                                            color: modelData
                                            border.width: 1
                                            border.color: MusicState.m3OutlineVariant
                                        }
                                    }
                                }
                            }
                        }

                        // 3. Caelestia Media Card
                        ClippingRectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 160
                            Layout.maximumHeight: 160
                            radius: 24
                            color: MusicState.m3SurfaceContainerHigh

                            Image {
                                id: mediaBgImg
                    sourceSize: Qt.size(320, 320)
                                anchors.fill: parent
                                source: MusicState.artUrl
                                fillMode: Image.PreserveAspectCrop
                                visible: false
                                asynchronous: true
                            }

                            MultiEffect {
                                anchors.fill: parent
                                source: mediaBgImg
                                visible: MusicState.hasTrack && mediaBgImg.status === Image.Ready
                                blurEnabled: true
                                blur: 0.72
                                blurMax: 48
                                brightness: -0.24
                                autoPaddingEnabled: false
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: Qt.rgba(MusicState.m3SurfaceContainerHigh.r, MusicState.m3SurfaceContainerHigh.g, MusicState.m3SurfaceContainerHigh.b, MusicState.hasTrack ? 0.56 : 0.94)
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 7

                                Item { Layout.fillHeight: true }

                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: MusicState.hasTrack ? MusicState.trackTitle : "Музыка не играет"
                                    color: MusicState.m3OnSurface
                                    font.family: MusicState.fontUi
                                    font.pixelSize: 16
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: MusicState.hasTrack ? MusicState.trackArtist : "Нет активного трека"
                                    color: MusicState.m3OnSurfaceVariant
                                    font.family: MusicState.fontUi
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                }

                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.topMargin: 4
                                    spacing: 14

                                    Rectangle {
                                        Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: 18
                                        color: prevMa.containsMouse ? MusicState.m3PrimaryContainer : MusicState.m3SurfaceContainerHighest
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        SysIcon { anchors.centerIn: parent; name: "skip_prev"; size: 17; color: MusicState.m3OnSurface }
                                        MouseArea { id: prevMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { MusicState.prevTrack(); passHidden.forceActiveFocus() } }
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: MusicState.isPlaying ? 50 : 44
                                        Layout.preferredHeight: 44
                                        radius: MusicState.isPlaying ? 14 : 22
                                        color: MusicState.m3Primary
                                        Behavior on Layout.preferredWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                        Behavior on radius { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                                        SysIcon {
                                            anchors.centerIn: parent
                                            name: MusicState.isPlaying ? "pause" : "play"
                                            size: 19
                                            color: MusicState.m3OnPrimary
                                        }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { MusicState.togglePlay(); passHidden.forceActiveFocus() } }
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: 18
                                        color: nextMa.containsMouse ? MusicState.m3PrimaryContainer : MusicState.m3SurfaceContainerHighest
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        SysIcon { anchors.centerIn: parent; name: "skip_next"; size: 17; color: MusicState.m3OnSurface }
                                        MouseArea { id: nextMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { MusicState.nextTrack(); passHidden.forceActiveFocus() } }
                                    }
                                }

                                M3WavyBar {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 14
                                    visible: MusicState.hasTrack && MusicState.trackLength > 0
                                    value: MusicState.trackLength > 0 ? (MusicState.livePosition / MusicState.trackLength) : 0
                                    activeColor: MusicState.m3Primary
                                    trackColor: MusicState.m3SurfaceContainerHighest
                                    lineWidth: 4.0
                                    amplitude: 2.2
                                    showThumb: false
                                    interactive: false
                                    animated: MusicState.isPlaying
                                }

                                Item { Layout.fillHeight: true }
                            }
                        }
                    }

                    // ---------------------------------------------------------
                    // CENTER COLUMN: Tall Condensed Bebas Neue Clock (2133) + Date + Avatar + Password Pill
                    // ---------------------------------------------------------
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 10

                        Item { Layout.fillHeight: true }

                        // Signature Caelestia Tall Condensed Clock (HHmm, Bebas Neue) with HUD-colored minutes
                        Row {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 2

                            Text {
                                text: surface.hrStr
                                color: MusicState.m3OnSurface
                                font.family: lockClockFont.status === FontLoader.Ready ? lockClockFont.name : MusicState.fontClock
                                font.pixelSize: 138
                                font.weight: Font.Normal
                                font.letterSpacing: 2
                            }

                            Text {
                                text: surface.minStr
                                color: MusicState.m3Primary
                                font.family: lockClockFont.status === FontLoader.Ready ? lockClockFont.name : MusicState.fontClock
                                font.pixelSize: 138
                                font.weight: Font.Normal
                                font.letterSpacing: 2
                            }
                        }

                        // Uppercase Date Subtitle
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: -16
                            text: surface.dateStr
                            color: MusicState.m3OnSurfaceVariant
                            font.family: MusicState.fontUi
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            font.letterSpacing: 1.6
                        }

                        Item { Layout.preferredHeight: 14 }

                        // Large Circular User Avatar (~/.face if present, else M3 cookie8 initial badge)
                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 190
                            Layout.preferredHeight: 190

                            M3Shape {
                                anchors.fill: parent
                                visible: faceImg.status !== Image.Ready
                                shape: "cookie8"
                                fillColor: MusicState.m3PrimaryContainer
                                spin: LockState.authenticating
                                spinDuration: 4200
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: faceImg.status !== Image.Ready
                                text: SystemState.userName ? SystemState.userName.slice(0, 1).toUpperCase() : "A"
                                color: MusicState.m3OnPrimaryContainer
                                font.family: MusicState.fontUi
                                font.pixelSize: 68
                                font.weight: Font.Black
                            }

                            Canvas {
                                id: lockCookieMask
                                anchors.fill: parent
                                layer.enabled: true
                                visible: false
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    var cx = width / 2, cy = height / 2
                                    var baseR = Math.min(width, height) * 0.445
                                    var amp = baseR * 0.088
                                    ctx.beginPath()
                                    for (var i = 0; i <= 160; i++) {
                                        var a = (i / 160) * Math.PI * 2
                                        var r = baseR + amp * Math.cos(8 * a)
                                        var px = cx + r * Math.cos(a)
                                        var py = cy + r * Math.sin(a)
                                        if (i === 0) ctx.moveTo(px, py)
                                        else ctx.lineTo(px, py)
                                    }
                                    ctx.closePath()
                                    ctx.fillStyle = "#ffffff"
                                    ctx.fill()
                                }
                            }

                            Image {
                                id: faceImg
                    sourceSize: Qt.size(256, 256)
                                anchors.fill: parent
                                source: surface.homeDir !== "" ? ("file://" + surface.homeDir + "/.face") : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: false
                                onStatusChanged: lockCookieMask.requestPaint()
                            }

                            MultiEffect {
                                anchors.fill: parent
                                source: faceImg
                                visible: faceImg.status === Image.Ready
                                maskEnabled: true
                                maskSource: lockCookieMask
                            }
                        }

                        Item { Layout.preferredHeight: 16 }

                        // Caelestia Clean Centered Password Pill
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
                                color: MusicState.m3SurfaceContainerHigh
                                border.width: LockState.errorText !== "" ? 2 : 1
                                border.color: LockState.errorText !== ""
                                    ? MusicState.m3Error
                                    : (LockState.passwordText.length > 0 ? MusicState.m3Primary : MusicState.m3OutlineVariant)
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

                                    SysIcon {
                                        name: "lock"
                                        size: 16
                                        color: LockState.errorText !== "" ? MusicState.m3Error : MusicState.m3OnSurfaceVariant
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        clip: true

                                        Text {
                                            anchors.centerIn: parent
                                            visible: LockState.passwordText.length === 0
                                            text: LockState.authenticating ? "Проверка..." : "Введите пароль"
                                            color: MusicState.m3OnSurfaceVariant
                                            opacity: 0.78
                                            font.family: MusicState.fontUi
                                            font.pixelSize: 14
                                        }

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 8
                                            visible: LockState.passwordText.length > 0

                                            Repeater {
                                                model: Math.min(12, LockState.passwordText.length)
                                                delegate: Item {
                                                    required property int index
                                                    readonly property var shapes: ["cookie6", "clover4", "gem", "squircle", "cookie8"]
                                                    width: 18
                                                    height: 18
                                                    scale: 0.15
                                                    opacity: 0.0

                                                    Component.onCompleted: {
                                                        scale = 1.0
                                                        opacity = 1.0
                                                    }

                                                    Behavior on scale   { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
                                                    Behavior on opacity { NumberAnimation { duration: 120 } }

                                                    M3Shape {
                                                        anchors.fill: parent
                                                        shape: parent.shapes[parent.index % parent.shapes.length]
                                                        fillColor: MusicState.m3Primary
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.preferredHeight: 28
                                        Layout.preferredWidth: lkKbdTxt.implicitWidth + 16
                                        radius: 14
                                        color: kbdMa.containsMouse ? MusicState.m3PrimaryContainer : MusicState.m3SurfaceContainer
                                        Behavior on color { ColorAnimation { duration: 140 } }

                                        Text {
                                            id: lkKbdTxt
                                            anchors.centerIn: parent
                                            text: SystemState.kbdLayout
                                            color: MusicState.m3OnSurface
                                            font.family: MusicState.fontUi
                                            font.pixelSize: 12
                                            font.weight: Font.Bold
                                        }

                                        MouseArea {
                                            id: kbdMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: { SystemState.switchKeyboardLayout(); passHidden.forceActiveFocus() }
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            visible: LockState.errorText !== ""
                            text: LockState.errorText
                            color: MusicState.m3Error
                            font.family: MusicState.fontUi
                            font.pixelSize: 13
                            font.weight: Font.Bold
                        }

                        Item { Layout.fillHeight: true }
                    }

                    // ---------------------------------------------------------
                    // RIGHT COLUMN (~300px): Fixed-Height Resource Pills + Notifications List
                    // ---------------------------------------------------------
                    ColumnLayout {
                        Layout.preferredWidth: 300
                        Layout.fillHeight: true
                        spacing: 14

                        // 1. Fixed-Height Row of 3 Vertical Liquid Resource Pills (CPU / RAM / BAT or DISK)
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: false
                            Layout.preferredHeight: 118
                            Layout.minimumHeight: 118
                            Layout.maximumHeight: 118
                            spacing: 10

                            Repeater {
                                model: [
                                    { label: "CPU", pct: SystemState.cpuPercent },
                                    { label: "RAM", pct: SystemState.ramPercent },
                                    { label: SystemState.hasBattery ? "BAT" : "DISK", pct: SystemState.hasBattery ? SystemState.batteryPercent : SystemState.diskPercent }
                                ]
                                delegate: ClippingRectangle {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 118
                                    Layout.maximumHeight: 118
                                    radius: 22
                                    color: MusicState.m3SurfaceContainerHigh

                                    Rectangle {
                                        anchors {
                                            left: parent.left
                                            right: parent.right
                                            bottom: parent.bottom
                                        }
                                        height: Math.max(12, parent.height * Math.min(100, Math.max(0, modelData.pct)) / 100.0)
                                        color: MusicState.m3PrimaryContainer
                                        Behavior on height { NumberAnimation { duration: 480; easing.type: Easing.OutCubic } }
                                    }

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 2

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.label
                                            color: MusicState.m3OnSurfaceVariant
                                            font.family: MusicState.fontUi
                                            font.pixelSize: 12
                                            font.weight: Font.Bold
                                        }

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.pct + "%"
                                            color: MusicState.m3OnSurface
                                            font.family: MusicState.fontUi
                                            font.pixelSize: 22
                                            font.weight: Font.Black
                                        }
                                    }
                                }
                            }
                        }

                        // 2. Notifications List Card (fills remaining height cleanly!)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 200
                            radius: 24
                            color: MusicState.m3SurfaceContainerHigh

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Text {
                                        Layout.fillWidth: true
                                        text: NotifState.history.length > 0
                                            ? (NotifState.history.length + " уведомлений")
                                            : "Нет уведомлений"
                                        color: MusicState.m3OnSurfaceVariant
                                        font.family: MusicState.fontUi
                                        font.pixelSize: 13
                                        font.weight: Font.SemiBold
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 14
                                        color: sMa.containsMouse ? MusicState.m3PrimaryContainer : MusicState.m3SurfaceContainer
                                        Behavior on color { ColorAnimation { duration: 140 } }
                                        SysIcon { anchors.centerIn: parent; name: "moon"; size: 13; color: MusicState.m3OnSurface }
                                        MouseArea { id: sMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: SystemState.suspendSystem() }
                                    }
                                    Rectangle {
                                        Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 14
                                        color: rMa.containsMouse ? MusicState.m3PrimaryContainer : MusicState.m3SurfaceContainer
                                        Behavior on color { ColorAnimation { duration: 140 } }
                                        SysIcon { anchors.centerIn: parent; name: "reboot"; size: 13; color: MusicState.m3OnSurface }
                                        MouseArea { id: rMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: SystemState.rebootSystem() }
                                    }
                                    Rectangle {
                                        Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 14
                                        color: pMa.containsMouse ? MusicState.m3Error : MusicState.m3SurfaceContainer
                                        Behavior on color { ColorAnimation { duration: 140 } }
                                        SysIcon { anchors.centerIn: parent; name: "power"; size: 13; color: MusicState.m3OnSurface }
                                        MouseArea { id: pMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: SystemState.powerOffSystem() }
                                    }
                                }

                                Item {
                                    visible: NotifState.history.length === 0
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 10
                                        Item {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: 56; height: 56
                                            M3Shape {
                                                anchors.fill: parent
                                                shape: "cookie8"
                                                fillColor: MusicState.m3SurfaceContainer
                                            }
                                            SysIcon {
                                                anchors.centerIn: parent
                                                name: "bell"
                                                size: 22
                                                color: MusicState.m3OnSurfaceVariant
                                            }
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: "Всё спокойно"
                                            color: MusicState.m3OnSurfaceVariant
                                            font.family: MusicState.fontUi
                                            font.pixelSize: 14
                                        }
                                    }
                                }

                                ListView {
                                    visible: NotifState.history.length > 0
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    spacing: 8
                                    model: NotifState.history

                                    delegate: Rectangle {
                                        required property var modelData
                                        width: ListView.view.width
                                        height: nCol.implicitHeight + 20
                                        radius: 16
                                        color: MusicState.m3SurfaceContainer

                                        ColumnLayout {
                                            id: nCol
                                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                                            spacing: 3

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.appName || "Система"
                                                    color: MusicState.m3Primary
                                                    font.family: MusicState.fontUi
                                                    font.pixelSize: 13
                                                    font.weight: Font.Bold
                                                    elide: Text.ElideRight
                                                }
                                                Text {
                                                    text: modelData.time || ""
                                                    color: MusicState.m3OnSurfaceVariant
                                                    font.family: MusicState.fontUi
                                                    font.pixelSize: 11
                                                }
                                            }

                                            Text {
                                                visible: (modelData.summary || "") !== ""
                                                Layout.fillWidth: true
                                                text: modelData.summary || ""
                                                color: MusicState.m3OnSurface
                                                font.family: MusicState.fontUi
                                                font.pixelSize: 13
                                                font.weight: Font.SemiBold
                                                elide: Text.ElideRight
                                                maximumLineCount: 1
                                            }

                                            Text {
                                                visible: (modelData.body || "") !== ""
                                                Layout.fillWidth: true
                                                text: modelData.body || ""
                                                color: MusicState.m3OnSurfaceVariant
                                                font.family: MusicState.fontUi
                                                font.pixelSize: 12
                                                elide: Text.ElideRight
                                                maximumLineCount: 2
                                                wrapMode: Text.Wrap
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
