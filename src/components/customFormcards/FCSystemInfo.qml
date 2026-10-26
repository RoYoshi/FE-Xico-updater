// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts
import org.kde.kirigamiaddons.formcard as FC
import io.github.royoshi.fexicoupdater

FormCardCollapsible {
    id: card
    Layout.fillWidth: true
    readonly property var state: AppState.hostStatus.status || ({})
    readonly property var booted: state.booted || ({})
    buttonText: expanded ? i18n("Display less information") : i18n("Display more information")

    function describe(entry) {
        if (!entry) return i18n("None");
        const image = entry.image || ({});
        return (image.image?.image || i18n("Unknown image")) + "\n" + (image.version || image.imageDigest || "");
    }

    topComponent: ColumnLayout {
        spacing: 0
        Layout.fillWidth: true
        FC.FormTextDelegate {
            text: AppConfig.osRelease.PRETTY_NAME || i18n("FE-XicoOS")
            description: AppConfig.osRelease.FE_XICO_VERSION || AppConfig.osRelease.VERSION_ID || ""
        }
        FormDelegateSeparatorFixed {}
        FC.FormTextDelegate {
            text: card.state.booted ? card.describe(card.booted) : i18n("Deployment state has not been verified. Select Refresh Deployment Status.")
            description: i18n("Booted Image")
            textItem.wrapMode: Text.WordWrap
        }
    }
    FC.FormTextDelegate {
        text: card.describe(card.state.staged)
        description: card.state.staged?.downloadOnly ? i18n("Download-only Deployment — Locked; Reboot Will Not Apply") : i18n("Staged Deployment")
        textItem.wrapMode: Text.WordWrap
    }
    FormDelegateSeparatorFixed {}
    FC.FormTextDelegate {
        text: card.describe(card.state.rollback)
        description: card.state.rollbackQueued ? i18n("Previous Deployment — Queued for Next Boot") : i18n("Previous Deployment")
        textItem.wrapMode: Text.WordWrap
    }
    FormDelegateSeparatorFixed {}
    FC.FormTextDelegate {
        text: card.state.booted ? (card.booted.pinned ? i18n("Pinned") : i18n("Not pinned")) : i18n("Unknown")
        description: i18n("Booted Deployment Recovery Pin")
    }
    FormDelegateSeparatorFixed {}
    FC.FormTextDelegate {
        text: i18n("This application does not select driver editions, switch images, or manage recovery pins.")
        textItem.wrapMode: Text.WordWrap
    }
}
