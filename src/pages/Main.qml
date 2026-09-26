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

    // ─────────────────────────────────────────────────────────
    // FE-Xico identity
    // ─────────────────────────────────────────────────────────

    readonly property string appIconName: "io.github.royoshi.fexicoupdater"

    readonly property color feXicoGreen: "#39FF14"
    readonly property color feXicoMagenta: "#FF00FF"
    readonly property color feXicoSilver: "#C0C0C0"

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

        // Preserve KDE styling while giving selections the
        // characteristic FE-Xico magenta accent.
        Kirigami.Theme.highlightColor: root.feXicoMagenta

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
                    root.activeDialog.accept();
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
                    AppState.commandSucceeded
                        ? i18n("Restart to Apply Update")
                        : i18n("Reboot System")
                ) + GP.Labels.spacer + GP.Labels.north

                icon.name:
                    AppState.commandSucceeded
                        ? "system-shutdown-update-symbolic"
                        : "system-shutdown-symbolic"

                enabled: !AppState.commandRunning

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
                            AppState.commandSucceeded
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
                actionReboot.triggered();
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

        title: AppState.commandSucceeded
            ? i18nc("@title:window", "Apply FE-Xico Update")
            : i18nc("@title:window", "Reboot System")

        standardButtons: Kirigami.Dialog.NoButton

        enabled: !AppState.commandRunning
        activeDialogParent: root

        subtitle: AppState.commandSucceeded
            ? i18n(
                "Restart the system to boot into the newly staged FE-Xico deployment."
            )
            : i18n("This will reboot the system.")

        customFooterActions: [
            Kirigami.Action {
                id: confirmReboot

                text:
                    i18n("Reboot")
                    + GP.Labels.spacer
                    + GP.Labels.south

                icon.name: AppState.commandSucceeded
                    ? "system-shutdown-update-symbolic"
                    : "system-reboot-symbolic"

                onTriggered:
                    rebootDialog.accept()
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
            AppState.rebootSystem(function(callback) {
                rebootTimer.start();
                console.log("Reboot callback: " + callback);
            });
        }

        // Wait before reporting failure so a successful reboot
        // doesn't briefly display an error notification.
        Timer {
            id: rebootTimer

            interval: 5000
            repeat: false

            onTriggered:
                root.showPassiveNotification(
                    i18n(
                        "FE-Xico Updater was unable to reboot the system. "
                        + "Reboot through your system menu to apply changes."
                    )
                )
        }

        function handleInput(buttonId, button_down) {
            if (!button_down)
                return;

            switch (buttonId) {
            case 0: // A
                confirmReboot.triggered();
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
                return AppState.commandSucceeded
                    ? i18n(
                        "The FE-Xico update is staged. "
                        + "Restart the system to apply it."
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
                    + "Exiting now may leave the system update incomplete."
                );
            }

            return i18n(
                "An update operation is still running. "
                + "If you exit now, its changes may not be applied."
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

                onTriggered:
                    exitDialog.accept()
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
                confirmExit.triggered();
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