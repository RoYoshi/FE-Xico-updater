// SPDX-FileCopyrightText: 2026 RoYoshi
// SPDX-License-Identifier: GPL-2.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

import io.github.royoshi.fexicoupdater

// The dashboard's primary status: what is true right now, and the one thing to
// do next. While an update runs, the bar is indeterminate unless bootc itself
// reported a position and a total (AppState.progress, built in C++ by
// describeNativeProgress). The bar never decides or announces an outcome.
Panel {
    id: root

    property string stateId
    property string tone: "neutral"
    property string iconName: "dialog-information-symbolic"
    property string title
    property string explanation
    property string detail
    property bool busy: false
    // bootc's own progress for the running operation; {} when it reported none.
    property var progress: ({})
    readonly property bool progressKnown: busy && progress.known === true && progress.total > 0
    readonly property string progressText: [progress.headline || "", progress.detail || ""]
        .filter(part => part.length > 0).join(" — ")
    property QQC2.Action primaryAction: null
    property var secondaryActions: []

    padding: Kirigami.Units.gridUnit
    accentColor: FeXico.toneColor(tone, Kirigami.Theme)

    Accessible.role: Accessible.Grouping
    Accessible.name: title
    Accessible.description: explanation

    // A brief settle when the state changes; skipped when KDE animations are off.
    onStateIdChanged: {
        if (FeXico.motion(1) > 0)
            settle.restart();
    }

    ParallelAnimation {
        id: settle
        NumberAnimation {
            target: textBlock
            property: "opacity"
            from: 0.35
            to: 1
            duration: FeXico.motion(Kirigami.Units.longDuration)
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: indicator
            property: "scale"
            from: 0.75
            to: 1
            duration: FeXico.motion(Kirigami.Units.longDuration)
            easing.type: Easing.OutBack
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.largeSpacing

        Item {
            Layout.alignment: Qt.AlignTop
            implicitWidth: Kirigami.Units.iconSizes.medium
            implicitHeight: Kirigami.Units.iconSizes.medium

            QQC2.BusyIndicator {
                anchors.fill: parent
                running: root.busy
                visible: running
            }

            Kirigami.Icon {
                id: indicator
                anchors.fill: parent
                visible: !root.busy
                source: root.iconName
                color: root.accentColor
                isMask: true
            }
        }

        ColumnLayout {
            id: textBlock
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Heading {
                Layout.fillWidth: true
                level: 2
                text: root.title
                font.family: FeXico.headingFamily(Kirigami.Theme.defaultFont.family)
                wrapMode: Text.WordWrap
            }

            QQC2.Label {
                Layout.fillWidth: true
                text: root.explanation
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
            }

            QQC2.Label {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.detail
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                color: FeXico.structure(Kirigami.Theme.backgroundColor)
            }
        }
    }

    QQC2.Label {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        visible: root.busy && text.length > 0
        text: root.progressText
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
    }

    QQC2.ProgressBar {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        visible: root.busy
        indeterminate: !root.progressKnown
        from: 0
        to: root.progressKnown ? root.progress.total : 1
        value: root.progressKnown ? root.progress.value : 0
        Accessible.name: root.title
        Accessible.description: root.progressText
    }

    Flow {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        QQC2.Button {
            id: primaryButton
            visible: root.primaryAction !== null
            action: root.primaryAction
            highlighted: true
        }

        Repeater {
            model: root.secondaryActions

            QQC2.Button {
                required property var modelData
                action: modelData
                visible: modelData.visible
                flat: true
            }
        }
    }
}
