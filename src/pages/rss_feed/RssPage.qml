// SPDX-FileCopyrightText: 2026 Robert French <frenchrobertm@outlook.com>
// SPDX-License-Identifier: GPL-2.0-or-later

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FC

import io.github.royoshi.fexicoupdater
import io.github.rfrench3.controllable as GP

import QtQml.XmlListModel

FC.FormCardPage {
    id: page

    topPadding:
        Kirigami.Units.largeSpacing * 4

    title:
        GP.Labels.east
        + GP.Labels.spacer_large
        + i18n("Release Notes")

    function grabScrollbar(item) {
        if (item.contentItem?.ScrollBar?.vertical)
            return item.contentItem.ScrollBar.vertical;

        if (item.parent)
            return grabScrollbar(item.parent);

        console.warn(
            "Parent scrollbar not found, controller scrolling will not function!"
        );
    }

    GP.PageNavigation {
        targetScrollbar: page.grabScrollbar(page)
        active: !globalDrawer.drawerOpen
    }

    FC.FormCard {
        visible:
            modelLoader.item?.status
            !== XmlListModel.Ready

        FC.FormPlaceholderMessageDelegate {
            id: nullMsg

            text:
                i18nc(
                    "@info:placeholder",
                    "No FE-Xico release notes are available."
                )

            visible:
                modelLoader.item?.status
                === XmlListModel.Null
        }

        FC.FormPlaceholderMessageDelegate {
            id: loadingMsg

            text:
                i18nc(
                    "@info:placeholder",
                    "Loading FE-Xico release notes"
                )
                + dots

            visible:
                modelLoader.item?.status
                === XmlListModel.Loading

            property string dots: "."
            property int dotIndex: 0

            Timer {
                interval: 500
                running: loadingMsg.visible
                repeat: true

                onTriggered: {
                    loadingMsg.dotIndex =
                        (loadingMsg.dotIndex % 3) + 1;

                    loadingMsg.dots =
                        ".".repeat(loadingMsg.dotIndex);
                }
            }
        }

        FC.FormPlaceholderMessageDelegate {
            id: errorMsg

            text:
                i18nc(
                    "@info:placeholder",
                    "Unable to load FE-Xico release notes: "
                )
                + (modelLoader.item?.errorString() || "")

            visible:
                modelLoader.item?.status
                === XmlListModel.Error
        }

        FC.FormPlaceholderMessageDelegate {
            text:
                i18nc(
                    "@info:placeholder",
                    "An error occurred while loading FE-Xico release notes."
                )

            visible:
                !(
                    nullMsg.visible
                    || loadingMsg.visible
                    || errorMsg.visible
                )
        }

        Item {
            Layout.fillHeight: true
        }
    }

    Repeater {
        id: repeater

        enabled:
            modelLoader.item?.status
            === XmlListModel.Ready

        model: modelLoader.item

        delegate: ColumnLayout {
            id: delegate

            required property int index
            required property string updated
            required property string link
            required property string title
            required property string content

            Layout.fillWidth: true

            Item {
                implicitHeight:
                    Kirigami.Units.mediumSpacing

                visible:
                    delegate.index > 0
            }

            FCRssDelegate {
                updated: delegate.updated
                link: delegate.link
                title: delegate.title
                content: delegate.content
            }
        }
    }

    Loader {
        id: modelLoader
        source: "RssModel.qml"
    }
}