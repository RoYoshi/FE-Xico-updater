// SPDX-FileCopyrightText: 2025-2026 Robert French <frenchrobertm@outlook.com>
// SPDX-FileCopyrightText: 2026 RoYoshi
// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FC

import io.github.royoshi.fexicoupdater
import io.github.rfrench3.controllable as GP

// Deployments & Recovery: what is running, what starts after a restart, and
// the deliberately separate rollback control.
FC.FormCardPage {
    id: page

    title:
        GP.Labels.east
        + GP.Labels.spacer_large
        + i18n("Deployments & Recovery")

    readonly property var hostState: AppState.hostStatus.status || ({})
    readonly property bool known: !!hostState.booted

    function formatTime(value) {
        if (!value)
            return "";
        const date = new Date(value);
        return isNaN(date.getTime()) ? "" : date.toLocaleString(Qt.locale(), Locale.ShortFormat);
    }

    // Friendly description of one deployment, from bootc's own fields only.
    function describe(entry) {
        if (!entry)
            return "";
        const image = entry.image || ({});
        const lines = [];
        const parts = [];
        if (image.version)
            parts.push(image.version);
        const built = formatTime(image.timestamp);
        if (built)
            parts.push(i18nc("image build date", "built %1", built));
        if (parts.length > 0)
            lines.push(parts.join(" · "));
        lines.push(image.image?.image || i18n("Unknown image"));
        return lines.join("\n");
    }

    function rollbackSummary() {
        if (!known)
            return i18n("Rolling back queues the previous deployment for the next restart. Refresh the deployment status to see which one that is.");
        if (!hostState.rollback)
            return i18n("There is no previous deployment to return to.");
        return i18n("Rolling back queues this deployment to start the next time you restart:\n%1\n\nYour home folder and other data under /var are shared by both deployments and are not changed. System settings in /etc return to that deployment's state.", describe(hostState.rollback));
    }

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
                i18n("Technical Details")
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

    // ─────────────────────────────────────────────────────────
    // Deployments
    // ─────────────────────────────────────────────────────────

    FC.FormHeader {
        title: i18n("Deployments")
    }

    FC.FormCard {
        FC.FormTextDelegate {
            text: i18n("FE-XicoOS keeps the deployment you used before the last update, so you can return to it if something goes wrong.")
            textItem.wrapMode: Text.Wrap
        }

        FormDelegateSeparatorFixed {}

        FC.FormTextDelegate {
            icon.name: "computer-symbolic"
            description: page.known && page.hostState.booted.pinned
                ? i18n("Running now · pinned for recovery")
                : i18n("Running now")
            text: page.known
                ? page.describe(page.hostState.booted)
                : i18n("Not read yet. Select Refresh Deployment Status.")
            textItem.wrapMode: Text.WrapAnywhere
        }

        FormDelegateSeparatorFixed {
            visible: page.known
        }

        FC.FormTextDelegate {
            visible: page.known
            icon.name: "system-reboot-symbolic"
            description: i18n("Starts after the next restart")
            text: {
                if (page.hostState.staged)
                    return page.describe(page.hostState.staged)
                        + (page.hostState.staged.downloadOnly
                            ? "\n" + i18n("Download-only: locked, a restart will not apply it.")
                            : "");
                if (page.hostState.rollbackQueued)
                    return i18n("The previous deployment (rollback is queued).");
                return i18n("Nothing. The running deployment starts again.");
            }
            textItem.wrapMode: Text.WrapAnywhere
        }

        FormDelegateSeparatorFixed {
            visible: page.known
        }

        FC.FormTextDelegate {
            visible: page.known
            icon.name: "edit-undo-symbolic"
            description: i18n("Previous deployment")
            text: page.hostState.rollback
                ? page.describe(page.hostState.rollback)
                : i18n("None")
            textItem.wrapMode: Text.WrapAnywhere
        }

        FormDelegateSeparatorFixed {}

        FC.FormButtonDelegate {
            text: i18n("Refresh Deployment Status")
            icon.name: "view-refresh-symbolic"
            enabled: AppState.allowCommands && !!(AppConfig.ini.Commands?.systemStatusCommand || "")
            onClicked: RebaseHelperBackend.refreshStatus(function(code) {
                showPassiveNotification(AppState.resultMessage, Kirigami.long);
                if (code !== 0)
                    consoleDrawer.drawerOpen = true;
            })
        }

        FormDelegateSeparatorFixed {}

        FC.FormTextDelegate {
            text: i18n("This application does not select driver editions, switch images or manage recovery pins.")
            textItem.wrapMode: Text.Wrap
            textItem.color: FeXico.structure(Kirigami.Theme.backgroundColor)
        }
    }

    // ─────────────────────────────────────────────────────────
    // Rollback: kept apart from ordinary updates
    // ─────────────────────────────────────────────────────────

    FC.FormHeader {
        title: i18n("Roll Back")
        visible: rollbackFC.visible
    }

    FC.FormCard {
        id: rollbackFC

        visible: !!(AppConfig.ini.Commands?.systemRollbackCommand || "")

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.largeSpacing
            visible: true
            type: Kirigami.MessageType.Warning
            text: i18n("An OS rollback is not a backup. It does not restore or remove personal files.")
        }

        FC.FormTextDelegate {
            text: page.rollbackSummary()
            textItem.wrapMode: Text.Wrap
        }

        FormDelegateSeparatorFixed {}

        FC.FormTextDelegate {
            text: i18n("Rollback is refused while an update is waiting for a restart, so a prepared update is never discarded.")
            textItem.wrapMode: Text.Wrap
        }

        FormDelegateSeparatorFixed {}

        FC.FormCheckDelegate {
            id: rollbackConfirm

            text: i18n("I understand and want to roll back")

            enabled:
                AppState.allowCommands
                && !AppState.rollbackRunning
                && !(page.known && !page.hostState.rollback)
        }

        FormDelegateSeparatorFixed {}

        FC.FormButtonDelegate {
            text: AppState.rollbackRunning
                ? i18n("Queuing Rollback…")
                : i18n("Roll Back to Previous Deployment")
            icon.name: "edit-undo-symbolic"

            enabled:
                rollbackConfirm.checked
                && rollbackConfirm.enabled

            onClicked: {
                showPassiveNotification(
                    i18n("Queuing the FE-XicoOS rollback…"),
                    Kirigami.short
                );

                RebaseHelperBackend.rollbackImage(function(callback) {
                    if (callback != 0) {
                        showPassiveNotification(
                            i18n(
                                "The rollback was not queued. "
                                + "Open Technical Details for the full output."
                            ),
                            Kirigami.long,
                            i18n("Technical Details")
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

        FormDelegateSeparatorFixed {
            visible: page.hostState.rollbackQueued === true
        }

        FC.FormButtonDelegate {
            visible: page.hostState.rollbackQueued === true
            text: i18n("Restart to Finish Rollback")
            description: i18n("The previous deployment starts after the restart. Nothing has been rolled back yet.")
            icon.name: "system-reboot-symbolic"
            enabled: AppState.allowCommands
            onClicked: applicationWindow().openRestartDialog()
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
