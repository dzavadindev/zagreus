import QtQuick

Item {
    id: root

    required property real position
    required property real trackWidth
    property color leftColor: "black"
    property color rightColor: "white"
    property real offset: 0
    property real kickDistance: 0

    x: Math.max(0, Math.min(trackWidth - width, position * trackWidth - width / 2 + offset))

    SequentialAnimation {
        id: kickAnimation

        NumberAnimation {
            target: root
            property: "offset"
            to: root.kickDistance
            duration: 70
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root
            property: "offset"
            to: 0
            duration: 150
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        id: leftHalf
        width: Math.floor(root.width / 2)
        height: root.height
        color: root.leftColor
    }

    Rectangle {
        x: leftHalf.width
        width: root.width - x
        height: root.height
        color: root.rightColor
    }

    function kick(distance: real) {
        kickDistance = Math.max(-16, Math.min(16, distance));
        kickAnimation.restart();
    }

    function reset() {
        kickAnimation.stop();
        offset = 0;
    }
}
