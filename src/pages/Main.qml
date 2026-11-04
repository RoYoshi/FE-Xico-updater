// SPDX-FileCopyrightText: 2025 Robert French <frenchrobertm@outlook.com>
// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.statefulapp as StatefulApp

import io.github.royoshi.fexicoupdater
import io.github.rfrench3.controllable as GP

// NOTE:
// Gamepad.labels.* automatically show/hide themselves depending
// on the presence of a controller.

StatefulApp.StatefulWindow {
    id: root

    // Isolated QML load test; never starts an update or authentication request.
    function smokeTestPage(index) {
        if (!QmlSmokeTest)
            return;
        const pages = ["SystemUpdate.qml", "RebaseHelper.qml", "Settings.qml", "AboutDataOS.qml", "AboutDataApp.qml", "RssPage.qml"];
        pageStack.replace(Qt.resolvedUrl(pages[index]));
        return !!pageStack.currentItem && pageStack.currentItem.Window.window === root;
    }

    // ─────────────────────────────────────────────────────────
    // FE-Xico identity
    // ─────────────────────────────────────────────────────────

    readonly property string appIconName: "io.github.royoshi.fexicoupdater"

    // Read from the window's own theme, so child Theme overrides never feed back.
    readonly property bool darkScheme: FeXico.isDark(Kirigami.Theme.backgroundColor)

    // Used by pages for the restart-to-finish and review-deployments actions.
    function openRestartDialog() {
        if (AppState.allowCommands)
            rebootDialog.open();
    }

    function showDeployments() {
        deploymentsAction.trigger();
    }

    // One read-only status read at startup, so the dashboard can show the real
    // state. Never a check, update or rollback; skipped in tests and previews.
    Component.onCompleted: {
        if (QmlSmokeTest || PreviewMode || !UserSettings.readStatusOnStart)
            return;
        if (!AppState.allowCommands || !(AppConfig.ini.Commands?.systemStatusCommand || ""))
            return;
        SystemUpdateBackend.refreshStatus(function(code) {
            if (code !== 0)
                root.showPassiveNotification(i18n("Could not read the system status. Open Technical Details on System Update for the output."), "long");
        });
    }

    // Rendered screenshots of simulated states must say so.
    footer: Loader {
        active: PreviewMode
        sourceComponent: QQC2.Label {
            text: i18n("Simulated preview: example state for design review, not this computer's status.")
            horizontalAlignment: Text.AlignHCenter
            padding: Kirigami.Units.smallSpacing
            background: Rectangle {
                color: FeXico.secondary(Kirigami.Theme.backgroundColor)
                opacity: 0.25
            }
        }
    }

    title: i18nc("@title:window", "FE-Xico Updater")
    windowName: "FE-Xico Updater"

    minimumWidth: Kirigami.Units.gridUnit * 20
    minimumHeight: Kirigami.Units.gridUnit * 20

    visibility: (UseFullscreen || UserSettings.preferFullscreen)
        ? Window.FullScreen
        : Window.Windowed

    onClosing: close => {
        close.accepted = false;
        actionQuit.triggered();
    }

    // ─────────────────────────────────────────────────────────
    // Fullscreen shortcut
    // ─────────────────────────────────────────────────────────

    Shortcut {
        sequences: ["F11"]
        context: Qt.ApplicationShortcut
        enabled: !UseFullscreen

        onActivated: {
            if (root.visibility === Window.Windowed)
                root.visibility = Window.FullScreen;
            else if (root.visibility === Window.FullScreen)
                root.visibility = Window.Windowed;
        }
    }

    // ─────────────────────────────────────────────────────────
    // Controller / dialog handling
    // ─────────────────────────────────────────────────────────

    property var activeDialog: null

    Connections {
        target: GP.Gamepad

        function onButtonEvent(buttonId, button_down) {
            if (root.activeDialog) {
                if (root.activeDialog.visible !== false)
                    root.activeDialog.handleInput(buttonId, button_down);
                return;
            }

            switch (buttonId) {
            case 1: // B
            case 4: // View / Minus
            case 6: // Pause / Plus
                if (button_down)
                    globalDrawer.drawerOpen = !globalDrawer.drawerOpen;
                return;
            }

            if (globalDrawer.drawerOpen) {
                globalDrawer.handleInput(buttonId, button_down);
                return;
            }

            if (typeof root.pageStack.currentItem.handleInput === "function") {
                root.pageStack.currentItem.handleInput(buttonId, button_down);
                return;
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // FE-Xico navigation drawer
    // ─────────────────────────────────────────────────────────

    globalDrawer: Kirigami.GlobalDrawer {
        id: globalDrawer

        title: i18n("FE-Xico Updater")
        titleIcon: root.appIconName

        // Preserve KDE styling; the selected page gets FE-Xico's restrained
        // magenta (a darker form on light colour schemes).
        Kirigami.Theme.highlightColor: root.darkScheme ? FeXico.magenta : FeXico.magentaOnLight

        Behavior on width {
            NumberAnimation {
                duration: Kirigami.Units.shortDuration
                easing.type: Easing.InOutQuad
            }
        }

        // Some Kirigami versions do not calculate the drawer
        // width correctly, so determine it from the longest label.
        FontMetrics {
            id: actionFontMetrics
            font: Kirigami.Theme.defaultFont
        }

        function getMaxActionTextWidth() {
            let maxWidth = 0;

            for (let i = 0; i < actions.length; i++) {
                if (actions[i].text) {
                    let currentWidth =
                        actionFontMetrics.advanceWidth(actions[i].text);

                    if (currentWidth > maxWidth)
                        maxWidth = currentWidth;
                }
            }

            return maxWidth;
        }

        width: getMaxActionTextWidth()
            + Kirigami.Units.iconSizes.medium
            + (Kirigami.Units.largeSpacing * 4)

        // ─────────────────────────────────────────────────────
        // Drawer keyboard navigation
        // ─────────────────────────────────────────────────────

        Shortcut {
            sequences: [
                StandardKey.Back,
                StandardKey.Close,
                "F1",
                "Ctrl+M",
                "Escape"
            ]

            context: Qt.ApplicationShortcut

            onActivated: {
                if (root.activeDialog)
                    root.activeDialog.reject();
                else
                    globalDrawer.drawerOpen = !globalDrawer.drawerOpen;
            }
        }

        Shortcut {
            sequences: ["Return"]
            context: Qt.ApplicationShortcut
            enabled: globalDrawer.drawerOpen || root.activeDialog

            onActivated: {
                if (root.activeDialog)
                    root.activeDialog.handleInput(0, true);
                else
                    globalDrawer.drawerOpen = false;
            }
        }

        Shortcut {
            sequences: ["Up"]
            context: Qt.ApplicationShortcut
            enabled: globalDrawer.drawerOpen

            onActivated:
                globalDrawer.__navigateGlobalDrawer(-1)
        }

        Shortcut {
            sequences: ["Down"]
            context: Qt.ApplicationShortcut
            enabled: globalDrawer.drawerOpen

            onActivated:
                globalDrawer.__navigateGlobalDrawer(1)
        }

        QQC2.ActionGroup {
            id: pageSelector
        }

        // ─────────────────────────────────────────────────────
        // Navigation
        // ─────────────────────────────────────────────────────

        actions: [
            Kirigami.Action {
                id: systemUpdateAction
                text: i18n("System Update")
                icon.name: "system-software-update-symbolic"

                checkable: true
                QQC2.ActionGroup.group: pageSelector
                checked: true

                onTriggered:
                    root.pageStack.initialPage =
                        Qt.resolvedUrl("SystemUpdate.qml")
            },

            Kirigami.Action {
                id: deploymentsAction
                text: i18n("Deployments & Recovery")
                icon.name: "system-reboot-symbolic"

                checkable: true
                QQC2.ActionGroup.group: pageSelector

                onTriggered:
                    root.pageStack.initialPage =
                        Qt.resolvedUrl("RebaseHelper.qml")
            },

            Kirigami.Action {
                text: i18n("Release Notes")
                icon.name: "feed-subscribe-symbolic"

                checkable: true
                QQC2.ActionGroup.group: pageSelector

                onTriggered:
                    root.pageStack.initialPage =
                        Qt.resolvedUrl("RssPage.qml")
            },

            Kirigami.Action {
                separator: true
            },

            Kirigami.Action {
                text: i18n("Settings")
                icon.name: "settings-configure-symbolic"

                checkable: true
                QQC2.ActionGroup.group: pageSelector

                onTriggered:
                    root.pageStack.initialPage =
                        Qt.resolvedUrl("Settings.qml")
            },

            Kirigami.Action {
                text: i18nc(
                    "About (user's OS)",
                    "About %1",
                    AppConfig.osAboutData.displayName
                )

                icon.name: "help-about-symbolic"

                checkable: true
                QQC2.ActionGroup.group: pageSelector

                onTriggered:
                    root.pageStack.initialPage =
                        Qt.resolvedUrl("AboutDataOS.qml")
            },

            Kirigami.Action {
                text: i18n("About FE-Xico Updater")
                icon.name: root.appIconName

                checkable: true
                QQC2.ActionGroup.group: pageSelector

                onTriggered:
                    root.pageStack.initialPage =
                        Qt.resolvedUrl("AboutDataApp.qml")
            },

            Kirigami.Action {
                separator: true
            },

            // ─────────────────────────────────────────────────
            // Reboot
            // ─────────────────────────────────────────────────

            Kirigami.Action {
                id: actionReboot

                text: (
                    AppState.rebootRequired
                        ? i18n("Restart to Finish")
                        : i18n("Restart System")
                ) + GP.Labels.spacer + GP.Labels.north

                icon.name:
                    AppState.rebootRequired
                        ? "system-shutdown-update-symbolic"
                        : "system-shutdown-symbolic"

                enabled: AppState.allowCommands

                onTriggered: {
                    rebootDialog.open();
                }
            },

            // ─────────────────────────────────────────────────
            // Quit
            // ─────────────────────────────────────────────────

            Kirigami.Action {
                id: actionQuit

                text:
                    i18n("Quit")
                    + GP.Labels.spacer
                    + GP.Labels.west

                icon.name: "application-exit-symbolic"
                shortcut: StandardKey.Quit

                onTriggered: {
                    // A running command is always worth warning
                    // about; only the reboot reminder is optional.
                    if (
                        AppState.commandRunning
                        || (
                            AppState.rebootRequired
                            && UserSettings.showRebootReminder
                        )
                    ) {
                        exitDialog.open();
                    } else {
                        Qt.quit();
                    }
                }
            }
        ]

        // ─────────────────────────────────────────────────────
        // Drawer navigation helper
        // ─────────────────────────────────────────────────────

        function __navigateGlobalDrawer(direction) {
            let currentIndex = -1;

            for (let i = 0; i < globalDrawer.actions.length; i++) {
                if (globalDrawer.actions[i].checked) {
                    currentIndex = i;
                    break;
                }
            }

            let newIndex = currentIndex;

            for (let j = 0; j < globalDrawer.actions.length; j++) {
                newIndex += direction;

                // Do not wrap around.
                if (
                    newIndex < 0
                    || newIndex >= globalDrawer.actions.length
                ) {
                    return;
                }

                let item = globalDrawer.actions[newIndex];

                if (item.checkable)
                    break;
            }

            if (newIndex !== currentIndex) {
                if (currentIndex >= 0)
                    globalDrawer.actions[currentIndex].checked = false;

                globalDrawer.actions[newIndex].triggered();
                globalDrawer.actions[newIndex].checked = true;
            }
        }

        function handleInput(buttonId, button_down) {
            if (!button_down)
                return;

            switch (buttonId) {
            case 0: // A
                drawerOpen = false;
                break;

            case 2: // X
                actionQuit.triggered();
                break;

            case 3: // Y
                if (actionReboot.enabled)
                    actionReboot.trigger();
                break;

            case 11: // D-pad Up
                __navigateGlobalDrawer(-1);
                break;

            case 12: // D-pad Down
                __navigateGlobalDrawer(1);
                break;
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // Reboot confirmation
    // ─────────────────────────────────────────────────────────

    AppDialog {
        id: rebootDialog

        title: AppState.rebootRequired
            ? i18nc("@title:window", "Restart to Finish")
            : i18nc("@title:window", "Restart System")

        standardButtons: Kirigami.Dialog.NoButton

        enabled: AppState.allowCommands
        activeDialogParent: root

        subtitle: {
            if (AppState.hostStatus.status?.rollbackQueued)
                return i18n("Restart now to start the previous FE-XicoOS deployment. Save your work first.");
            if (AppState.rebootRequired)
                return i18n("Restart now to start your new FE-XicoOS deployment. Save your work first.");
            return i18n("This restarts the computer. Save your work first.");
        }

        customFooterActions: [
            Kirigami.Action {
                id: confirmReboot

                text:
                    i18n("Restart")
                    + GP.Labels.spacer
                    + GP.Labels.south

                icon.name: AppState.rebootRequired
                    ? "system-shutdown-update-symbolic"
                    : "system-reboot-symbolic"

                enabled: AppState.allowCommands
                onTriggered: {
                    if (enabled)
                        rebootDialog.accept();
                }
            },

            Kirigami.Action {
                id: cancelReboot

                text:
                    i18n("Cancel")
                    + GP.Labels.spacer
                    + GP.Labels.east

                onTriggered:
                    rebootDialog.reject()
            }
        ]

        onAccepted: {
            AppState.rebootSystem(function(code) {
                if (code !== 0)
                    root.showPassiveNotification(i18n("The restart request failed. Use the desktop system menu when ready."));
            });
        }

        function handleInput(buttonId, button_down) {
            if (!button_down)
                return;

            switch (buttonId) {
            case 0: // A
                if (confirmReboot.enabled)
                    confirmReboot.trigger();
                break;

            case 1: // B
                cancelReboot.triggered();
                break;
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // Exit confirmation
    // ─────────────────────────────────────────────────────────

    AppDialog {
        id: exitDialog

        title: i18n("Exit FE-Xico Updater")
        standardButtons: Kirigami.Dialog.NoButton

        activeDialogParent: root

        subtitle: {
            if (!AppState.commandRunning) {
                return AppState.rebootRequired
                    ? i18n(
                        "A deployment is waiting for a restart. "
                        + "Restart the system to start using it."
                    )
                    : i18n(
                        "No update operation is running. "
                        + "You may safely exit."
                    );
            }

            if (
                AppConfig.ini.Commands?.allowEarlyExit
                !== "true"
            ) {
                return i18n(
                    "An update operation is still running. "
                    + "The system service continues if this window disconnects. Wait for the result before rebooting."
                );
            }

            return i18n(
                "An update operation is still running. "
                + "The system service continues independently. Closing this window does not cancel it."
            );
        }

        QQC2.CheckBox {
            id: skipRebootReminder

            visible: !AppState.commandRunning
            enabled: visible

            text:
                i18n("Do not show this again")
                + GP.Labels.spacer
                + GP.Labels.north

            checked: !UserSettings.showRebootReminder

            onToggled: {
                UserSettings.showRebootReminder = !checked;

                // Assigning to checked drops the binding,
                // so put the binding back.
                checked = Qt.binding(
                    () => !UserSettings.showRebootReminder
                );
            }

            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
        }

        customFooterActions: [
            Kirigami.Action {
                id: confirmExit

                text:
                    i18nc(
                        "dialog to exit the application",
                        "Exit"
                    )
                    + GP.Labels.spacer
                    + GP.Labels.south

                enabled:
                    AppConfig.ini.Commands?.allowEarlyExit
                        === "true"
                    || !AppState.commandRunning

                onTriggered: {
                    if (enabled)
                        exitDialog.accept();
                }
            },

            Kirigami.Action {
                id: cancelExit

                text:
                    i18n("Cancel")
                    + GP.Labels.spacer
                    + GP.Labels.east

                onTriggered:
                    exitDialog.reject()
            }
        ]

        onAccepted:
            Qt.quit()

        function handleInput(buttonId, button_down) {
            if (!button_down)
                return;

            switch (buttonId) {
            case 0: // A
                if (confirmExit.enabled)
                    confirmExit.trigger();
                break;

            case 1: // B
                cancelExit.triggered();
                break;

            case 3: // Y
                if (skipRebootReminder.visible)
                    skipRebootReminder.animateClick();
                break;
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // Initial page
    // ─────────────────────────────────────────────────────────

    pageStack.initialPage:
        Qt.resolvedUrl("SystemUpdate.qml")
}