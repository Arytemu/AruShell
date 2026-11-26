import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import "../services"

/**
 * Floating Material You Pill Dynamic Island (aligned with TopBar pills at 36px height):
 * - Collapsed: sleek 36px floating pill (radius 18) with mini cover, time, date, and GPU equalizer
 * - Toast: morphs smoothly into a floating notification pill (click to open app / invoke action)
 * - Expanded (click): 3-tab floating Material 3 card (Dashboard | Media | Performance)
 *   with chubby M3WavyBar progress scrubbers and M3WavyGauge circular charts!
 */
Item {
    id: root

    readonly property bool isToast: NotifState.activeToast !== null && !NotifState.islandExpanded
    readonly property bool isExpanded: NotifState.islandExpanded

    readonly property bool activeWsHasWindows: {
        const ws = Hyprland.focusedWorkspace
        return !!(ws && ws.toplevels && ws.toplevels.values && ws.toplevels.values.length > 0)
    }
    // Hide mini-song on empty desktop when AlbumCard is visible; show when windows are open OR when minimized to Island
    readonly property bool showTrackInCompactIsland: MusicState.hasTrack && (activeWsHasWindows || MusicState.stageMinimizedToIsland || !ShellConfig.stageVisible)

    property int currentTab: 1 // 0: Dashboard, 1: Media, 2: Performance
    property int calMonthOffset: 0

    readonly property var calData: {
        const now = islandClock.date || new Date()
        const target = new Date(now.getFullYear(), now.getMonth() + calMonthOffset, 1)
        const yr = target.getFullYear()
        const mo = target.getMonth()
        const monthsRu = ["Январь","Февраль","Март","Апрель","Май","Июнь","Июль","Август","Сентябрь","Октябрь","Ноябрь","Декабрь"]
        const firstDay = (target.getDay() + 6) % 7 // Monday = 0
        const daysInMonth = new Date(yr, mo + 1, 0).getDate()
        const isThisMonth = (yr === now.getFullYear() && mo === now.getMonth())
        const todayNum = now.getDate()
        const cells = []
        for (let i = 0; i < firstDay; i++) cells.push({ day: "", today: false })
        for (let d = 1; d <= daysInMonth; d++) cells.push({ day: String(d), today: isThisMonth && d === todayNum })
        while (cells.length % 7 !== 0) cells.push({ day: "", today: false })
        return { title: monthsRu[mo] + " " + yr, cells: cells }
    }

    readonly property bool _mediaHasLyrics: MusicState.hasTrack && MusicState.lyricsLines && MusicState.lyricsLines.length > 0

    readonly property int targetWidth: {
        if (isExpanded) {
            if (currentTab === 0) return 530
            if (currentTab === 1) return _mediaHasLyrics ? 660 : 504
            if (currentTab === 2) return 530
            return 550
        }
        if (isToast) {
            return 370
        }
        return Math.round(compactRow.implicitWidth + 28)
    }

    readonly property int targetHeight: {
        if (isExpanded) {
            if (currentTab === 0) return 296
            if (currentTab === 1) return _mediaHasLyrics ? 296 : 272
            if (currentTab === 2) return 280
            return 296
        }
        if (isToast) return 60
        return 36
    }

    implicitWidth: islandBody.width
    implicitHeight: islandBody.height
    width: implicitWidth
    height: implicitHeight

    function sysIcon(names) {
        for (let i = 0; i < names.length; i++) {
            const p = Quickshell.iconPath(names[i], true)
            if (p && p !== "") return p
        }
        return ""
    }

    SystemClock {
        id: islandClock
        precision: SystemClock.Seconds
    }

    readonly property string timeStr: Qt.formatTime(islandClock.date, "HH:mm")
    readonly property string secStr: Qt.formatTime(islandClock.date, "ss")
    readonly property string dateStr: Qt.formatDate(islandClock.date, "ddd, d MMM")
    readonly property string fullDateStr: Qt.formatDate(islandClock.date, "dddd, d MMMM")

    // =========================================================================
    // Floating Material You Pill Body (matches Pac-Man, Tray, QuickSettings, Bell!)
    // =========================================================================
    Rectangle {
        id: islandBody
        width: root.targetWidth
        height: root.targetHeight
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        radius: root.isExpanded ? MusicState.shapeXl : (root.isToast ? 22 : 18)
        color: MusicState.m3SurfaceContainer
        border.width: 1
        border.color: MusicState.m3OutlineVariant
        clip: true

        Behavior on width  { M3Anim { duration: 380 } }
        Behavior on height { M3Anim { duration: 380 } }
        Behavior on radius { M3Anim { duration: 380 } }

        // Subtle Telegram-style liquid absorption pulse when AlbumCard merges into / emerges from Island
        property real absorbScale: 1.0
        scale: absorbScale
        transformOrigin: Item.Top

        SequentialAnimation {
            id: absorbPulse
            PauseAnimation { duration: 240 }
            NumberAnimation { target: islandBody; property: "absorbScale"; to: 1.07; duration: 170; easing.type: Easing.OutCubic }
            NumberAnimation { target: islandBody; property: "absorbScale"; to: 1.0;  duration: 280; easing.type: Easing.OutBack }
        }

        Connections {
            target: MusicState
            function onStageMinimizedToIslandChanged() {
                absorbPulse.restart()
            }
        }

        // Auto-close Dynamic Island gracefully when cursor leaves it
        HoverHandler {
            id: islandHover
            onHoveredChanged: {
                if (hovered) {
                    islandAutoClose.stop()
                } else if (root.isExpanded && ShellConfig.islandAutoClose) {
                    islandAutoClose.restart()
                }
            }
        }

        Timer {
            id: islandAutoClose
            interval: 420
            repeat: false
            onTriggered: {
                if (root.isExpanded && !islandHover.hovered) {
                    NotifState.islandExpanded = false
                }
            }
        }

        // Absorb clicks on expanded island background so they don't fall through to TopBar backdrop
        MouseArea {
            anchors.fill: parent
            enabled: root.isExpanded
        }

        // ---------------------------------------------------------------------
        // STATE 1: Compact 36px Floating Pill (Cover + Time + Date + Equalizer)
        // ---------------------------------------------------------------------
        RowLayout {
            id: compactRow
            anchors.centerIn: parent
            spacing: 10
            opacity: (!root.isExpanded && !root.isToast) ? 1.0 : 0.0
            visible: opacity > 0.01
            Behavior on opacity { M3Anim { duration: 220 } }

            ClippingRectangle {
                visible: root.showTrackInCompactIsland && MusicState.artUrl !== ""
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter
                radius: 11
                color: MusicState.m3SurfaceContainerHigh
                scale: visible ? 1.0 : 0.2
                opacity: visible ? 1.0 : 0.0
                Behavior on scale   { NumberAnimation { duration: 380; easing.type: Easing.OutBack } }
                Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

                Image {
                    anchors.fill: parent
                    source: MusicState.artUrl
                    sourceSize: Qt.size(64, 64)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                // Clicking the mini cover when minimized restores the AlbumCard back to the desktop!
                MouseArea {
                    anchors.fill: parent
                    enabled: MusicState.stageMinimizedToIsland
                    cursorShape: Qt.PointingHandCursor
                    onClicked: MusicState.stageMinimizedToIsland = false
                }
            }

            Text {
                text: root.timeStr
                color: MusicState.m3OnSurface
                font.family: MusicState.fontUi
                font.pixelSize: 13
                font.weight: Font.Bold
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: root.dateStr
                color: MusicState.m3OnSurfaceVariant
                font.family: MusicState.fontUi
                font.pixelSize: 12
                font.weight: Font.Medium
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                visible: ShellConfig.showWeatherInIsland && SystemState.weatherTemp !== ""
                text: "· " + SystemState.weatherTemp
                color: MusicState.m3Primary
                font.family: MusicState.fontUi
                font.pixelSize: 12
                font.weight: Font.Bold
                Layout.alignment: Qt.AlignVCenter
            }

            // GPU-accelerated Equalizer Bars
            Row {
                visible: root.showTrackInCompactIsland && MusicState.isPlaying
                Layout.alignment: Qt.AlignVCenter
                spacing: 2.5

                Repeater {
                    model: 4
                    delegate: Rectangle {
                        width: 2.5
                        height: 14
                        radius: 1.5
                        color: MusicState.m3Primary
                        property real barScale: 0.4
                        transform: Scale { origin.x: 1.25; origin.y: 7; yScale: barScale }

                        SequentialAnimation on barScale {
                            running: root.showTrackInCompactIsland && MusicState.isPlaying && !root.isExpanded && !root.isToast
                            loops: Animation.Infinite
                            NumberAnimation { to: 1.0 - (index % 2) * 0.2; duration: 260 + index * 70; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 0.28 + (index % 2) * 0.14; duration: 260 + index * 60; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // STATE 2: Incoming Notification Toast Pill
        // ---------------------------------------------------------------------
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 10
            opacity: root.isToast ? 1.0 : 0.0
            visible: opacity > 0.01
            Behavior on opacity { M3Anim { duration: 220 } }

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                Layout.alignment: Qt.AlignVCenter
                radius: 12
                color: MusicState.m3PrimaryContainer
                clip: true

                IconImage {
                    visible: NotifState.activeToast && NotifState.activeToast.appIcon !== ""
                    anchors.centerIn: parent
                    implicitSize: 22
                    source: (NotifState.activeToast && NotifState.activeToast.appIcon)
                        ? Quickshell.iconPath(NotifState.activeToast.appIcon, true)
                        : ""
                }

                SysIcon {
                    visible: !NotifState.activeToast || NotifState.activeToast.appIcon === ""
                    anchors.centerIn: parent
                    name: "bell"
                    size: 17
                    color: MusicState.m3OnPrimaryContainer
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: NotifState.activeToast ? (NotifState.activeToast.summary || NotifState.activeToast.appName) : ""
                    color: MusicState.m3OnSurface
                    font.family: MusicState.fontUi
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: NotifState.activeToast ? NotifState.activeToast.body : ""
                    color: MusicState.m3OnSurfaceVariant
                    font.family: MusicState.fontUi
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
        }

        // ---------------------------------------------------------------------
        // STATE 3: 3-Tab Floating Card (Dashboard | Media | Performance)
        // ---------------------------------------------------------------------
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14
            opacity: root.isExpanded ? 1.0 : 0.0
            visible: opacity > 0.01
            Behavior on opacity { M3Anim { duration: 260 } }

            // Segmented Tab Bar with Sliding M3 Pill Indicator
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 36

                Rectangle {
                    anchors.fill: parent
                    radius: 18
                    color: MusicState.m3SurfaceContainerLow
                    border.width: 1
                    border.color: MusicState.m3OutlineVariant
                }

                Rectangle {
                    id: tabIndicator
                    property real animTab: root.currentTab
                    Behavior on animTab { M3Anim { duration: 300 } }
                    height: 30
                    width: (parent.width - 6) / 4
                    y: 3
                    x: 3 + animTab * width
                    radius: 15
                    color: MusicState.m3SecondaryContainer
                }

                Row {
                    id: tabRow
                    anchors.fill: parent
                    anchors.margins: 3

                    Repeater {
                        model: ["Dashboard", "Media", "Performance", "Weather"]

                        delegate: Item {
                            width: tabRow.width / 4
                            height: tabRow.height

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: root.currentTab === index
                                    ? MusicState.m3OnPrimaryContainer
                                    : MusicState.m3OnSurfaceVariant
                                font.family: MusicState.fontUi
                                font.pixelSize: 12
                                font.weight: root.currentTab === index ? Font.Bold : Font.Medium
                                Behavior on color { ColorAnimation { duration: 180 } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.currentTab = index
                            }
                        }
                    }
                }
            }

            // Tab Content Area
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // === TAB 0: DASHBOARD (Clock + Live Weather + Monthly Calendar) ===
                RowLayout {
                    anchors.fill: parent
                    spacing: 12
                    opacity: root.currentTab === 0 ? 1.0 : 0.0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    // Left Card: Clock + Weather + User/Uptime + Screenshot
                    Rectangle {
                        Layout.preferredWidth: 224
                        Layout.fillHeight: true
                        radius: 20
                        color: MusicState.m3SurfaceContainerHigh

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 6

                            RowLayout {
                                spacing: 4
                                Text {
                                    text: root.timeStr
                                    color: MusicState.m3Primary
                                    font.family: MusicState.fontUi
                                    font.pixelSize: 36
                                    font.weight: Font.Black
                                }
                                Text {
                                    text: ":" + root.secStr
                                    color: MusicState.m3OnSurfaceVariant
                                    font.family: MusicState.fontUi
                                    font.pixelSize: 15
                                    font.weight: Font.SemiBold
                                    Layout.alignment: Qt.AlignBottom
                                    Layout.bottomMargin: 6
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.fullDateStr
                                color: MusicState.m3OnSurface
                                font.family: MusicState.fontUi
                                font.pixelSize: 12
                                font.weight: Font.SemiBold
                                elide: Text.ElideRight
                            }

                            // Live Weather Pill
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 42
                                radius: 14
                                color: MusicState.m3SurfaceContainer

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    Item {
                                        Layout.preferredWidth: 30
                                        Layout.preferredHeight: 30
                                        Layout.alignment: Qt.AlignVCenter
                                        M3Shape {
                                            anchors.fill: parent
                                            shape: "cookie6"
                                            fillColor: MusicState.m3PrimaryContainer
                                            spin: root.isExpanded && root.currentTab === 0
                                            spinDuration: 24000
                                        }
                                        SysIcon {
                                            anchors.centerIn: parent
                                            name: "weather"
                                            size: 15
                                            color: MusicState.m3OnPrimaryContainer
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Text {
                                            Layout.fillWidth: true
                                            text: SystemState.weatherTemp !== "" ? (SystemState.weatherTemp + (SystemState.weatherCity ? " · " + SystemState.weatherCity : "")) : "Погода загружается..."
                                            color: MusicState.m3OnSurface
                                            font.family: MusicState.fontUi
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            visible: text !== ""
                                            text: SystemState.weatherDesc
                                            color: MusicState.m3OnSurfaceVariant
                                            font.family: MusicState.fontUi
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 30
                                    radius: 15
                                    color: dShotMa.containsMouse ? MusicState.m3Primary : MusicState.m3PrimaryContainer
                                    Behavior on color { ColorAnimation { duration: 160 } }

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 5
                                        SysIcon { name: "screenshot"; size: 13; color: dShotMa.containsMouse ? MusicState.m3OnPrimary : MusicState.m3OnPrimaryContainer }
                                        Text { text: "Скриншот"; color: dShotMa.containsMouse ? MusicState.m3OnPrimary : MusicState.m3OnPrimaryContainer; font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold }
                                    }
                                    MouseArea { id: dShotMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ScreenshotState.open("region") }
                                }
                            }
                        }
                    }

                    // Right Card: Interactive Monthly Calendar
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 20
                        color: MusicState.m3SurfaceContainerHigh

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 6

                            // Month Header + Prev/Next arrows
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Rectangle {
                                    Layout.preferredWidth: 24; Layout.preferredHeight: 24; radius: 12
                                    color: cPrevMa.containsMouse ? MusicState.m3SurfaceContainerHighest : "transparent"
                                    SysIcon { anchors.centerIn: parent; name: "chevron_left"; size: 13; color: MusicState.m3OnSurfaceVariant }
                                    MouseArea { id: cPrevMa; anchors.fill: parent; anchors.margins: -5; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.calMonthOffset -= 1 }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: root.calData.title
                                    color: MusicState.m3OnSurface
                                    font.family: MusicState.fontUi
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.calMonthOffset = 0 }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 24; Layout.preferredHeight: 24; radius: 12
                                    color: cNextMa.containsMouse ? MusicState.m3SurfaceContainerHighest : "transparent"
                                    SysIcon { anchors.centerIn: parent; name: "chevron_right"; size: 13; color: MusicState.m3OnSurfaceVariant }
                                    MouseArea { id: cNextMa; anchors.fill: parent; anchors.margins: -5; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.calMonthOffset += 1 }
                                }
                            }

                            // Weekday Headers
                            Row {
                                Layout.fillWidth: true
                                Repeater {
                                    model: ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
                                    delegate: Text {
                                        width: parent.width / 7
                                        horizontalAlignment: Text.AlignHCenter
                                        text: modelData
                                        color: index >= 5 ? MusicState.m3Primary : MusicState.m3OnSurfaceVariant
                                        font.family: MusicState.fontUi
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                    }
                                }
                            }

                            // Calendar Days Grid
                            Grid {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                columns: 7

                                Repeater {
                                    model: root.calData.cells

                                    delegate: Item {
                                        width: parent.width / 7
                                        height: 22

                                        Item {
                                            anchors.centerIn: parent
                                            width: 24
                                            height: 24

                                            M3Shape {
                                                anchors.fill: parent
                                                visible: modelData.today
                                                shape: "cookie8"
                                                fillColor: MusicState.m3Primary
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.day
                                                color: modelData.today ? MusicState.m3OnPrimary : MusicState.m3OnSurface
                                                font.family: MusicState.fontUi
                                                font.pixelSize: 10
                                                font.weight: modelData.today ? Font.Black : Font.Medium
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // === TAB 1: MEDIA ===
                Rectangle {
                    anchors.fill: parent
                    radius: 20
                    color: MusicState.m3SurfaceContainerHigh
                    opacity: root.currentTab === 1 ? 1.0 : 0.0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    clip: true

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 16

                        ClippingRectangle {
                            Layout.preferredWidth: 132
                            Layout.preferredHeight: 132
                            Layout.alignment: Qt.AlignVCenter
                            radius: 28
                            color: MusicState.m3SurfaceContainer

                            Image {
                                id: islandArtImg
                                anchors.fill: parent
                                source: MusicState.artUrl
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: islandArtImg.status !== Image.Ready
                                text: "♫"
                                color: MusicState.m3OnSurfaceVariant
                                opacity: 0.45
                                font.pixelSize: 38
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    MusicState.raiseActivePlayer()
                                    NotifState.islandExpanded = false
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 8

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: MusicState.hasTrack ? MusicState.trackTitle : "Ничего не играет"
                                    color: MusicState.m3OnSurface
                                    opacity: MusicState.moodFontOpacity
                                    font.family: MusicState.trackMoodFont
                                    font.italic: MusicState.trackMoodItalic
                                    font.letterSpacing: MusicState.trackMoodSpacing
                                    font.pixelSize: 16
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: MusicState.hasTrack
                                        ? (MusicState.trackArtist + (MusicState.trackAlbum ? " · " + MusicState.trackAlbum : ""))
                                        : MusicState.currentPlatformObj.name
                                    color: MusicState.m3OnSurfaceVariant
                                    font.family: MusicState.fontUi
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }

                            // Chubby Material 3 Expressive Wavy Scrubber
                            M3WavyBar {
                                id: mediaProg
                                Layout.fillWidth: true
                                Layout.preferredHeight: 20
                                visible: MusicState.hasTrack && MusicState.trackLength > 0
                                value: MusicState.trackLength > 0 ? (MusicState.livePosition / MusicState.trackLength) : 0
                                activeColor: MusicState.m3Primary
                                trackColor: MusicState.m3SurfaceContainer
                                lineWidth: 5.5
                                amplitude: 3.4
                                animated: MusicState.isPlaying && root.isExpanded && root.currentTab === 1
                                onMoved: function(ratio) {
                                    if (MusicState.trackLength > 0) {
                                        MusicState.seekTo(ratio * MusicState.trackLength)
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: 2
                                spacing: 12

                                Rectangle {
                                    Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 19
                                    color: pMa.containsMouse ? MusicState.m3SurfaceContainerHighest : MusicState.m3SurfaceContainer
                                    SysIcon { anchors.centerIn: parent; name: "skip_prev"; size: 17; color: MusicState.m3OnSurface }
                                    MouseArea { id: pMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: MusicState.prevTrack() }
                                }

                                Item {
                                    Layout.preferredWidth: 46
                                    Layout.preferredHeight: 46
                                    M3Shape {
                                        anchors.fill: parent
                                        shape: "cookie12"
                                        fillColor: MusicState.m3Primary
                                        morphFactor: MusicState.isPlaying ? 1.0 : 0.0
                                        spin: MusicState.isPlaying && root.isExpanded && root.currentTab === 1
                                        spinDuration: 14000
                                    }
                                    SysIcon { anchors.centerIn: parent; name: MusicState.isPlaying ? "pause" : "play"; size: 20; color: MusicState.m3OnPrimary }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: MusicState.togglePlay() }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 19
                                    color: nMa.containsMouse ? MusicState.m3SurfaceContainerHighest : MusicState.m3SurfaceContainer
                                    SysIcon { anchors.centerIn: parent; name: "skip_next"; size: 17; color: MusicState.m3OnSurface }
                                    MouseArea { id: nMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: MusicState.nextTrack() }
                                }

                                // Restore-to-Desktop / Minimize-to-Island toggle button
                                Rectangle {
                                    visible: MusicState.hasTrack
                                    Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 17
                                    color: rstMa.containsMouse ? MusicState.m3SecondaryContainer : MusicState.m3SurfaceContainer
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    SysIcon {
                                        anchors.centerIn: parent
                                        name: "chevron_left"
                                        size: 14
                                        rotation: MusicState.stageMinimizedToIsland ? -90 : 90
                                        color: rstMa.containsMouse ? MusicState.m3OnSecondaryContainer : MusicState.m3OnSurfaceVariant
                                        Behavior on rotation { M3Anim { duration: 240 } }
                                    }
                                    MouseArea {
                                        id: rstMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: MusicState.stageMinimizedToIsland = !MusicState.stageMinimizedToIsland
                                    }
                                }

                                Item { Layout.fillWidth: true }
                            }
                        }

                        // Synced Lyrics Pane with soft bottom fade (never hard-clips half lines!)
                        Rectangle {
                            visible: root._mediaHasLyrics
                            Layout.preferredWidth: 214
                            Layout.fillHeight: true
                            radius: 16
                            color: MusicState.m3SurfaceContainer
                            clip: true

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 6

                                Text {
                                    text: "Текст песни"
                                    color: MusicState.m3Primary
                                    font.family: MusicState.fontUi
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true

                                    ListView {
                                        id: islandLyricsList
                                        anchors.fill: parent
                                        bottomMargin: 16
                                        spacing: 6
                                        model: MusicState.lyricsLines
                                        currentIndex: Math.max(0, MusicState.currentLyricIndex)
                                        highlightFollowsCurrentItem: true
                                        preferredHighlightBegin: height * 0.28
                                        preferredHighlightEnd: height * 0.48
                                        highlightRangeMode: ListView.ApplyRange

                                        delegate: Text {
                                            required property var modelData
                                            required property int index
                                            readonly property bool isCur: index === MusicState.currentLyricIndex
                                            width: islandLyricsList.width
                                            text: modelData.text || ""
                                            color: isCur ? MusicState.m3Primary : MusicState.m3OnSurfaceVariant
                                            opacity: isCur ? 1.0 : 0.62
                                            font.family: MusicState.trackMoodFont
                                            font.italic: MusicState.trackMoodItalic
                                            font.pixelSize: isCur ? 12 : 11
                                            font.weight: isCur ? Font.Bold : Font.Normal
                                            wrapMode: Text.Wrap
                                            Behavior on opacity { NumberAnimation { duration: 180 } }
                                        }
                                    }

                                    // Soft bottom fade mask so lyrics fade smoothly instead of slicing text in half
                                    Rectangle {
                                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                        height: 22
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: "transparent" }
                                            GradientStop { position: 1.0; color: MusicState.m3SurfaceContainer }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // === TAB 2: PERFORMANCE (3 Chubby Circular Wavy Gauges + Live Network Speed) ===
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    opacity: root.currentTab === 2 ? 1.0 : 0.0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 10

                        Repeater {
                            model: ["CPU", "RAM", "Disk"]

                            delegate: Rectangle {
                                id: gaugeCard
                                required property string modelData
                                required property int index
                                readonly property real metricPct: index === 0 ? SystemState.cpuPercent : (index === 1 ? SystemState.ramPercent : SystemState.diskPercent)
                                readonly property string metricSub: index === 0 ? "Процессор" : (index === 1 ? SystemState.ramText : SystemState.diskText)

                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 20
                                color: MusicState.m3SurfaceContainerHigh
                                clip: true

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 5

                                    M3WavyGauge {
                                        Layout.preferredWidth: 78
                                        Layout.preferredHeight: 78
                                        Layout.alignment: Qt.AlignHCenter
                                        percent: gaugeCard.metricPct
                                        activeColor: MusicState.m3Primary
                                        trackColor: MusicState.m3SurfaceContainer
                                        lineWidth: 7.0
                                        amplitude: 2.2
                                        animated: root.isExpanded && root.currentTab === 2
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData + " · " + Math.round(gaugeCard.metricPct) + "%"
                                        color: MusicState.m3OnSurface
                                        font.family: MusicState.fontUi
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: gaugeCard.metricSub
                                        color: MusicState.m3OnSurfaceVariant
                                        font.family: MusicState.fontUi
                                        font.pixelSize: 10
                                    }
                                }
                            }
                        }
                    }

                    // Live Network Speed Pill (reads /proc/net/dev — zero Wi-Fi scans!)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: 19
                        color: MusicState.m3SurfaceContainerHigh

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 12

                            SysIcon {
                                name: SystemState.ethernetConnected ? "ethernet" : "wifi"
                                size: 15
                                color: MusicState.m3Primary
                            }
                            Text {
                                text: SystemState.ethernetConnected ? "Ethernet" : (SystemState.wifiSsid || "Сеть")
                                color: MusicState.m3OnSurface
                                font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.SemiBold
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: "↓ " + SystemState.netDown
                                color: MusicState.m3Primary
                                font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.Bold
                            }
                            Text {
                                text: "↑ " + SystemState.netUp
                                color: MusicState.m3OnSurfaceVariant
                                font.family: MusicState.fontUi; font.pixelSize: 12; font.weight: Font.SemiBold
                            }
                        }
                    }
                }

                // === TAB 3: WEATHER (Caelestia-style Full Forecast Tab) ===
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    opacity: root.currentTab === 3 ? 1.0 : 0.0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    // Top Weather Summary Card
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 112
                        radius: 20
                        color: MusicState.m3SurfaceContainerHigh

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 14

                            Item {
                                Layout.preferredWidth: 56
                                Layout.preferredHeight: 56
                                M3Shape {
                                    anchors.fill: parent
                                    shape: "cookie6"
                                    fillColor: MusicState.m3PrimaryContainer
                                    spin: root.isExpanded && root.currentTab === 3
                                    spinDuration: 22000
                                }
                                SysIcon {
                                    anchors.centerIn: parent
                                    name: "weather"
                                    size: 24
                                    color: MusicState.m3OnPrimaryContainer
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: SystemState.weatherCity || "Погода"
                                    color: MusicState.m3OnSurface
                                    font.family: MusicState.fontUi; font.pixelSize: 14; font.weight: Font.Bold
                                    elide: Text.ElideRight
                                }
                                RowLayout {
                                    spacing: 8
                                    Text {
                                        text: SystemState.weatherTemp || "—"
                                        color: MusicState.m3Primary
                                        font.family: MusicState.fontUi; font.pixelSize: 30; font.weight: Font.Black
                                    }
                                    Text {
                                        text: SystemState.weatherDesc || "Загрузка..."
                                        color: MusicState.m3OnSurfaceVariant
                                        font.family: MusicState.fontUi; font.pixelSize: 12
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            ColumnLayout {
                                spacing: 4
                                Text {
                                    visible: SystemState.weatherHumidity !== ""
                                    text: "Влажность: " + SystemState.weatherHumidity
                                    color: MusicState.m3OnSurfaceVariant
                                    font.family: MusicState.fontUi; font.pixelSize: 11
                                }
                                Text {
                                    visible: SystemState.weatherFeels !== ""
                                    text: "Ощущается: " + SystemState.weatherFeels
                                    color: MusicState.m3OnSurfaceVariant
                                    font.family: MusicState.fontUi; font.pixelSize: 11
                                }
                                Text {
                                    visible: SystemState.weatherWind !== ""
                                    text: "Ветер: " + SystemState.weatherWind
                                    color: MusicState.m3OnSurfaceVariant
                                    font.family: MusicState.fontUi; font.pixelSize: 11
                                }
                            }
                        }
                    }

                    // 3-Day Forecast Row
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 10

                        Repeater {
                            model: SystemState.weatherForecast.length > 0
                                ? SystemState.weatherForecast
                                : [
                                    { date: "Сегодня", min: "—", max: "—", desc: "Обновление..." },
                                    { date: "Завтра",  min: "—", max: "—", desc: "—" },
                                    { date: "Послезавтра", min: "—", max: "—", desc: "—" }
                                ]
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 18
                                color: MusicState.m3SurfaceContainerHigh

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    width: parent.width - 16
                                    spacing: 4

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.date || ""
                                        color: MusicState.m3Primary
                                        font.family: MusicState.fontUi; font.pixelSize: 11; font.weight: Font.Bold
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: (modelData.max || "—") + " / " + (modelData.min || "—")
                                        color: MusicState.m3OnSurface
                                        font.family: MusicState.fontUi; font.pixelSize: 14; font.weight: Font.Black
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        text: modelData.desc || ""
                                        color: MusicState.m3OnSurfaceVariant
                                        font.family: MusicState.fontUi; font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Click compact pill or toast
        MouseArea {
            anchors.fill: parent
            enabled: !root.isExpanded
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.isToast) {
                    NotifState.activateEntry(NotifState.activeToast, -1)
                } else {
                    SystemState.quickSettingsOpen = false
                    SystemState.launcherOpen = false
                    NotifState.toggleIsland()
                }
            }
        }
    }
}
