import QtQuick

Item {
    id: root

    required property real progress

    property color baseColor: "#000000"
    property color fillColor: "#ffffff"
    property real radius: 0

    readonly property real clampedProgress: Math.max(0, Math.min(1, progress))

    implicitHeight: 8

    Rectangle {
        id: baseTrack
        anchors.fill: parent

        radius: root.radius
        color: root.baseColor
    }

    Item {
        width: root.width * root.clampedProgress
        height: root.height
        clip: true

        // Reveal a full-size rounded track so the moving edge stays straight.
        Rectangle {
            width: root.width
            height: root.height
            radius: root.radius
            color: root.fillColor
        }
    }
}
