// SPDX-FileCopyrightText: 2025-2026 Robert French <frenchrobertm@outlook.com>
// SPDX-FileCopyrightText: 2026 RoYoshi
// SPDX-License-Identifier: GPL-2.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

import io.github.royoshi.fexicoupdater
import io.github.rfrench3.controllable as GP

import "status.js" as Status

// FE-Xico Updater dashboard. Everything shown here comes from the verified
// native backend result (AppState); nothing is inferred from silence.
Kirigami.ScrollablePage {
    id: page

    // HACK: global drawer gamepad labels are placed in the page titles.
    title: GP.Labels.east + GP.Labels.spacer_large + i18n("System Update")

    // ─────────────────────────────────────────────────────────
    // Verified state
    // ─────────────────────────────────────────────────────────

    readonly property var hostState: AppState.hostStatus.status || ({})
    readonly property var booted: hostState.booted || null
    readonly property string systemState: Status.dashboardState({
        updateRunning: AppState.updateRunning,
        rollbackRunning: AppState.rollbackRunning,
        operation: AppState.operation,
        outcome: AppState.outcome,
        lastCheckOutcome: AppState.lastCheckOutcome,
        host: AppState.hostStatus
    })
    readonly property string nextStep: Status.primaryAction(systemState)
    readonly property bool wideLayout: width >= Kirigami.Units.gridUnit * 30
    property bool showTechnical: false

    readonly property bool hasCheckCommand: !!(AppConfig.ini.Commands?.systemCheckCommand || "")
    readonly property bool hasUpdateCommand: !!(AppConfig.ini.Commands?.systemUpdateCommand || "")
    readonly property bool hasStatusCommand: !!(AppConfig.ini.Commands?.systemStatusCommand || "")

    function formatTime(value) {
        if (!value)
            return "";
        const date = new Date(value);
        return isNaN(date.getTime()) ? "" : date.toLocaleString(Qt.locale(), Locale.ShortFormat);
    }

    function imageRef(entry) {
        return entry?.image?.image?.image || "";
    }

    function versionAndDate(image) {
        if (!image)
            return "";
        const parts = [];
        if (image.version)
            parts.push(image.version);
        const built = formatTime(image.timestamp);
        if (built)
            parts.push(i18nc("image build date", "built %1", built));
        return parts.join(" · ");
    }

    function stateTitle() {
        switch (systemState) {
        case "reading": return i18n("Reading system status");
        case "checking": return i18n("Checking for updates");
        case "updating": return i18n("Downloading and preparing update");
        case "rolling-back": return i18n("Queuing rollback");
        case "update-available": return i18n("Update available");
        case "staged": return i18n("Update ready — restart to finish");
        case "rollback-staged": return i18n("Rollback ready — restart to finish");
        case "download-only": return i18n("Download kept — review needed");
        case "up-to-date": return i18n("Up to date");
        case "unchecked": return i18n("System status read");
        case "failed": return i18n("Operation not completed");
        default: return i18n("Status not read yet");
        }
    }

    function stateExplanation() {
        switch (systemState) {
        case "reading":
            return i18n("Asking bootc for the current, pending and previous deployments. Nothing is changed.");
        case "checking":
            return i18n("Comparing your FE-XicoOS image with the newest one in its registry. Only image information is downloaded; nothing on this system changes.");
        case "updating":
            return i18n("The new FE-XicoOS image is being downloaded and prepared as a new deployment. Your running system is not changed. This can take a while on a slow connection.");
        case "rolling-back":
            return i18n("Setting the previous deployment to start next time. Nothing changes until you restart.");
        case "update-available":
            return i18n("A newer FE-XicoOS image is available. Updating downloads it and prepares a new deployment; you keep using the current one until you restart.");
        case "staged":
            return i18n("Your new FE-XicoOS deployment has been prepared. Restart to begin using it. Until then, the current deployment stays in use.");
        case "rollback-staged":
            return i18n("The previous deployment will start the next time you restart. Nothing has been rolled back yet.");
        case "download-only":
            return i18n("A download-only deployment is locked, so a restart will not apply it. This updater does not unlock it. Review it under Deployments & Recovery.");
        case "up-to-date":
            return i18n("The last check found no newer FE-XicoOS image, and no deployment is waiting for a restart.");
        case "unchecked":
            return i18n("Your deployments were read and nothing is waiting for a restart. No update check has run yet.");
        case "failed":
            return AppState.resultMessage || i18n("The last operation could not be verified.");
        default:
            return i18n("FE-Xico Updater has not read this system's deployments yet. Check for updates to read them and look for a newer image.");
        }
    }

    function stateIcon() {
        switch (systemState) {
        case "up-to-date": return "checkmark-symbolic";
        case "update-available": return "update-none-symbolic";
        case "staged":
        case "rollback-staged": return "system-reboot-symbolic";
        case "download-only": return "dialog-warning-symbolic";
        case "failed": return "dialog-error-symbolic";
        case "unchecked": return "documentinfo-symbolic";
        default: return "dialog-question-symbolic";
        }
    }

    function stateDetail() {
        if (Status.isBusy(systemState))
            return i18n("The system service keeps working even if this window closes.");
        const checked = formatTime(AppState.lastCheckedAt);
        return checked ? i18n("Last checked: %1", checked) : "";
    }

    // ─────────────────────────────────────────────────────────
    // Operations
    // ─────────────────────────────────────────────────────────

    function finished(code) {
        showPassiveNotification(AppState.resultMessage, code === 0 ? Kirigami.short : Kirigami.long);
        if (code !== 0)
            consoleDrawer.drawerOpen = true;
    }

    function runPrimary() {
        switch (nextStep) {
        case "check":
            SystemUpdateBackend.checkUpdates(finished);
            break;
        case "update":
            SystemUpdateBackend.runUpdate(finished);
            break;
        case "restart":
            applicationWindow().openRestartDialog();
            break;
        case "review-deployments":
            applicationWindow().showDeployments();
            break;
        default: // progress, review-error
            consoleDrawer.drawerOpen = true;
            break;
        }
    }

    function primaryAvailable() {
        switch (nextStep) {
        case "check":
            return AppState.allowCommands && hasCheckCommand;
        case "update":
            return AppState.allowCommands && hasUpdateCommand && !SystemUpdateBackend.blockUpdate;
        case "restart":
            return AppState.allowCommands;
        default:
            return true;
        }
    }

    // ─────────────────────────────────────────────────────────
    // Controller input
    // ─────────────────────────────────────────────────────────

    function handleInput(buttonId, button_down) {
        if (!button_down)
            return;

        if (consoleDrawer.drawerOpen) {
            consoleDrawer.handleInput(buttonId, button_down);
            return;
        }

        switch (buttonId) {
        case 0: // A
            if (mainAction.enabled)
                mainAction.trigger();
            return;
        case 3: // Y
            toggleConsole.trigger();
            // Close up to five passive notifications.
            for (let i = 0; i < 5; ++i)
                hidePassiveNotification();
            return;
        }
    }

    Kirigami.Action {
        id: mainAction

        text: {
            let label;
            switch (page.nextStep) {
            case "update": label = i18n("Update System"); break;
            case "restart": label = i18n("Restart to Finish"); break;
            case "progress": label = i18n("View Progress"); break;
            case "review-error": label = i18n("Review Error"); break;
            case "review-deployments": label = i18n("Review Deployments"); break;
            default: label = i18n("Check for Updates"); break;
            }
            return label + GP.Labels.spacer + GP.Labels.south;
        }

        icon.name: {
            switch (page.nextStep) {
            case "update": return "system-software-update-symbolic";
            case "restart": return "system-reboot-symbolic";
            case "progress":
            case "review-error": return "utilities-terminal-symbolic";
            case "review-deployments": return "view-list-details-symbolic";
            default: return "view-refresh-symbolic";
            }
        }

        shortcut: "Return"

        enabled:
            page.primaryAvailable()
            && !consoleDrawer.drawerOpen
            && !globalDrawer.drawerOpen
            && !applicationWindow().activeDialog

        onTriggered: page.runPrimary()
    }

    Kirigami.Action {
        id: checkAction
        text: i18n("Check for Updates")
        icon.name: "view-refresh-symbolic"
        visible: page.nextStep !== "check" && page.nextStep !== "progress"
        enabled: AppState.allowCommands && page.hasCheckCommand
        onTriggered: SystemUpdateBackend.checkUpdates(page.finished)
    }

    Kirigami.Action {
        id: statusAction
        text: i18n("Refresh Status")
        icon.name: "view-list-details-symbolic"
        visible: page.nextStep !== "progress"
        enabled: AppState.allowCommands && page.hasStatusCommand
        onTriggered: SystemUpdateBackend.refreshStatus(page.finished)
    }

    actions: [
        Kirigami.Action {
            id: toggleConsole

            text: i18n("Technical Details") + GP.Labels.spacer + GP.Labels.north
            icon.name: "utilities-terminal-symbolic"
            shortcut: "F12"

            onTriggered: consoleDrawer.drawerOpen = !consoleDrawer.drawerOpen
        }
    ]

    // ─────────────────────────────────────────────────────────
    // Content
    // ─────────────────────────────────────────────────────────

    ColumnLayout {
        id: content
        spacing: Kirigami.Units.largeSpacing

        // Identity: one mark, one name.
        RowLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 40
            Layout.alignment: Qt.AlignHCenter
            spacing: Kirigami.Units.largeSpacing

            Image {
                source: "qrc:/updaterLogo"
                Layout.preferredWidth: Kirigami.Units.iconSizes.large
                Layout.preferredHeight: Kirigami.Units.iconSizes.large
                sourceSize: Qt.size(128, 128)
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                Accessible.ignored: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Kirigami.Heading {
                    Layout.fillWidth: true
                    level: 1
                    text: i18n("FE-Xico Updater")
                    font.family: FeXico.headingFamily(Kirigami.Theme.defaultFont.family)
                    elide: Text.ElideRight
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    text: i18n("System maintenance for %1", AppConfig.osAboutData.displayName || "FE-XicoOS")
                    color: FeXico.structure(Kirigami.Theme.backgroundColor)
                    elide: Text.ElideRight
                }
            }
        }

        StatusPanel {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 40
            Layout.alignment: Qt.AlignHCenter

            stateId: page.systemState
            tone: Status.tone(page.systemState)
            iconName: page.stateIcon()
            title: page.stateTitle()
            explanation: page.stateExplanation()
            detail: page.stateDetail()
            busy: Status.isBusy(page.systemState)
            progress: AppState.progress
            primaryAction: mainAction
            secondaryActions: [checkAction, statusAction]
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 40
            Layout.alignment: Qt.AlignHCenter
            visible: !page.hasUpdateCommand
            type: Kirigami.MessageType.Error
            text: i18n("The FE-XicoOS update command is not configured. Make sure /etc/fe-xico-updater/config.ini is present.")
        }

        SectionLabel {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 40
            Layout.alignment: Qt.AlignHCenter
            text: i18n("This system")
        }

        Panel {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 40
            Layout.alignment: Qt.AlignHCenter

            FactRow {
                wide: page.wideLayout
                label: i18n("FE-XicoOS")
                value: [AppConfig.osRelease.FE_XICO_VERSION || "", AppConfig.osRelease.FE_XICO_VARIANT || ""]
                    .filter(part => part.length > 0).join(" · ")
            }
            FactRow {
                wide: page.wideLayout
                label: i18n("Fedora release")
                value: /fedora/.test((AppConfig.osRelease.ID || "") + " " + (AppConfig.osRelease.ID_LIKE || ""))
                    ? (AppConfig.osRelease.VERSION_ID || "") : ""
            }
            FactRow {
                wide: page.wideLayout
                label: i18n("Running image")
                value: page.booted ? page.imageRef(page.booted) : i18n("Not read yet")
                valueColor: page.booted ? Kirigami.Theme.textColor : FeXico.structure(Kirigami.Theme.backgroundColor)
            }
            FactRow {
                wide: page.wideLayout
                label: i18n("Version")
                value: page.versionAndDate(page.booted?.image)
            }
            FactRow {
                wide: page.wideLayout
                label: i18n("Available update")
                value: page.systemState === "update-available"
                    ? (page.versionAndDate(page.booted?.cachedUpdate) || i18n("Newer image found"))
                    : ""
                valueColor: FeXico.accent(Kirigami.Theme.backgroundColor)
            }
            FactRow {
                wide: page.wideLayout
                label: i18n("Prepared for restart")
                value: page.hostState.staged
                    ? (page.versionAndDate(page.hostState.staged.image) || i18n("New deployment"))
                        + (page.hostState.staged.downloadOnly ? " · " + i18n("locked, not applied by restart") : "")
                    : (page.hostState.rollbackQueued ? i18n("Previous deployment (rollback)") : "")
            }
            FactRow {
                wide: page.wideLayout
                label: i18n("Rollback")
                value: page.booted
                    ? (page.hostState.rollback
                        ? i18n("Available: %1", page.versionAndDate(page.hostState.rollback.image) || page.imageRef(page.hostState.rollback))
                        : i18n("No previous deployment"))
                    : ""
            }
            FactRow {
                wide: page.wideLayout
                label: i18n("Restart needed")
                value: page.booted ? (AppState.rebootRequired ? i18n("Yes") : i18n("No")) : ""
            }
            FactRow {
                wide: page.wideLayout
                label: i18n("Last check")
                value: page.formatTime(AppState.lastCheckedAt) || i18n("Not checked this session")
            }

            QQC2.ToolButton {
                Layout.topMargin: Kirigami.Units.smallSpacing
                visible: page.booted !== null
                text: page.showTechnical ? i18n("Hide technical details") : i18n("Show technical details")
                icon.name: page.showTechnical ? "go-up-symbolic" : "go-down-symbolic"
                onClicked: page.showTechnical = !page.showTechnical
            }

            FactRow {
                wide: page.wideLayout
                visible: page.showTechnical && value.length > 0
                label: i18n("Image digest")
                value: page.booted?.image?.imageDigest || ""
                monospace: true
            }
            FactRow {
                wide: page.wideLayout
                visible: page.showTechnical && value.length > 0
                label: i18n("Transport")
                value: page.booted?.image?.image?.transport || ""
                monospace: true
            }
            FactRow {
                wide: page.wideLayout
                visible: page.showTechnical && value.length > 0
                label: i18n("Recovery pin")
                value: page.booted ? (page.booted.pinned ? i18n("Pinned") : i18n("Not pinned")) : ""
            }
            FactRow {
                wide: page.wideLayout
                visible: page.showTechnical && value.length > 0
                label: i18n("Last result")
                value: AppState.resultMessage
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 40
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: Kirigami.Units.largeSpacing
            text: i18n("Updates change the operating system image only. Flatpak apps are updated separately in your app store.")
            wrapMode: Text.WordWrap
            color: FeXico.structure(Kirigami.Theme.backgroundColor)
        }
    }

    // ─────────────────────────────────────────────────────────
    // Technical details (real command output)
    // ─────────────────────────────────────────────────────────

    ConsoleDrawer {
        id: consoleDrawer
        model: SystemUpdateBackend.consoleModel
    }
}
