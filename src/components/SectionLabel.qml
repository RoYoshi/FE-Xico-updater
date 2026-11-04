// SPDX-FileCopyrightText: 2026 RoYoshi
// SPDX-License-Identifier: GPL-2.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

import io.github.royoshi.fexicoupdater

// Section title followed by a fine structural line.
RowLayout {
    id: root

    property alias text: label.text

    Layout.fillWidth: true
    Layout.topMargin: Kirigami.Units.largeSpacing
    spacing: Kirigami.Units.largeSpacing

    QQC2.Label {
        id: label
        font.weight: Font.DemiBold
        color: FeXico.structure(Kirigami.Theme.backgroundColor)
        Accessible.role: Accessible.Heading
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        implicitHeight: FeXico.hairline
        color: FeXico.outline(Kirigami.Theme)
    }
}
