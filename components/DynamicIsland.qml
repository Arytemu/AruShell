import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
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

    readonly property int targetWidth: isExpanded ? 540 : (isToast ? 380 : Math.max(192, compactRow.implicitWidth + 32))
    readonly property int targetHeight: isExpanded ? 292 : (isToast ? 60 : 36)

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
        radius: root.isExpanded ? 26 : (root.isToast ? 22 : 18)
        color: MusicState.m3SurfaceContainer
        clip: true

        Behavior on width  { M3Anim { duration: 400 } }
        Behavior on height { M3Anim { duration: 380 } }
        Behavior on radius { M3Anim { duration: 340 } }

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
                visible: MusicState.hasTrack && MusicState.artUrl !== ""
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter
                radius: 11
                color: MusicState.m3SurfaceContainerHigh

                Image {
                    anchors.fill: parent
                    source: MusicState.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
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
                visible: MusicState.isPlaying
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
                            running: MusicState.isPlaying && !root.isExpanded && !root.isToast
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
                    color: MusicState.m3SurfaceContainerHigh
                }

                Rectangle {
                    id: tabIndicator
                    height: 30
                    width: (parent.width - 6) / 3
                    y: 3
                    x: 3 + root.currentTab * width
                    radius: 15
                    color: MusicState.m3PrimaryContainer

                    Behavior on x { M3Anim { duration: 340 } }
                }

                Row {
                    id: tabRow
                    anchors.fill: parent
                    anchors.margins: 3

                    Repeater {
                        model: ["Dashboard", "Media", "Performance"]

                        delegate: Item {
                            width: tabRow.width / 3
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
                    visible: root.currentTab === 0

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
                                    MouseArea { id: cPrevMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.calMonthOffset -= 1 }
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
                                    MouseArea { id: cNextMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.calMonthOffset += 1 }
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
                    visible: root.currentTab === 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 16

                        ClippingRectangle {
                            Layout.preferredWidth: 148
                            Layout.preferredHeight: 148
                            Layout.alignment: Qt.AlignVCenter
                            radius: 34
                            color: MusicState.m3SurfaceContainer

                            Image {
                                anchors.fill: parent
                                source: MusicState.artUrl
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
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
                            Layout.fillHeight: true
                            spacing: 6

                            Text {
                                Layout.fillWidth: true
                                text: MusicState.hasTrack ? MusicState.trackTitle : "Ничего не играет"
                                color: MusicState.m3OnSurface
                                font.family: MusicState.fontUi
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

                            Item { Layout.fillHeight: true }

                            // Chubby Material 3 Expressive Wavy Scrubber
                            M3WavyBar {
                                id: mediaProg
                                Layout.fillWidth: true
                                Layout.preferredHeight: 22
                                visible: MusicState.hasTrack && MusicState.trackLength > 0
                                value: MusicState.trackLength > 0 ? (MusicState.livePosition / MusicState.trackLength) : 0
                                activeColor: MusicState.m3Primary
                                trackColor: MusicState.m3SurfaceContainer
                                lineWidth: 6.0
                                amplitude: 3.8
                                animated: MusicState.isPlaying && root.isExpanded && root.currentTab === 1
                                onMoved: function(ratio) {
                                    if (MusicState.trackLength > 0) {
                                        MusicState.seekTo(ratio * MusicState.trackLength)
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: 4
                                spacing: 10

                                Rectangle {
                                    Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 19
                                    color: pMa.containsMouse ? MusicState.m3SurfaceContainerHighest : MusicState.m3SurfaceContainer
                                    IconImage {
                                        id: pIc; anchors.centerIn: parent; implicitSize: 16; visible: false
                                        source: root.sysIcon(["media-skip-backward-symbolic", "go-previous-symbolic"])
                                    }
                                    MultiEffect { anchors.fill: pIc; source: pIc; colorization: 1.0; colorizationColor: MusicState.m3OnSurface }
                                    MouseArea { id: pMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: MusicState.prevTrack() }
                                }

                                Item {
                                    Layout.preferredWidth: 48
                                    Layout.preferredHeight: 48
                                    M3Shape {
                                        anchors.fill: parent
                                        shape: "cookie12"
                                        fillColor: MusicState.m3Primary
                                        morphFactor: MusicState.isPlaying ? 1.0 : 0.0
                                        spin: MusicState.isPlaying && root.isExpanded && root.currentTab === 1
                                        spinDuration: 14000
                                    }
                                    IconImage {
                                        id: plIc; anchors.centerIn: parent; implicitSize: 18; visible: false
                                        source: MusicState.isPlaying
                                            ? root.sysIcon(["media-playback-pause-symbolic"])
                                            : root.sysIcon(["media-playback-start-symbolic"])
                                    }
                                    MultiEffect { anchors.fill: plIc; source: plIc; colorization: 1.0; colorizationColor: MusicState.m3OnPrimary }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: MusicState.togglePlay() }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 19
                                    color: nMa.containsMouse ? MusicState.m3SurfaceContainerHighest : MusicState.m3SurfaceContainer
                                    IconImage {
                                        id: nIc; anchors.centerIn: parent; implicitSize: 16; visible: false
                                        source: root.sysIcon(["media-skip-forward-symbolic", "go-next-symbolic"])
                                    }
                                    MultiEffect { anchors.fill: nIc; source: nIc; colorization: 1.0; colorizationColor: MusicState.m3OnSurface }
                                    MouseArea { id: nMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: MusicState.nextTrack() }
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 16
                                    color: cMa.containsMouse ? MusicState.m3SurfaceContainerHighest : "transparent"
                                    SysIcon { anchors.centerIn: parent; name: "close"; size: 15; color: MusicState.m3OnSurfaceVariant }
                                    MouseArea { id: cMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: NotifState.islandExpanded = false }
                                }
                            }
                        }
                    }
                }

                // === TAB 2: PERFORMANCE (3 Chubby Circular Wavy Gauges) ===
                RowLayout {
                    anchors.fill: parent
                    spacing: 12
                    visible: root.currentTab === 2

                    Repeater {
                        model: ["CPU", "RAM", "Disk"]

                        delegate: Rectangle {
                            id: gaugeCard
                            readonly property real metricPct: index === 0 ? SystemState.cpuPercent : (index === 1 ? SystemState.ramPercent : SystemState.diskPercent)
                            readonly property string metricSub: index === 0 ? "Процессор" : (index === 1 ? SystemState.ramText : SystemState.diskText)

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 22
                            color: MusicState.m3SurfaceContainerHigh
                            clip: true

                            M3Shape {
                                width: 110; height: 110
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -14
                                shape: "clover4"
                                fillColor: MusicState.m3Primary
                                opacity: 0.06
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 8

                                M3WavyGauge {
                                    Layout.preferredWidth: 88
                                    Layout.preferredHeight: 88
                                    Layout.alignment: Qt.AlignHCenter
                                    percent: gaugeCard.metricPct
                                    activeColor: MusicState.m3Primary
                                    trackColor: MusicState.m3SurfaceContainer
                                    lineWidth: 7.5
                                    amplitude: 2.5
                                    animated: root.isExpanded && root.currentTab === 2
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData
                                    color: MusicState.m3OnSurface
                                    font.family: MusicState.fontUi
                                    font.pixelSize: 13
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
