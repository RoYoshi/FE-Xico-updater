// SPDX-FileCopyrightText: 2025-2026 Robert French <frenchrobertm@outlook.com>
// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FC

import io.github.royoshi.fexicoupdater
import io.github.rfrench3.controllable as GP

FC.FormCardPage {
    id: page

    readonly property color feXicoGreen: "#00FF00"
    readonly property color feXicoMagenta: "#FF00FF"

    title:
        GP.Labels.east
        + GP.Labels.spacer_large
        + i18n("Deployments & Recovery")

    function grabScrollbar(item) {
        if (item.contentItem?.ScrollBar?.vertical)
            return item.contentItem.ScrollBar.vertical;

        if (item.parent)
            return grabScrollbar(item.parent);

        console.warn(
            "Parent scrollbar not found, controller scrolling will not function!"
        );
    }

    property ScrollBar scrollbar: page.grabScrollbar(page)

    function handleInput(buttonId, button_down) {
        if (!button_down)
            return;

        if (consoleDrawer.drawerOpen) {
            consoleDrawer.handleInput(buttonId, button_down);
            return;
        }

        switch (buttonId) {
        case 3: // Y
            toggleConsole.trigger();

            for (let i = 0; i < 5; ++i)
                hidePassiveNotification();

            break;
        }
    }

    actions: [
        Kirigami.Action {
            id: toggleConsole

            text:
                i18n("Toggle Console")
                + GP.Labels.spacer
                + GP.Labels.north

            icon.name: "utilities-terminal-symbolic"
            shortcut: "F12"

            onTriggered:
                consoleDrawer.drawerOpen = !consoleDrawer.drawerOpen
        }
    ]

    GP.PageNavigation {
        targetScrollbar: page.scrollbar

        active:
            !globalDrawer.drawerOpen
            && !consoleDrawer.drawerOpen
            && !applicationWindow().activeDialog
    }

    FC.FormHeader {
        title: i18n("Rollback FE-Xico")
        visible: rollbackFC.visible
    }

    FC.FormCard {
        id: rollbackFC

        visible:
            AppConfig.ini.Commands?.systemRollbackCommand
            || ""

        FC.FormTextDelegate {
            text: i18n(
                "Rollback queues the previous system deployment for the next boot. "
                + "User data under /var is shared, while /etc configuration returns to the previous deployment's state. "
                + "A pending update will not be discarded; rollback is refused while one is staged."
            )

            textItem.wrapMode: Text.Wrap
        }

        FormDelegateSeparatorFixed {}

        FC.FormCheckDelegate {
            id: rollbackConfirm

            text: i18n("I understand and want to roll back")

            enabled:
                AppState.allowCommands
                && !AppState.rollbackRunning
        }

        FormDelegateSeparatorFixed {}

        FC.FormButtonDelegate {
            text: AppState.rollbackRunning
                ? i18n("Rolling Back FE-Xico…")
                : i18n("Rollback to Previous Deployment")

            enabled:
                rollbackConfirm.checked
                && rollbackConfirm.enabled

            onClicked: {
                showPassiveNotification(
                    i18n("FE-Xico rollback started."),
                    Kirigami.short
                );

                RebaseHelperBackend.rollbackImage(function(callback) {
                    if (callback != 0) {
                        showPassiveNotification(
                            i18n(
                                "FE-Xico rollback failed. "
                                + "Check the console for details."
                            ),
                            Kirigami.long,
                            i18n("Open Console")
                                + GP.Labels.spacer
                                + GP.Labels.north,
                            consoleDrawer.open
                        );
                    } else {
                        showPassiveNotification(
                            AppState.resultMessage,
                            Kirigami.short
                        );

                        rollbackConfirm.checked = false;
                    }
                });
            }

            trailing: BusyIndicator {
                id: rollbackBusyIndicator
                running: AppState.rollbackRunning
            }

            trailingLogo.visible:
                !rollbackBusyIndicator.running
        }
    }

    FC.FormHeader {
        title: i18n("Current Deployment")
        visible: true
    }

    FCSystemInfo {}

    FC.FormCard {
        FC.FormButtonDelegate {
            text: i18n("Refresh Deployment Status")
            enabled: AppState.allowCommands && !!(AppConfig.ini.Commands?.systemStatusCommand || "")
            onClicked: RebaseHelperBackend.refreshStatus(function(code) {
                showPassiveNotification(AppState.resultMessage, Kirigami.long);
                if (code !== 0) consoleDrawer.drawerOpen = true;
            })
        }
    }

    FC.FormHeader {
        title: i18n("System Information")
    }

    FCOsRelease {}

    ConsoleDrawer {
        id: consoleDrawer
        model: RebaseHelperBackend.consoleModel
    }
}