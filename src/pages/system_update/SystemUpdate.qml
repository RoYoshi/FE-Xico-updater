// SPDX-FileCopyrightText: 2025-2026 Robert French <frenchrobertm@outlook.com>
// SPDX-License-Identifier: GPL-2.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FC

import io.github.royoshi.fexicoupdater
import io.github.rfrench3.controllable as GP

Kirigami.Page {
    id: page

    // ─────────────────────────────────────────────────────────
    // FE-Xico branding
    // ─────────────────────────────────────────────────────────

    readonly property color feXicoGreen: "#00FF00"
    readonly property color feXicoMagenta: "#FF00FF"
    readonly property color feXicoSilver: "#C0C0C0"

    // HACK:
    // Global drawer gamepad labels are placed in the page titles.
    title:
        GP.Labels.east
        + GP.Labels.spacer_large
        + i18n("System Update")

    // ─────────────────────────────────────────────────────────
    // Controller input
    // ─────────────────────────────────────────────────────────

    function handleInput(buttonId, button_down) {
        if (!button_down)
            return;

        switch (buttonId) {
        case 0: // A
            updateButton.animateClick();
            return;
        }

        if (consoleDrawer.drawerOpen) {
            consoleDrawer.handleInput(buttonId, button_down);
            return;
        }

        switch (buttonId) {
        case 3: // Y
            toggleConsole.trigger();

            // Close up to five passive notifications.
            for (let i = 0; i < 5; ++i) {
                hidePassiveNotification();
            }

            break;
        }
    }

    // ─────────────────────────────────────────────────────────
    // Update action
    // ─────────────────────────────────────────────────────────

    Kirigami.Action {
        id: updateAction

        text:
            i18n("Update FE-Xico")
            + GP.Labels.spacer
            + GP.Labels.south

        shortcut: "Return"

        enabled:
            AppState.allowCommands
            && !SystemUpdateBackend.blockUpdate
            && (AppConfig.ini.Commands?.systemUpdateCommand || "")

        onTriggered: {
            SystemUpdateBackend.runUpdate(function(code) {
                showPassiveNotification(AppState.resultMessage, code === 0 ? Kirigami.short : Kirigami.long);
                if (code !== 0)
                    consoleDrawer.drawerOpen = true;
            });
        }
    }

    // ─────────────────────────────────────────────────────────
    // Main content
    // ─────────────────────────────────────────────────────────

    ColumnLayout {
        id: pageContents

        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
        }

        width: Math.min(
            parent.width - Kirigami.Units.gridUnit * 2,
            Kirigami.Units.gridUnit * 32
        )

        spacing: Kirigami.Units.largeSpacing

        // ─────────────────────────────────────────────────────
        // FE-Xico header
        // ─────────────────────────────────────────────────────

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Icon {
                source: "io.github.royoshi.fexicoupdater"

                Layout.preferredWidth:
                    Kirigami.Units.iconSizes.huge

                Layout.preferredHeight:
                    Kirigami.Units.iconSizes.huge
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Kirigami.Heading {
                    text: i18n("FE-Xico Updater")
                    level: 1
                    Layout.fillWidth: true
                }

                QQC2.Label {
                    text: i18n("Fedora Atomic. Refined.")

                    color: page.feXicoSilver

                    font.pixelSize:
                        Kirigami.Theme.defaultFont.pixelSize * 1.05

                    opacity: 0.85
                }
            }
        }

        // FE-Xico accent line
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 3

            radius: height / 2
            color: page.feXicoMagenta
        }

        // ─────────────────────────────────────────────────────
        // Current system status
        // ─────────────────────────────────────────────────────

        Rectangle {
            Layout.fillWidth: true

            implicitHeight:
                statusLayout.implicitHeight
                + Kirigami.Units.largeSpacing * 2

            radius: Kirigami.Units.cornerRadius

            color: Kirigami.Theme.backgroundColor

            border.width: 1

            border.color:
                AppState.commandSucceeded
                    ? page.feXicoGreen
                    : Kirigami.Theme.disabledTextColor

            RowLayout {
                id: statusLayout

                anchors {
                    fill: parent
                    margins: Kirigami.Units.largeSpacing
                }

                spacing: Kirigami.Units.largeSpacing

                Rectangle {
                    Layout.preferredWidth:
                        Kirigami.Units.gridUnit

                    Layout.preferredHeight:
                        Kirigami.Units.gridUnit

                    radius: width / 2

                    color: {
                        if (AppState.updateRunning)
                            return page.feXicoMagenta;

                        if (AppState.commandSucceeded)
                            return page.feXicoGreen;

                        return Kirigami.Theme.disabledTextColor;
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Heading {
                        level: 3

                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: AppState.resultMessage || i18n(
                            "Check for and stage FE-XicoOS image updates. Flatpak apps are managed separately in your app store."
                        )

                        opacity: 0.75
                    }
                }

                Kirigami.Icon {
                    visible: AppState.commandSucceeded

                    source: "checkmark-symbolic"

                    color: page.feXicoGreen

                    Layout.preferredWidth:
                        Kirigami.Units.iconSizes.medium

                    Layout.preferredHeight:
                        Kirigami.Units.iconSizes.medium
                }
            }
        }

        // ─────────────────────────────────────────────────────
        // System identity
        // ─────────────────────────────────────────────────────

        RowLayout {
            Layout.fillWidth: true

            spacing: Kirigami.Units.largeSpacing

            Item {
                Layout.preferredWidth:
                    Kirigami.Units.iconSizes.huge

                Layout.preferredHeight:
                    Kirigami.Units.iconSizes.huge

                Image {
                    anchors.fill: parent

                    source:
                        AppConfig.osAboutData.programLogo
                            ? "file:/"
                                + AppConfig.osAboutData.programLogo
                            : "qrc:/fallbackLogo"

                    sourceSize:
                        Qt.size(width, height)

                    fillMode: Image.PreserveAspectFit
                    antialiasing: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Kirigami.Heading {
                    level: 2

                    text:
                        i18n("System Update")
                }

                QQC2.Label {
                    text:
                        AppConfig.osAboutData.displayName
                        || i18n("FE-Xico")

                    opacity: 0.7
                }
            }
        }

        // ─────────────────────────────────────────────────────
        // Update card
        // ─────────────────────────────────────────────────────

        FC.FormCard {
            id: updateFC

            Layout.fillWidth: true

            maximumWidth:
                pageContents.width

            FC.FormButtonDelegate {
                id: updateButton

                text: {
                    if (AppState.updateRunning)
                        return AppState.operation === "check" ? i18n("Checking for updates…")
                            : AppState.operation === "status" ? i18n("Reading deployments…")
                            : i18n("Updating FE-Xico…");

                    if (AppState.commandSucceeded)
                        return i18n("Update FE-Xico");

                    return i18n("Update FE-Xico");
                }

                enabled: updateAction.enabled

                onClicked:
                    updateAction.trigger()

                trailing: Loader {
                    sourceComponent: {
                        if (AppState.updateRunning)
                            return busyComponent;

                        if (AppState.commandSucceeded)
                            return checkmarkComponent;

                        return labelComponent;
                    }

                    Component {
                        id: busyComponent

                        QQC2.BusyIndicator {
                            running:
                                AppState.updateRunning
                        }
                    }

                    Component {
                        id: checkmarkComponent

                        Kirigami.Icon {
                            source: "checkmark-symbolic"

                            visible:
                                AppState.commandSucceeded

                            color: page.feXicoGreen
                        }
                    }

                    Component {
                        id: labelComponent

                        Kirigami.Heading {
                            text: GP.Labels.south
                        }
                    }
                }

                trailingLogo.visible:
                    !AppState.updateRunning
                    && !AppState.commandSucceeded

                description: i18n("Stages the OS image only. Your running deployment is unchanged until reboot.")
            }

            FormDelegateSeparatorFixed {}

            FC.FormButtonDelegate {
                text: i18n("Check for OS Updates")
                description: i18n("Fetch image metadata without staging a deployment.")
                enabled: AppState.allowCommands && !!(AppConfig.ini.Commands?.systemCheckCommand || "")
                onClicked: SystemUpdateBackend.checkUpdates(function(code) {
                    showPassiveNotification(AppState.resultMessage, Kirigami.long);
                    if (code !== 0) consoleDrawer.drawerOpen = true;
                })
            }

            FormDelegateSeparatorFixed {}

            FC.FormButtonDelegate {
                text: i18n("Refresh Deployment Status")
                enabled: AppState.allowCommands && !!(AppConfig.ini.Commands?.systemStatusCommand || "")
                onClicked: SystemUpdateBackend.refreshStatus(function(code) {
                    showPassiveNotification(AppState.resultMessage, Kirigami.long);
                    if (code !== 0) consoleDrawer.drawerOpen = true;
                })
            }

            FormDelegateSeparatorFixed {
                visible: errorUpdateNotFound.visible
            }

            FC.FormTextDelegate {
                id: errorUpdateNotFound

                visible:
                    !(
                        AppConfig.ini.Commands
                            ?.systemUpdateCommand
                        || ""
                    )

                enabled: visible

                text:
                    i18n(
                        "The FE-Xico system update command "
                        + "is not defined."
                    )

                description:
                    i18n(
                        "Make sure "
                        + "/etc/fe-xico-updater/config.ini "
                        + "is present."
                    )
            }
        }

        // ─────────────────────────────────────────────────────
        // Progress
        // ─────────────────────────────────────────────────────

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.ProgressBar {
                Layout.fillWidth: true

                value:
                    AppState.commandSucceeded
                        ? 1.0
                        : 0.0

                indeterminate:
                    AppState.updateRunning
            }

            QQC2.Label {
                Layout.alignment:
                    Qt.AlignHCenter

                visible:
                    AppState.updateRunning
                    || AppState.commandSucceeded

                text: {
                    if (AppState.updateRunning)
                        return i18n(
                            "Preparing the latest "
                            + "FE-XicoOS operation…"
                        );

                    if (AppState.commandSucceeded)
                        return AppState.rebootRequired ? i18n("Restart when ready to apply the pending deployment.") : i18n("No restart is needed.");

                    return "";
                }

                color:
                    AppState.commandSucceeded
                        ? page.feXicoGreen
                        : Kirigami.Theme.textColor

                opacity:
                    AppState.commandSucceeded
                        ? 1.0
                        : 0.8
            }
        }

        Item {
            Layout.preferredHeight:
                Kirigami.Units.largeSpacing
        }
    }

    // ─────────────────────────────────────────────────────────
    // Page actions
    // ─────────────────────────────────────────────────────────

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
                consoleDrawer.drawerOpen =
                    !consoleDrawer.drawerOpen
        }
    ]

    // ─────────────────────────────────────────────────────────
    // Console
    // ─────────────────────────────────────────────────────────

    ConsoleDrawer {
        id: consoleDrawer
        model: SystemUpdateBackend.consoleModel
    }
}