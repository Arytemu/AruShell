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
    property var mutedApps: ({})

    function isAppMuted(appName) {
        const key = String(appName || "").trim().toLowerCase()
        if (!key || !mutedApps[key]) return false
        if (Date.now() > mutedApps[key]) {
            const copy = Object.assign({}, mutedApps)
            delete copy[key]
            mutedApps = copy
            return false
        }
        return true
    }

    function muteApp(appName, hours) {
        const key = String(appName || "").trim().toLowerCase()
        if (!key) return
        const copy = Object.assign({}, mutedApps)
        copy[key] = Date.now() + hours * 3600 * 1000
        mutedApps = copy
        SystemState.showOsd("bell_off", appName, 1.0, "Мут " + hours + "ч", false)
    }

    function unmuteApp(appName) {
        const key = String(appName || "").trim().toLowerCase()
        if (!key) return
        const copy = Object.assign({}, mutedApps)
        delete copy[key]
        mutedApps = copy
        SystemState.showOsd("bell", appName, 1.0, "Звук вкл", false)
    }
    property var history: []
    property var activeToast: null
    property int unreadCount: 0

    // Keep live C++ Notification* references strictly out of ListView model items,
    // and clean them up immediately when `closed` fires so Qt never hits a dangling QObject*!
    property var _liveNotifs: ({})

    NotificationServer {
        id: server
        bodySupported: true
        bodyMarkupSupported: false
        actionsSupported: true
        imageSupported: true
        keepOnReload: true

        onNotification: function(n) {
            if (!n) return
            n.tracked = true
            const nid = String(n.id)
            const nowStr = Qt.formatTime(new Date(), "HH:mm")

            // Snapshot actions as pure JS objects (no raw C++ NotificationAction* inside model!)
            const safeActions = []
            const rawActs = n.actions || []
            for (let i = 0; i < rawActs.length; i++) {
                const a = rawActs[i]
                if (!a) continue
                safeActions.push({
                    identifier: String(a.identifier || ""),
                    text: String(a.text || "")
                })
            }

            root._liveNotifs[nid] = n
            try {
                n.closed.connect(function() {
                    if (root._liveNotifs && root._liveNotifs[nid]) {
                        delete root._liveNotifs[nid]
                    }
                })
            } catch (e) {}

            const entry = {
                id: n.id,
                appName: String(n.appName || "Система"),
                desktopEntry: String(n.desktopEntry || ""),
                summary: String(n.summary || ""),
                body: String(n.body || ""),
                appIcon: String(n.appIcon || ""),
                image: String(n.image || ""),
                time: nowStr,
                actions: safeActions
            }

            // Replace existing entry with same id or prepend
            const filtered = root.history.filter(function(it) { return it && it.id !== n.id })
            root.history = [entry].concat(filtered).slice(0, 25)
            if (!root.centerOpen) {
                root.unreadCount += 1
            }

            if (!root.dndEnabled && !root.isAppMuted(entry.appName)) {
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
                if (aid.indexOf(key) !== -1 || (key.indexOf(aid) !== -1 && aid !== "") || ttl.indexOf(key) !== -1) {
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

    function _liveFor(entry) {
        if (!entry) return null
        return root._liveNotifs[String(entry.id)] || null
    }

    function activateEntry(entry, idx) {
        if (!entry) return
        let invoked = false
        const live = _liveFor(entry)
        const acts = (live && live.actions) ? live.actions : []

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

        focusAppForEntry(entry)

        if (!invoked && acts.length === 1 && acts[0]) {
            try { acts[0].invoke() } catch (e) {}
        }

        centerOpen = false
        activeToast = null
        removeEntryById(entry.id, idx)
    }

    function invokeAction(entry, actionObj, idx) {
        if (entry && actionObj) {
            const live = _liveFor(entry)
            const acts = (live && live.actions) ? live.actions : []
            for (let i = 0; i < acts.length; i++) {
                if (acts[i] && acts[i].identifier === actionObj.identifier) {
                    try { acts[i].invoke() } catch (e) {}
                    break
                }
            }
        }
        focusAppForEntry(entry)
        centerOpen = false
        activeToast = null
        if (entry) removeEntryById(entry.id, idx)
    }

    function dismissAt(idx) {
        if (idx < 0 || idx >= history.length) return
        const item = history[idx]
        const live = _liveFor(item)
        if (live) {
            try { live.dismiss() } catch (e) {}
            delete root._liveNotifs[String(item.id)]
        }
        const copy = history.slice()
        copy.splice(idx, 1)
        history = copy
    }

    function clearAll() {
        for (let i = 0; i < history.length; i++) {
            const live = _liveFor(history[i])
            if (live) {
                try { live.dismiss() } catch (e) {}
            }
        }
        _liveNotifs = ({})
        history = []
        unreadCount = 0
    }
}
