pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland

Singleton {
    id: root

    property bool centerOpen: false
    property bool islandExpanded: false
    property bool dndEnabled: false
    property var history: []
    property var activeToast: null
    property int unreadCount: 0

    NotificationServer {
        id: server
        bodySupported: true
        bodyMarkupSupported: false
        actionsSupported: true
        imageSupported: true
        keepOnReload: true

        onNotification: function(n) {
            n.tracked = true
            const nowStr = Qt.formatTime(new Date(), "HH:mm")
            const entry = {
                id: n.id,
                appName: n.appName || "Система",
                desktopEntry: n.desktopEntry || "",
                summary: n.summary || "",
                body: n.body || "",
                appIcon: n.appIcon || "",
                image: n.image || "",
                time: nowStr,
                actions: n.actions || [],
                notif: n
            }

            const next = [entry].concat(root.history).slice(0, 25)
            root.history = next
            if (!root.centerOpen) {
                root.unreadCount += 1
            }

            if (!root.dndEnabled) {
                root.activeToast = entry
                toastTimer.restart()
            }
        }
    }

    Timer {
        id: toastTimer
        interval: ShellConfig.toastDurationMs
        repeat: false
        onTriggered: root.activeToast = null
    }

    function toggleCenter() {
        centerOpen = !centerOpen
        if (centerOpen) {
            unreadCount = 0
            islandExpanded = false
            activeToast = null
        }
    }

    function toggleIsland() {
        islandExpanded = !islandExpanded
        if (islandExpanded) {
            centerOpen = false
        }
    }

    function closeAllPopups() {
        centerOpen = false
        islandExpanded = false
    }

    function focusAppForEntry(entry) {
        if (!entry) return false
        const toplevels = ToplevelManager.toplevels.values || []
        const keys = []
        if (entry.desktopEntry) keys.push(String(entry.desktopEntry).toLowerCase())
        if (entry.appName) keys.push(String(entry.appName).toLowerCase())
        if (keys.length === 0) return false

        for (let i = 0; i < toplevels.length; i++) {
            const tl = toplevels[i]
            if (!tl) continue
            const aid = String(tl.appId || "").toLowerCase()
            const ttl = String(tl.title || "").toLowerCase()
            for (let k = 0; k < keys.length; k++) {
                const key = keys[k]
                if (!key) continue
                if (aid.indexOf(key) !== -1 || key.indexOf(aid) !== -1 && aid !== "" || ttl.indexOf(key) !== -1) {
                    try {
                        tl.activate()
                        return true
                    } catch (e) {}
                }
            }
        }
        return false
    }

    function removeEntryById(entryId, fallbackIdx) {
        let idx = fallbackIdx
        if (idx === undefined || idx < 0 || idx >= history.length || (history[idx] && history[idx].id !== entryId)) {
            idx = -1
            for (let i = 0; i < history.length; i++) {
                if (history[i] && history[i].id === entryId) {
                    idx = i
                    break
                }
            }
        }
        if (idx >= 0) {
            const copy = history.slice()
            copy.splice(idx, 1)
            history = copy
        }
    }

    function activateEntry(entry, idx) {
        if (!entry) return
        let invoked = false
        const acts = (entry.notif && entry.notif.actions) ? entry.notif.actions : (entry.actions || [])

        // 1. Prefer the notification's "default" action (standard Desktop Notifications spec)
        for (let i = 0; i < acts.length; i++) {
            const a = acts[i]
            if (a && a.identifier === "default") {
                try {
                    a.invoke()
                    invoked = true
                } catch (e) {}
                break
            }
        }

        // 2. Also bring the sending app window to focus in Hyprland
        focusAppForEntry(entry)

        // 3. If no default action existed and there's a single action, invoke it
        if (!invoked && acts.length === 1 && acts[0]) {
            try { acts[0].invoke() } catch (e) {}
        }

        centerOpen = false
        activeToast = null
        removeEntryById(entry.id, idx)
    }

    function invokeAction(entry, actionObj, idx) {
        if (actionObj) {
            try { actionObj.invoke() } catch (e) {}
        }
        focusAppForEntry(entry)
        centerOpen = false
        activeToast = null
        if (entry) removeEntryById(entry.id, idx)
    }

    function dismissAt(idx) {
        if (idx < 0 || idx >= history.length) return
        const item = history[idx]
        if (item && item.notif) {
            try { item.notif.dismiss() } catch (e) {}
        }
        const copy = history.slice()
        copy.splice(idx, 1)
        history = copy
    }

    function clearAll() {
        for (let i = 0; i < history.length; i++) {
            if (history[i] && history[i].notif) {
                try { history[i].notif.dismiss() } catch (e) {}
            }
        }
        history = []
        unreadCount = 0
    }
}
