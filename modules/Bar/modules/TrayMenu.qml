import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.SystemTray
import qs.config

PopupWindow {
    id: root

    property SystemTrayItem trayItem: null
    property var menuStack: []
    readonly property var currentPage: pages.count > 0 ? pages.itemAt(pages.count - 1) : null

    visible: false
    color: "transparent"
    grabFocus: true
    implicitWidth: 300
    implicitHeight: Math.min(440, Math.max(80, (currentPage ? currentPage.contentHeight : 0) + 40 + (menuStack.length > 1 ? 36 : 0)))

    function open(item) {
        if (visible && trayItem === item) {
            close();
            return;
        }
        trayItem = item;
        menuStack = [item.menu];
        visible = true;
    }

    function close() {
        visible = false;
        menuStack = [];
        trayItem = null;
    }

    onVisibleChanged: {
        if (!visible) {
            menuStack = [];
            trayItem = null;
        } else {
            content.forceActiveFocus();
        }
    }
    Connections {
        target: root.trayItem
        function onHasMenuChanged() {
            if (!root.trayItem.hasMenu)
                root.close();
        }
    }
    onTrayItemChanged: {
        if (!trayItem && visible)
            close();
    }

    // A fourth-order superellipse gives continuous squircle corners, not circular arcs.
    Canvas {
        id: background
        anchors.fill: parent
        property color fillColor: Appearance.colors.primary_light
        property color strokeColor: Appearance.colors.tertiary
        onFillColorChanged: requestPaint()
        onStrokeColorChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const rx = width / 2 - 1;
            const ry = height / 2 - 1;
            ctx.beginPath();
            for (let i = 0; i <= 160; ++i) {
                const t = i * Math.PI * 2 / 160;
                const c = Math.cos(t);
                const s = Math.sin(t);
                const x = width / 2 + rx * Math.sign(c) * Math.sqrt(Math.abs(c));
                const y = height / 2 + ry * Math.sign(s) * Math.sqrt(Math.abs(s));
                if (i === 0) ctx.moveTo(x, y);
                else ctx.lineTo(x, y);
            }
            ctx.closePath();
            ctx.fillStyle = fillColor;
            ctx.fill();
            ctx.strokeStyle = strokeColor;
            ctx.lineWidth = 1;
            ctx.stroke();
        }
    }

    FocusScope {
        id: content
        anchors.fill: parent
        // Keep rows inside the curved superellipse boundary.
        anchors.margins: 20
        focus: true
        Keys.onEscapePressed: root.close()
        Keys.onLeftPressed: {
            if (root.menuStack.length > 1)
                root.menuStack = root.menuStack.slice(0, -1);
        }

        Button {
            id: back
            visible: root.menuStack.length > 1
            width: parent.width
            height: visible ? 36 : 0
            text: "‹ Back"
            onClicked: root.menuStack = root.menuStack.slice(0, -1)
            contentItem: Text {
                text: back.text
                color: Appearance.colors.secondary
                font.family: Appearance.font.family.mono
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                radius: 8
                color: back.hovered ? Appearance.colors.tertiary : "transparent"
            }
        }

        Repeater {
            id: pages
            model: root.menuStack

            delegate: ListView {
                id: page
                required property var modelData
                required property int index
                anchors.top: back.bottom
                anchors.bottom: parent.bottom
                width: parent.width
                visible: index === root.menuStack.length - 1
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: opener.children
                ScrollBar.vertical: ScrollBar {}

                // Keep ancestor openers alive while navigating their submenu handles.
                QsMenuOpener {
                    id: opener
                    menu: page.modelData
                }

                delegate: ItemDelegate {
                    id: entry
                    required property QsMenuEntry modelData
                    width: page.width
                    height: modelData.isSeparator ? 9 : 36
                    enabled: modelData.enabled && !modelData.isSeparator
                    hoverEnabled: true
                    onClicked: {
                        if (modelData.hasChildren)
                            root.menuStack = root.menuStack.concat([modelData]);
                        else {
                            modelData.triggered();
                            root.close();
                        }
                    }
                    background: Rectangle {
                        radius: 8
                        color: entry.hovered || entry.activeFocus ? Appearance.colors.tertiary : "transparent"
                        visible: !entry.modelData.isSeparator
                    }
                    contentItem: Item {
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width
                            height: 1
                            color: Appearance.colors.secondary
                            opacity: 0.25
                            visible: entry.modelData.isSeparator
                        }
                        Text {
                            id: check
                            width: 22
                            anchors.verticalCenter: parent.verticalCenter
                            text: entry.modelData.buttonType === QsMenuButtonType.RadioButton
                                ? (entry.modelData.checkState === Qt.Checked ? "●" : "○")
                                : (entry.modelData.checkState === Qt.Checked ? "✓" : entry.modelData.checkState === Qt.PartiallyChecked ? "−" : "")
                            color: Appearance.colors.secondary
                            visible: !entry.modelData.isSeparator
                        }
                        Image {
                            id: entryIcon
                            anchors.left: check.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: source.toString() ? 18 : 0
                            height: 18
                            source: entry.modelData.icon
                            sourceSize: Qt.size(18, 18)
                        }
                        Text {
                            anchors.left: entryIcon.right
                            anchors.leftMargin: entryIcon.width ? 6 : 0
                            anchors.right: arrow.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: entry.modelData.text.replace(/&&/g, "\u0000").replace(/&/g, "").replace(/\u0000/g, "&")
                            textFormat: Text.PlainText
                            font.family: Appearance.font.family.mono
                            font.pointSize: Appearance.font.size.sm
                            color: Appearance.colors.secondary
                            opacity: entry.enabled ? 1 : 0.4
                            elide: Text.ElideRight
                            visible: !entry.modelData.isSeparator
                        }
                        Text {
                            id: arrow
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            text: entry.modelData.hasChildren ? "›" : ""
                            color: Appearance.colors.secondary
                        }
                    }
                }
            }
        }
    }
}
