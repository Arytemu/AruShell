pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pam

/**
 * Caelestia-style Native Lock Screen State & PAM Authentication Service.
 * Supports smooth animated lock-in and animated unlock transitions before releasing WlSessionLock.
 */
Singleton {
    id: root

    property bool locked: false
    property bool unlocking: false
    property bool authenticating: false
    property string passwordText: ""
    property string errorText: ""
    property int failedCount: 0

    signal wrongPasswordPulse()

    function lock() {
        if (locked) return
        unlockFinishTimer.stop()
        unlocking = false
        passwordText = ""
        errorText = ""
        authenticating = false
        ShellConfig.closeDesktopMenu()
        ShellConfig.settingsOpen = false
        WallpaperState.open = false
        SystemState.quickSettingsOpen = false
        SystemState.launcherOpen = false
        ClipboardState.open = false
        NotifState.closeAllPopups()
        SystemState.refreshAll()
        locked = true
    }

    function submitPassword() {
        if (!locked || unlocking || authenticating) return
        if (passwordText.length === 0) return
        errorText = ""
        authenticating = true
        pam.start()
    }

    PamContext {
        id: pam
        config: "login"

        onPamMessage: {
            if (pam.responseRequired) {
                pam.respond(root.passwordText)
            }
        }

        onCompleted: function(result) {
            root.authenticating = false
            if (result === PamResult.Success) {
                root.passwordText = ""
                root.errorText = ""
                root.failedCount = 0
                // Play Caelestia reverse blur/scale exit animation before releasing Wayland session lock
                root.unlocking = true
                unlockFinishTimer.restart()
            } else {
                root.failedCount += 1
                root.passwordText = ""
                root.errorText = "Неверный пароль"
                root.wrongPasswordPulse()
                errClearTimer.restart()
            }
        }
    }

    Timer {
        id: unlockFinishTimer
        interval: 380
        repeat: false
        onTriggered: {
            root.locked = false
            root.unlocking = false
        }
    }

    Timer {
        id: errClearTimer
        interval: 3000
        repeat: false
        onTriggered: root.errorText = ""
    }
}
