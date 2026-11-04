// SPDX-FileCopyrightText: 2026 RoYoshi
// SPDX-License-Identifier: GPL-2.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

import io.github.royoshi.fexicoupdater

// One labelled fact. Hidden when the backend gave no value, so nothing is
// ever filled in by guesswork. Label and value stack on narrow windows.
GridLayout {
    id: root

    property string label
    property string value
    property bool monospace: false
    property color valueColor: Kirigami.Theme.textColor
    // Two columns unless the container is narrow; set by the page, so the
    // row never sizes itself from its own width.
    property bool wide: true

    visible: value.length > 0
    Layout.fillWidth: true
    columns: wide ? 2 : 1
    columnSpacing: Kirigami.Units.largeSpacing
    rowSpacing: 0

    QQC2.Label {
        text: root.label
        color: FeXico.structure(Kirigami.Theme.backgroundColor)
        Layout.preferredWidth: root.columns === 2 ? Kirigami.Units.gridUnit * 9 : -1
        Layout.alignment: Qt.AlignTop
        wrapMode: Text.WordWrap
    }

    QQC2.Label {
        text: root.value
        color: root.valueColor
        font.family: root.monospace ? "monospace" : Kirigami.Theme.defaultFont.family
        textFormat: Text.PlainText
        wrapMode: root.monospace ? Text.WrapAnywhere : Text.WordWrap
        Layout.fillWidth: true
        Layout.bottomMargin: root.columns === 1 ? Kirigami.Units.smallSpacing : 0
    }

    Accessible.role: Accessible.StaticText
    Accessible.name: label + ": " + value
}
