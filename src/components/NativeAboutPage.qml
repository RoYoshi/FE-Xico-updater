// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard
import org.kde.coreaddons as Core

// Keep FormCard styling without the packaged AboutPage's broken MessageDialog
// enum binding (observed with Fedora 44 Kirigami Addons 1.13.1 / Qt 6.11.2).
FormCard.FormCardPage {
    id: page
    property var aboutData: Core.AboutData
    property bool showLibraries: true

    function showLicense(name, text) {
        licenseDialog.title = name;
        licenseText.text = text;
        licenseDialog.open();
    }

    FormCard.FormCard {
        Layout.topMargin: Kirigami.Units.largeSpacing * 4
        FormCard.AbstractFormDelegate {
            background: null
            contentItem: RowLayout {
                Kirigami.Icon {
                    source: page.aboutData.programLogo || Kirigami.Settings.applicationWindowIcon
                    Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                    Layout.preferredHeight: width
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Kirigami.Heading {
                        Layout.fillWidth: true
                        text: page.aboutData.displayName + " " + page.aboutData.version
                        wrapMode: Text.WordWrap
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        text: page.aboutData.shortDescription
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
        FormCard.FormTextDelegate {
            visible: !!page.aboutData.copyrightStatement
            text: i18n("Copyright")
            description: page.aboutData.copyrightStatement
            descriptionItem.textFormat: Text.PlainText
        }
        FormCard.FormTextDelegate {
            visible: !!page.aboutData.otherText
            text: page.aboutData.otherText
            textItem.wrapMode: Text.WordWrap
        }
        FormCard.FormLinkDelegate {
            visible: !!page.aboutData.homepage
            text: i18n("Homepage")
            url: page.aboutData.homepage
        }
        FormCard.FormLinkDelegate {
            visible: !!page.aboutData.bugAddress
            text: i18n("Report a Bug")
            url: page.aboutData.bugAddress
        }
    }
    FormCard.FormHeader { title: i18n("Licenses"); visible: page.aboutData.licenses.length > 0 }
    FormCard.FormCard {
        visible: page.aboutData.licenses.length > 0
        Repeater {
            model: page.aboutData.licenses
            delegate: FormCard.FormButtonDelegate {
                required property var modelData
                text: modelData.name
                onClicked: page.showLicense(modelData.name, modelData.text)
            }
        }
    }
    Repeater {
        model: [ {label: i18n("Authors"), people: page.aboutData.authors || []},
                 {label: i18n("Credits"), people: page.aboutData.credits || []},
                 {label: i18n("Translators"), people: page.aboutData.translators || []} ]
        delegate: ColumnLayout {
            required property var modelData
            Layout.fillWidth: true
            visible: modelData.people.length > 0
            FormCard.FormHeader { title: modelData.label }
            FormCard.FormCard {
                Layout.fillWidth: true
                Repeater {
                    model: modelData.people
                    delegate: FormCard.FormTextDelegate {
                        required property var modelData
                        text: modelData.name
                        description: modelData.task || ""
                        descriptionItem.textFormat: Text.PlainText
                        trailing: Row {
                            QQC2.ToolButton {
                                visible: !!modelData.webAddress
                                text: i18n("Website")
                                onClicked: Qt.openUrlExternally(modelData.webAddress)
                            }
                            QQC2.ToolButton {
                                visible: !!modelData.emailAddress
                                text: i18n("Email")
                                onClicked: Qt.openUrlExternally("mailto:" + modelData.emailAddress)
                            }
                        }
                    }
                }
            }
        }
    }
    FormCard.FormHeader { title: i18n("Libraries in use"); visible: page.showLibraries }
    FormCard.FormCard {
        visible: page.showLibraries
        Repeater {
            model: page.showLibraries ? FormCard.AboutComponent.components : null
            delegate: FormCard.FormButtonDelegate {
                required property var modelData
                text: modelData.name + " " + modelData.version
                description: modelData.description
                onClicked: page.showLicense(modelData.licenses.name, modelData.licenses.text)
            }
        }
    }
    data: QQC2.Dialog {
        id: licenseDialog
        parent: QQC2.Overlay.overlay
        modal: true
        onVisibleChanged: {
            if (visible) applicationWindow().activeDialog = licenseDialog;
            else releaseInput();
        }
        function releaseInput() {
            const owner = applicationWindow();
            Qt.callLater(function() {
                if (!licenseDialog.visible && owner.activeDialog === licenseDialog) owner.activeDialog = null;
            });
        }
        function handleInput(buttonId, down) {
            if (down && (buttonId === 0 || buttonId === 1)) close();
        }
        standardButtons: QQC2.Dialog.Close
        width: Math.min(parent ? parent.width - 32 : 600, 700)
        height: Math.min(parent ? parent.height - 32 : 400, 600)
        anchors.centerIn: parent
        contentItem: QQC2.ScrollView {
            clip: true
            QQC2.TextArea {
                id: licenseText
                readOnly: true
                wrapMode: Text.WordWrap
                textFormat: TextEdit.PlainText
                selectByMouse: true
            }
        }
    }
}
