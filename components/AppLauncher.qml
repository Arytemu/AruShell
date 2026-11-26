import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../services"

/**
 * Upgraded Material You App Launcher (NO calculator; Apps | Open Windows | Emoji + System Commands):
 * - Bound to SUPER tap in Hyprland Lua + top-left button
 * - Strictly ORIGINAL untouched app icons
 * - Instant search, Tab to switch sections, Up/Down/Enter/Esc keyboard navigation
 */
Item {
    id: root
    width: 440
    height: 490

    visible: opacity > 0.01
    opacity: SystemState.launcherOpen ? 1.0 : 0.0
    scale: SystemState.launcherOpen ? 1.0 : 0.94
    y: SystemState.launcherOpen ? 0 : -12
    transformOrigin: Item.TopLeft

    Behavior on opacity { M3Anim { duration: SystemState.launcherOpen ? 240 : 150 } }
    Behavior on scale   { M3Anim { duration: SystemState.launcherOpen ? 320 : 180 } }
    Behavior on y       { M3Anim { duration: SystemState.launcherOpen ? 320 : 180 } }

    property string query: ""
    property int activeTab: 0 // 0: Приложения, 1: Окна, 2: Эмодзи
    property int selectedIndex: 0

    readonly property var sysCommands: [
        { name: "Настройки шелла", desc: "Шейпы, шрифт, виджеты и панели", icon: "settings",   action: "settings" },
        { name: "Обои",           desc: "Карусель выбора обоев (Win+W)",   icon: "palette",    action: "wallpaper" },
        { name: "Скриншот",       desc: "Снимок области, окна или экрана", icon: "screenshot", action: "screenshot" },
        { name: "Буфер обмена",   desc: "Открыть историю cliphist",        icon: "clipboard",  action: "clipboard" },
        { name: "Ночной режим",   desc: "Включить / выключить hyprsunset", icon: "nightlight", action: "nightlight" },
        { name: "Блокировка",     desc: "Заблокировать экран",             icon: "lock",       action: "lock" },
        { name: "Сон",            desc: "Перевести ПК в спящий режим",     icon: "moon",       action: "suspend" },
        { name: "Перезагрузка",   desc: "Перезагрузить систему",           icon: "reboot",     action: "reboot" },
        { name: "Выключение",     desc: "Выключить компьютер",             icon: "power",      action: "poweroff" }
    ]

    readonly property var emojiList: [
        { e: "😀", k: "улыбка радость smile happy" }, { e: "😂", k: "смех lol haha" }, { e: "🥹", k: "умиление tears" },
        { e: "😍", k: "любовь сердце love heart" }, { e: "😎", k: "крутой cool" }, { e: "🤔", k: "думаю think" },
        { e: "😭", k: "плач cry sad" }, { e: "😡", k: "злость angry" }, { e: "🥳", k: "праздник party" },
        { e: "🔥", k: "огонь fire hot" }, { e: "❤️", k: "сердце любовь heart" }, { e: "✨", k: "искры магия sparkles" },
        { e: "👍", k: "класс лайк ok yes" }, { e: "👎", k: "дизлайк no" }, { e: "👏", k: "аплодисменты clap" },
        { e: "🙏", k: "пожалуйста спасибо pray thanks" }, { e: "🤝", k: "рукопожатие deal" }, { e: "💪", k: "сила strong" },
        { e: "🎉", k: "салют праздник tada" }, { e: "🎵", k: "музыка нота music" }, { e: "🎧", k: "наушники музыка headphones" },
        { e: "💻", k: "ноутбук код laptop dev" }, { e: "🚀", k: "ракета запуск rocket" }, { e: "⚡", k: "молния быстро zap" },
        { e: "☕", k: "кофе чай coffee" }, { e: "🍕", k: "пицца еда pizza" }, { e: "🌙", k: "луна ночь moon" },
        { e: "☀️", k: "солнце день sun" }, { e: "❄️", k: "снег зима snow" }, { e: "🌈", k: "радуга rainbow" },
        { e: "✅", k: "галочка готово check done" }, { e: "❌", k: "крестик нет cross" }, { e: "⚠️", k: "внимание warn" },
        { e: "📌", k: "скрепка пин pin" }, { e: "🔒", k: "замок lock" }, { e: "👀", k: "глаза смотрю eyes" }
    ]

    readonly property var filteredApps: {
        const q = query.trim().toLowerCase()
        const out = []

        // Match system commands when searching
        if (q !== "") {
            for (let c = 0; c < sysCommands.length; c++) {
                const cmd = sysCommands[c]
                if ((cmd.name + " " + cmd.desc + " " + cmd.action).toLowerCase().indexOf(q) !== -1) {
                    out.push({ kind: "cmd", name: cmd.name, desc: cmd.desc, sysIcon: cmd.icon, action: cmd.action })
                }
            }
        }

        const all = DesktopEntries.applications.values || []
        const apps = []
        for (let i = 0; i < all.length; i++) {
            const app = all[i]
            if (!app || app.noDisplay) continue
            const name = String(app.name || "")
            if (name === "") continue
            if (q === "") {
                apps.push(app)
            } else {
                const hay = (name + " " + String(app.genericName || "") + " " + String(app.comment || "") + " " + String(app.id || "")).toLowerCase()
                if (hay.indexOf(q) !== -1) apps.push(app)
            }
        }
        const rec = ShellConfig.recentApps || []
        function recentRank(appObj) {
            const idKey = String(appObj.id || "")
            const nameKey = String(appObj.name || "")
            let idx = idKey ? rec.indexOf(idKey) : -1
            if (idx === -1 && nameKey) idx = rec.indexOf(nameKey)
            return idx
        }
        apps.sort(function(a, b) {
            const an = String(a.name || "").toLowerCase()
            const bn = String(b.name || "").toLowerCase()
            if (q !== "") {
                const aS = an.startsWith(q) ? 0 : 1
                const bS = bn.startsWith(q) ? 0 : 1
                if (aS !== bS) return aS - bS
            } else {
                const ar = recentRank(a)
                const br = recentRank(b)
                if (ar !== -1 && br !== -1) return ar - br
                if (ar !== -1) return -1
                if (br !== -1) return 1
            }
            return an.localeCompare(bn)
        })
        for (let j = 0; j < apps.length; j++) {
            const rIdx = recentRank(apps[j])
            out.push({
                kind: "app",
                app: apps[j],
                isRecent: q === "" && rIdx !== -1,
                name: apps[j].name || "",
                desc: apps[j].genericName || apps[j].comment || "",
                icon: apps[j].icon || ""
            })
        }
        return out
    }

    readonly property var filteredWindows: {
        const list = ToplevelManager.toplevels.values || []
        const q = query.trim().toLowerCase()
        const out = []
        for (let i = 0; i < list.length; i++) {
            const tl = list[i]
            if (!tl) continue
            const title = String(tl.title || "")
            const appId = String(tl.appId || "")
            if (q === "" || (title + " " + appId).toLowerCase().indexOf(q) !== -1) {
                const entry = DesktopEntries.heuristicLookup(appId)
                out.push({
                    toplevel: tl,
                    title: title || appId || "Окно",
                    appId: appId,
                    icon: entry && entry.icon ? entry.icon : appId
                })
            }
        }
        return out
    }

    readonly property var filteredEmojis: {
        const q = query.trim().toLowerCase()
        if (q === "") return emojiList
        const out = []
        for (let i = 0; i < emojiList.length; i++) {
            if (emojiList[i].k.indexOf(q) !== -1 || emojiList[i].e === q) {
                out.push(emojiList[i])
            }
        }
        return out
    }

    function runSysCommand(action) {
        SystemState.launcherOpen = false
        if (action === "settings") ShellConfig.openSettings()
        else if (action === "wallpaper") WallpaperState.toggle()
        else if (action === "screenshot") ScreenshotState.open("region")
        else if (action === "clipboard") ClipboardState.toggle()
        else if (action === "nightlight") SystemState.toggleNightLight()
        else if (action === "lock") SystemState.lockScreen()
        else if (action === "suspend") SystemState.suspendSystem()
        else if (action === "reboot") SystemState.rebootSystem()
        else if (action === "poweroff") SystemState.powerOffSystem()
    }

    function activateCurrent() {
        if (activeTab === 0) {
            const list = filteredApps
            if (list.length === 0) return
            const item = list[Math.max(0, Math.min(selectedIndex, list.length - 1))]
            if (item.kind === "cmd") runSysCommand(item.action)
            else if (item.app) {
                ShellConfig.recordRecentApp(item.app.id || item.name)
                try { item.app.execute() } catch (e) {}
                SystemState.launcherOpen = false
            }
        } else if (activeTab === 1) {
            const list = filteredWindows
            if (list.length === 0) return
            const item = list[Math.max(0, Math.min(selectedIndex, list.length - 1))]
            if (item && item.toplevel) {
                try { item.toplevel.activate() } catch (e) {}
            }
            SystemState.launcherOpen = false
        } else if (activeTab === 2) {
            const list = filteredEmojis
            if (list.length === 0) return
            const item = list[Math.max(0, Math.min(selectedIndex, list.length - 1))]
            if (item) {
                Quickshell.execDetached(["bash", "-c", "printf '%s' " + JSON.stringify(item.e) + " | wl-copy"])
                SystemState.showOsd("emoji", "Скопировано", 1.0, item.e, false)
            }
            SystemState.launcherOpen = false
        }
    }

    Connections {
        target: SystemState
        function onLauncherOpenChanged() {
            if (SystemState.launcherOpen) {
                root.query = ""
                root.selectedIndex = 0
                root.activeTab = 0
                searchInput.text = ""
                focusTimer.restart()
            } else {
                searchInput.focus = false
            }
        }
    }

    Timer {
        id: focusTimer
        interval: 40
        repeat: false
        onTriggered: searchInput.forceActiveFocus()
    }

    Rectangle {
        anchors.fill: parent
        radius: MusicState.shapeXl
        color: MusicState.m3SurfaceContainer
        border.width: 1
        border.color: MusicState.m3OutlineVariant

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Search Input Pill (M3 Search Bar with visible focus outline)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: 22
                color: MusicState.m3SurfaceContainerHigh
                border.width: 1
                border.color: searchInput.activeFocus ? MusicState.m3Outline : MusicState.m3OutlineVariant

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 12
                    spacing: 10

                    SysIcon {
                        name: root.activeTab === 0 ? "apps" : (root.activeTab === 1 ? "window" : "emoji")
                        size: 16
                        color: MusicState.m3Primary
                        Layout.alignment: Qt.AlignVCenter
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        color: MusicState.m3OnSurface
                        selectionColor: MusicState.m3PrimaryContainer
                        selectedTextColor: MusicState.m3OnPrimaryContainer
                        font.family: MusicState.fontUi
                        font.pixelSize: 13
                        clip: true

                        onTextChanged: {
                            root.query = text
                            root.selectedIndex = 0
                        }

                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Escape) {
                                SystemState.launcherOpen = false
                                event.accepted = true
                            } else if (event.key === Qt.Key_Tab) {
                                root.activeTab = (root.activeTab + 1) % 3
                                root.selectedIndex = 0
                                event.accepted = true
                            } else if (event.key === Qt.Key_Down) {
                                const len = root.activeTab === 0 ? root.filteredApps.length : (root.activeTab === 1 ? root.filteredWindows.length : root.filteredEmojis.length)
                                if (len > 0) root.selectedIndex = Math.min(len - 1, root.selectedIndex + 1)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Up) {
                                root.selectedIndex = Math.max(0, root.selectedIndex - 1)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.activateCurrent()
                                event.accepted = true
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.activeTab === 0
                                ? "Приложения или команды (сон, скриншот)..."
                                : (root.activeTab === 1 ? "Переключиться на открытое окно..." : "Поиск эмодзи (огонь, сердце, smile)...")
                            color: MusicState.m3OnSurfaceVariant
                            font.family: MusicState.fontUi
                            font.pixelSize: 12
                            visible: searchInput.text === ""
                        }
                    }

                    Rectangle {
                        visible: searchInput.text !== ""
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        radius: 12
                        color: clrMa.containsMouse ? MusicState.m3SurfaceContainerHighest : "transparent"

                        SysIcon { anchors.centerIn: parent; name: "close"; size: 12; color: MusicState.m3OnSurfaceVariant }

                        MouseArea {
                            id: clrMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { searchInput.text = ""; searchInput.forceActiveFocus() }
                        }
                    }
                }
            }

            // Segmented Tabs: Приложения | Окна | Эмодзи
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 34

                Rectangle {
                    anchors.fill: parent
                    radius: 17
                    color: MusicState.m3SurfaceContainerHigh
                }

                Rectangle {
                    height: 28
                    width: (parent.width - 6) / 3
                    y: 3
                    x: 3 + root.activeTab * width
                    radius: 14
                    color: MusicState.m3PrimaryContainer
                    Behavior on x { M3Anim { duration: 300 } }
                }

                Row {
                    id: lTabRow
                    anchors.fill: parent
                    anchors.margins: 3

                    Repeater {
                        model: ["Приложения", "Окна (" + root.filteredWindows.length + ")", "Эмодзи"]

                        delegate: Item {
                            width: lTabRow.width / 3
                            height: lTabRow.height

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: root.activeTab === index ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurfaceVariant
                                font.family: MusicState.fontUi
                                font.pixelSize: 11
                                font.weight: root.activeTab === index ? Font.Bold : Font.Medium
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.activeTab = index
                                    root.selectedIndex = 0
                                    searchInput.forceActiveFocus()
                                }
                            }
                        }
                    }
                }
            }

            // TAB 0: Applications + System Commands
            ListView {
                id: appList
                visible: root.activeTab === 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: root.filteredApps

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool isSel: index === root.selectedIndex

                    width: Math.max(0, appList.width || 0)
                    height: 50
                    radius: 15
                    color: isSel ? MusicState.m3PrimaryContainer : (aMa.containsMouse ? MusicState.m3SurfaceContainerHigh : "transparent")
                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 12
                        spacing: 12

                        Item {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            Layout.alignment: Qt.AlignVCenter

                            // Original untouched app icon
                            IconImage {
                                visible: modelData.kind === "app"
                                anchors.centerIn: parent
                                implicitSize: 28
                                mipmap: true
                                asynchronous: true
                                source: modelData.kind === "app"
                                    ? (modelData.icon ? (Quickshell.iconPath(modelData.icon, true) || Quickshell.iconPath("application-x-executable", true) || "") : (Quickshell.iconPath("application-x-executable", true) || ""))
                                    : ""
                            }

                            Rectangle {
                                visible: modelData.kind === "cmd"
                                anchors.fill: parent
                                radius: 10
                                color: MusicState.m3SurfaceContainerHighest
                                SysIcon {
                                    anchors.centerIn: parent
                                    name: modelData.sysIcon || "apps"
                                    size: 16
                                    color: MusicState.m3Primary
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: modelData.name
                                color: isSel ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface
                                font.family: MusicState.fontUi
                                font.pixelSize: 13
                                font.weight: Font.SemiBold
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: modelData.desc
                                color: isSel ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurfaceVariant
                                opacity: isSel ? 0.85 : 1.0
                                font.family: MusicState.fontUi
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                        }

                        // Subtle Material 3 badge for recently launched apps
                        Rectangle {
                            visible: modelData.isRecent === true
                            Layout.preferredHeight: 20
                            Layout.preferredWidth: recBadgeTxt.implicitWidth + 12
                            Layout.alignment: Qt.AlignVCenter
                            radius: 10
                            color: isSel ? MusicState.m3Primary : MusicState.m3SecondaryContainer

                            Text {
                                id: recBadgeTxt
                                anchors.centerIn: parent
                                text: "Недавнее"
                                color: isSel ? MusicState.m3OnPrimary : MusicState.m3OnSecondaryContainer
                                font.family: MusicState.fontUi
                                font.pixelSize: 10
                                font.weight: Font.Bold
                            }
                        }
                    }

                    MouseArea {
                        id: aMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selectedIndex = index
                        onClicked: {
                            root.selectedIndex = index
                            root.activateCurrent()
                        }
                    }
                }
            }

            // TAB 1: Open Hyprland Windows Switcher
            ListView {
                id: winList
                visible: root.activeTab === 1
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: root.filteredWindows

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool isSel: index === root.selectedIndex

                    width: Math.max(0, winList.width || 0)
                    height: 50
                    radius: 15
                    color: isSel ? MusicState.m3PrimaryContainer : (wMa.containsMouse ? MusicState.m3SurfaceContainerHigh : "transparent")
                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 12
                        spacing: 12

                        IconImage {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            Layout.alignment: Qt.AlignVCenter
                            implicitSize: 28
                            mipmap: true
                            asynchronous: true
                            source: modelData.icon ? (Quickshell.iconPath(modelData.icon, true) || Quickshell.iconPath("application-x-executable", true) || "") : ""
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: modelData.title
                                color: isSel ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurface
                                font.family: MusicState.fontUi
                                font.pixelSize: 13
                                font.weight: Font.SemiBold
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.appId
                                color: isSel ? MusicState.m3OnPrimaryContainer : MusicState.m3OnSurfaceVariant
                                opacity: 0.8
                                font.family: MusicState.fontUi
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                        }
                    }

                    MouseArea {
                        id: wMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selectedIndex = index
                        onClicked: {
                            root.selectedIndex = index
                            root.activateCurrent()
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: winList.count === 0
                    text: "Нет открытых окон"
                    color: MusicState.m3OnSurfaceVariant
                    font.family: MusicState.fontUi
                    font.pixelSize: 13
                }
            }

            // TAB 2: Emoji Grid Picker (click copies to clipboard!)
            GridView {
                id: emojiGrid
                visible: root.activeTab === 2
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: Math.floor(width / 6)
                cellHeight: 54
                model: root.filteredEmojis

                delegate: Item {
                    required property var modelData
                    required property int index
                    width: emojiGrid.cellWidth
                    height: emojiGrid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: 14
                        color: (index === root.selectedIndex || eMa.containsMouse) ? MusicState.m3PrimaryContainer : MusicState.m3SurfaceContainerHigh

                        Text {
                            anchors.centerIn: parent
                            text: modelData.e
                            font.pixelSize: 24
                        }

                        MouseArea {
                            id: eMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.selectedIndex = index
                            onClicked: {
                                root.selectedIndex = index
                                root.activateCurrent()
                            }
                        }
                    }
                }
            }
        }
    }
}
