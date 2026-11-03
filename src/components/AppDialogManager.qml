pragma Singleton
import QtQuick

// Only show the earliest opened dialog, the rest are in a queue
QtObject {
    id: root

    property var dialogs: []

    readonly property var activeDialog: dialogs.length > 0 ? dialogs[0] : null

    function show(dialog) {
        if (!dialog || dialogs.indexOf(dialog) !== -1)
            return;
        dialogs = dialogs.concat([dialog]);
        if (dialogs.length === 1)
            dialog.open();
    }

    function remove(dialog) {
        const idx = dialogs.indexOf(dialog);
        if (idx === -1)
            return;
        dialogs = dialogs.filter(d => d !== dialog);
        // Only advance the queue if the dialog that went away was the visible one
        if (idx === 0 && dialogs.length > 0)
            dialogs[0].open();
    }
}
