// SPDX-FileCopyrightText: 2026 Robert French <frenchrobertm@outlook.com>
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

    readonly property var hourLabels: [
        "00:00", "01:00", "02:00", "03:00", "04:00", "05:00",
        "06:00", "07:00", "08:00", "09:00", "10:00", "11:00",
        "12:00", "13:00", "14:00", "15:00", "16:00", "17:00",
        "18:00", "19:00", "20:00", "21:00", "22:00", "23:00"
    ]

    Kirigami.Theme.highlightColor: applicationWindow().darkScheme ? FeXico.magenta : FeXico.magentaOnLight

    title:
        GP.Labels.east
        + GP.Labels.spacer_large
        + i18n("Settings")

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

    GP.PageNavigation {
        targetScrollbar: page.scrollbar
        active: !globalDrawer.drawerOpen && !applicationWindow().activeDialog
    }

    // ─────────────────────────────────────────────────────────
    // Update preferences
    // ─────────────────────────────────────────────────────────

    FC.FormHeader {
        title: i18n("Updates")
    }

    FC.FormCard {
        FC.FormSwitchDelegate {
            text: i18n("Read system status when the updater opens")

            description: i18n(
                "Reads your deployments with bootc at startup so the dashboard "
                + "can show the real state. Read-only: nothing is downloaded or "
                + "changed, and no update check or update is started."
            )

            checked: UserSettings.readStatusOnStart

            onToggled: {
                UserSettings.readStatusOnStart = checked;
                checked = Qt.binding(() => UserSettings.readStatusOnStart);
            }
        }
    }


    // System-level bootc timer control (not a user-local preference).
    FC.FormHeader {
        title: i18n("Automatic OS Updates")
    }

    FC.FormCard {
        FC.FormCheckDelegate {
            id: autoUpdateCheckbox
            text: i18n("Enable automatic OS updates")
            description: i18n("The FE-XicoOS timer checks and stages OS images outside active hours. It NEVER automatically reboots your PC. Manual updates remain available.")
            enabled: AutoUpdateSettings.available && !AutoUpdateSettings.busy
            checked: AutoUpdateSettings.enabled
            onClicked: {
                const requested = checked;
                // Rebind immediately: reflect actual timer state until the
                // privileged command succeeds and a new status is read.
                checked = Qt.binding(() => AutoUpdateSettings.enabled);
                confirmation.requested = requested;
                confirmation.open();
            }
        }

        FC.FormTextDelegate {
            text: AutoUpdateSettings.statusText
            description: AutoUpdateSettings.errorText.length > 0
                ? AutoUpdateSettings.errorText
                : i18n("Changes require an administrator password. The updater stages new OS images without rebooting.")
        }

        FC.FormTextDelegate {
            text: i18n("Active hours (local time)")
            description: i18n("Scheduled checks and downloads pause during this window. Start is inclusive; end is exclusive. Equal hours protect all day. Manual updates are unaffected.")
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.bottomMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            Label {
                text: i18n("From")
                Layout.alignment: Qt.AlignVCenter
            }
            ComboBox {
                id: activeStartPicker
                Layout.fillWidth: true
                model: page.hourLabels
                currentIndex: AutoUpdateSettings.startHour
                enabled: AutoUpdateSettings.available && !AutoUpdateSettings.busy
                onActivated: {
                    const selectedHour = currentIndex;
                    currentIndex = Qt.binding(() => AutoUpdateSettings.startHour);
                    AutoUpdateSettings.setActiveHours(selectedHour, AutoUpdateSettings.endHour);
                }
            }
            Label {
                text: i18n("To")
                Layout.alignment: Qt.AlignVCenter
            }
            ComboBox {
                id: activeEndPicker
                Layout.fillWidth: true
                model: page.hourLabels
                currentIndex: AutoUpdateSettings.endHour
                enabled: AutoUpdateSettings.available && !AutoUpdateSettings.busy
                onActivated: {
                    const selectedHour = currentIndex;
                    currentIndex = Qt.binding(() => AutoUpdateSettings.endHour);
                    AutoUpdateSettings.setActiveHours(AutoUpdateSettings.startHour, selectedHour);
                }
            }
        }

        FC.FormButtonDelegate {
            text: i18n("Refresh automatic update status")
            icon.name: "view-refresh"
            enabled: !AutoUpdateSettings.busy
            onClicked: AutoUpdateSettings.refresh()
        }
    }

    Dialog {
        id: confirmation
        property bool requested: false
        title: requested ? i18n("Enable automatic OS updates?") : i18n("Disable automatic OS updates?")
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        anchors.centerIn: Overlay.overlay
        width: Math.min(page.width - Kirigami.Units.gridUnit * 2, Kirigami.Units.gridUnit * 25)
        contentItem: Label {
            wrapMode: Text.WordWrap
            text: confirmation.requested
                ? i18n("FE-XicoOS will automatically check and stage updates OUTSIDE your active hours. Your PC will NEVER restart without your action. Authenticate to continue?")
                : i18n("Stop future scheduled checks and staging? An already running update is not cancelled. Administrator authentication may be required.")
        }
        onAccepted: AutoUpdateSettings.setAutoUpdatesEnabled(requested)
    }

    Component.onCompleted: {
        if (!QmlSmokeTest) AutoUpdateSettings.refresh();
    }

    // ─────────────────────────────────────────────────────────
    // Notifications
    // ─────────────────────────────────────────────────────────

    FC.FormHeader {
        title: i18n("Notifications")
    }

    FC.FormCard {
        FC.FormSwitchDelegate {
            text: i18n("Restart reminder")

            description: i18n(
                "Remind you when closing FE-Xico Updater while an update "
                + "or rollback is waiting for a restart."
            )

            checked: UserSettings.showRebootReminder

            onToggled: {
                UserSettings.showRebootReminder = checked;

                // Assigning to checked drops the binding, so restore it.
                checked = Qt.binding(
                    () => UserSettings.showRebootReminder
                );
            }
        }

        FormDelegateSeparatorFixed {}

        FC.FormTextDelegate {
            text: i18n("Desktop notifications")
            description: i18n(
                "When an update check finishes while FE-Xico Updater is not the "
                + "active window, the result is shown as a desktop notification."
            )
            icon.name: "preferences-desktop-notification-symbolic"
        }
    }

    // ─────────────────────────────────────────────────────────
    // Appearance
    // ─────────────────────────────────────────────────────────

    FC.FormHeader {
        title: i18n("Appearance")
    }

    FC.FormCard {
        FC.FormSwitchDelegate {
            text: i18n("Launch in fullscreen")

            description: i18n(
                "Open FE-Xico Updater in fullscreen by default. Press F11 to "
                + "switch at any time."
            )

            checked: UserSettings.preferFullscreen

            onToggled: {
                UserSettings.preferFullscreen = checked;

                checked = Qt.binding(
                    () => UserSettings.preferFullscreen
                );
            }
        }

    }

    // ─────────────────────────────────────────────────────────
    // Controller and navigation (information only: hints adapt by themselves)
    // ─────────────────────────────────────────────────────────

    FC.FormHeader {
        title: i18n("Controller & Navigation")
    }

    FC.FormCard {
        FC.FormTextDelegate {
            text: i18n("Controller button hints appear automatically")
            description: i18n(
                "A runs the main action, B or Start opens the menu, Y shows "
                + "Technical Details, and X quits from the menu. The keyboard works "
                + "too: Enter, Escape, F12 and the arrow keys."
            )
            icon.name: "input-gamepad-symbolic"
            textItem.wrapMode: Text.Wrap
        }
    }

    // ─────────────────────────────────────────────────────────
    // Advanced
    // ─────────────────────────────────────────────────────────

    FC.FormHeader {
        title: i18n("Advanced")
    }

    FC.FormCard {
        FC.FormSwitchDelegate {
            text: i18n("Open Technical Details by default")

            description: i18n(
                "Show the real command output panel when "
                + "FE-Xico Updater starts."
            )

            checked: UserSettings.preferConsole

            onToggled: {
                UserSettings.preferConsole = checked;

                checked = Qt.binding(
                    () => UserSettings.preferConsole
                );
            }
        }
    }

    FC.FormCard {
        Layout.topMargin: Kirigami.Units.mediumSpacing

        FC.FormButtonDelegate {
            text: i18n("Restore Default Settings")
            icon.name: "edit-undo-symbolic"

            enabled: !UserSettings.isDefault

            onClicked:
                UserSettings.restoreDefaults()
        }
    }

    // ─────────────────────────────────────────────────────────
    // System integration (read-only, provided by FE-XicoOS)
    // ─────────────────────────────────────────────────────────

    FC.FormHeader {
        title: i18n("System Integration")
    }

    FC.FormCard {
        FC.FormTextDelegate {
            text: i18n("Read-only configuration")

            description: i18n(
                "These values are provided by FE-XicoOS and cannot "
                + "be changed from the updater."
            )

            icon.name: "document-properties-symbolic"
        }

        FormDelegateSeparatorFixed {}

        FC.FormTextDelegate {
            text:
                AppConfig.ini.Commands?.systemUpdateCommand
                || i18n("Not configured")

            description: i18n("System Update Command")
        }

        FormDelegateSeparatorFixed {}

        FC.FormTextDelegate {
            text:
                AppConfig.ini.Commands?.systemRollbackCommand
                || i18n("Not configured")

            description: i18n("System Rollback Command")
        }

        FormDelegateSeparatorFixed {}

        FC.FormTextDelegate {
            text: {
                const value =
                    AppConfig.ini.Commands?.allowEarlyExit;

                if (value === "true")
                    return i18n("Allowed");

                if (value === "false")
                    return i18n("Not allowed");

                return i18n("Not configured");
            }

            description:
                i18n("Allow update commands to be exited early")
        }

        FormDelegateSeparatorFixed {}

        FC.FormTextDelegate {
            text:
                AppConfig.ini.General?.rssFeed
                || i18n("Not configured")

            description:
                i18n("FE-XicoOS Release Notes Feed")
        }
    }

    // ─────────────────────────────────────────────────────────
    // Configuration information
    // ─────────────────────────────────────────────────────────

    FC.FormHeader {
        title: i18n("Configuration")
    }

    FC.FormCard {
        FC.FormTextDelegate {
            text: "/etc/fe-xico-updater/config.ini"
            description: i18n("System Configuration")
            icon.name: "document-edit-symbolic"
        }

        FormDelegateSeparatorFixed {}

        FC.FormTextDelegate {
            text: "~/.config/fe-xico-updaterrc"
            description: i18n("User Preferences")
            icon.name: "user-properties-symbolic"
        }
    }
}