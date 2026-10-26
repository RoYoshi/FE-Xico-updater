// SPDX-FileCopyrightText: 2025-2026 Robert French <frenchrobertm@outlook.com>
// SPDX-License-Identifier: GPL-2.0-or-later

import QtQuick
import org.kde.kirigami as Kirigami

Kirigami.PromptDialog {
    id: root

    required property var activeDialogParent

    maximumWidth: Kirigami.Units.gridUnit * 20

    // Gamepad listeners share one signal. Keep ownership through this dispatch
    // so the A press that closes a dialog cannot reach a background control.
    function releaseInput() {
        Qt.callLater(function() {
            if (!root.visible && activeDialogParent.activeDialog === root)
                activeDialogParent.activeDialog = null;
        });
    }

    onVisibleChanged: {
        if (visible)
            activeDialogParent.activeDialog = root;
        else
            releaseInput();
    }
}
