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

    readonly property color feXicoGreen: "#39FF14"
    readonly property color feXicoMagenta: "#FF00FF"
    readonly property color feXicoSilver: "#C0C0C0"

    Kirigami.Theme.highlightColor: feXicoMagenta

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
        active: !globalDrawer.drawerOpen
    }

    // ─────────────────────────────────────────────────────────
    // FE-Xico Updater preferences
    // ─────────────────────────────────────────────────────────

    FC.FormHeader {
        title: i18n("FE-Xico Updater")
    }

    FC.FormCard {
        FC.FormTextDelegate {
            text: i18n("Updater Preferences")

            description: i18n(
                "Configure how FE-Xico Updater behaves when checking, "
                + "applying, and finishing system updates."
            )

            icon.name: "io.github.royoshi.fexicoupdater"
        }
    }

    // ─────────────────────────────────────────────────────────
    // Interface
    // ─────────────────────────────────────────────────────────

    FC.FormHeader {
        title: i18n("Interface")
    }

    FC.FormCard {
        FC.FormSwitchDelegate {
            text: i18n("Reboot reminder")

            description: i18n(
                "Show a reminder when exiting FE-Xico Updater after "
                + "an update or rollback completes and a reboot is required."
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

        FC.FormSwitchDelegate {
            text: i18n("Launch in fullscreen")

            description: i18n(
                "Open FE-Xico Updater in fullscreen mode by default."
            )

            checked: UserSettings.preferFullscreen

            onToggled: {
                UserSettings.preferFullscreen = checked;

                checked = Qt.binding(
                    () => UserSettings.preferFullscreen
                );
            }
        }

        FormDelegateSeparatorFixed {}

        FC.FormSwitchDelegate {
            text: i18n("Open console by default")

            description: i18n(
                "Automatically open update console panels when "
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
    // System integration
    // ─────────────────────────────────────────────────────────

    FC.FormHeader {
        title: i18n("System Integration")
    }

    FC.FormCard {
        FC.FormTextDelegate {
            text: i18n("Read-only configuration")

            description: i18n(
                "These values are provided by FE-Xico and cannot "
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
                i18n("FE-Xico Release Notes Feed")
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