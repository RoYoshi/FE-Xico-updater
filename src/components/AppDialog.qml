// SPDX-FileCopyrightText: 2025-2026 Robert French <frenchrobertm@outlook.com>
// SPDX-License-Identifier: GPL-2.0-or-later

import QtQuick
import org.kde.kirigami as Kirigami

Kirigami.PromptDialog {
    id: root

    required property var activeDialogParent

    maximumWidth: Kirigami.Units.gridUnit * 20

    onVisibleChanged: {
        if (visible)
            activeDialogParent.activeDialog = root;
        else if (activeDialogParent.activeDialog === root)
            activeDialogParent.activeDialog = null;
    }
}
