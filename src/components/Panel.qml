// SPDX-FileCopyrightText: 2026 RoYoshi
// SPDX-License-Identifier: GPL-2.0-or-later

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

import io.github.royoshi.fexicoupdater

// A quiet, outlined surface. An optional accent edge on the left carries the
// panel's tone; everything else stays neutral.
Rectangle {
    id: panel

    default property alias content: inner.data
    property color accentColor: "transparent"
    property real padding: Kirigami.Units.largeSpacing

    Layout.fillWidth: true
    implicitHeight: inner.implicitHeight + padding * 2

    radius: Kirigami.Units.cornerRadius
    color: FeXico.surface(Kirigami.Theme)
    border.width: FeXico.hairline
    border.color: FeXico.outline(Kirigami.Theme)

    Rectangle {
        visible: panel.accentColor.a > 0
        width: FeXico.accentEdge
        radius: width / 2
        color: panel.accentColor
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
            margins: FeXico.hairline
        }
        Behavior on color {
            ColorAnimation {
                duration: FeXico.motion(Kirigami.Units.longDuration)
            }
        }
    }

    ColumnLayout {
        id: inner
        spacing: Kirigami.Units.smallSpacing
        anchors {
            fill: parent
            margins: panel.padding
            leftMargin: panel.padding + (panel.accentColor.a > 0 ? FeXico.accentEdge : 0)
        }
    }
}
