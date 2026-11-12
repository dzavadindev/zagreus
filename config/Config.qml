pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    readonly property int trayMaxVisibleIcons: 5
    readonly property int trayIconSize: 20

    readonly property real worspacesCount: 5
    readonly property string colorThemeFile: "/home/dan/.cache/color-themes/quickshell.json"
}
