import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

import qs.config
import qs.components

Item {
    id: root

    property bool expanded: false
    property real reveal: expanded ? expandedWidth : 0
    readonly property int slotWidth: Config.trayIconSize + Appearance.padding.sm * 2
    readonly property real expandedWidth: {
        const currentItems = SystemTray.items.values.length
        if (currentItems < Config.trayMaxVisibleIcons)
            return currentItems * slotWidth
        return Math.max(1, Config.trayMaxVisibleIcons) * slotWidth
    }
    readonly property real ribbonWidth: 20

    implicitWidth: ribbonWidth + Math.max(0, reveal)
    implicitHeight: Config.trayIconSize + Appearance.padding.sm

    onExpandedChanged: {
        if (!expanded)
            menu.close();
    }

    Behavior on reveal {
        SmoothedAnimation {
            velocity: 600
            reversingMode: SmoothedAnimation.Eased
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Appearance.colors.primary_light
    }

    // The right edge stays fixed in the bar row; dragging the handle left reveals icons.
    MouseArea {
        id: handle

        property real pressX: 0
        property real initialReveal: 0
        property bool moved: false

        width: root.ribbonWidth
        height: parent.height
        hoverEnabled: true
        cursorShape: Qt.SizeHorCursor

        onPressed: mouse => {
            pressX = mapToGlobal(mouse.x, mouse.y).x;
            initialReveal = root.reveal;
            moved = false;
            menu.close();
        }

        onPositionChanged: mouse => {
            if (!pressed)
                return;
            const delta = pressX - mapToGlobal(mouse.x, mouse.y).x;
            if (Math.abs(delta) > 4)
                moved = true;
            if (moved)
                root.reveal = Math.max(0, Math.min(root.expandedWidth, initialReveal + delta));
        }

        onReleased: mouse => {
            const delta = pressX - mapToGlobal(mouse.x, mouse.y).x;
            if (moved || Math.abs(delta) > 4) {
                if (delta !== 0)
                    root.expanded = delta > 0;
            } else {
                root.expanded = !root.expanded;
            }
            root.reveal = Qt.binding(() => root.expanded ? root.expandedWidth : 0);
        }

        onCanceled: {
            root.reveal = Qt.binding(() => root.expanded ? root.expandedWidth : 0)
        }

        MaterialIcon {
            anchors.centerIn: parent
            name: root.expanded ? "chevron_right" : "chevron_left"
            size: 18
            color: handle.containsMouse ? Appearance.colors.tertiary_contrast : Appearance.colors.secondary
        }
    }

    Item {
        id: viewport
        anchors.left: handle.right
        anchors.right: parent.right
        height: parent.height
        clip: true

        ListView {
            id: icons
            anchors.fill: parent
            orientation: ListView.Horizontal
            boundsBehavior: Flickable.StopAtBounds
            model: SystemTray.items
            clip: true

            function clampScroll() {
                contentX = Math.max(originX, Math.min(contentX, originX + Math.max(0, contentWidth - width)));
            }
            onWidthChanged: clampScroll()
            onContentWidthChanged: clampScroll()

            delegate: MouseArea {
                id: iconDelegate
                required property SystemTrayItem modelData
                width: root.slotWidth
                height: icons.height
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (modelData.hasMenu)
                        menu.open(modelData);
                    else
                        modelData.activate();
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: Appearance.padding.xs
                    color: Appearance.colors.tertiary
                    opacity: iconDelegate.containsMouse ? 0.6 : 0
                }
                Image {
                    anchors.centerIn: parent
                    width: Config.trayIconSize
                    height: width
                    source: iconDelegate.modelData.icon
                    sourceSize: Qt.size(width, height)
                    fillMode: Image.PreserveAspectFit
                }
            }
        }

        WheelHandler {
            onWheel: event => {
                const pixels = event.pixelDelta.x || event.pixelDelta.y;
                const angle = event.angleDelta.x || event.angleDelta.y;
                icons.contentX -= pixels || angle / 120 * root.slotWidth;
                icons.clampScroll();
                event.accepted = true;
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 2
            height: parent.height - Appearance.padding.xs * 2
            color: Appearance.colors.tertiary
            visible: icons.contentX > icons.originX + 1
        }
        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 2
            height: parent.height - Appearance.padding.xs * 2
            color: Appearance.colors.secondary
            visible: icons.contentX + icons.width < icons.originX + icons.contentWidth - 1
        }
    }

    TrayMenu {
        id: menu
        anchor.item: root
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.adjustment: PopupAdjustment.SlideX
    }
}
