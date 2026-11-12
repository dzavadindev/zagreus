import QtQuick
import QtTest
import "../components"
import "../modules/Overlay/panels/AudioMixer"

Rectangle {
    id: root

    width: 320
    height: 160
    color: "red"
    property int renderedFrames: 0

    Connections {
        target: root.Window.window
        function onFrameSwapped() {
            root.renderedFrames++;
        }
    }

    MaskedProgressTrack {
        id: track

        width: 300
        height: 30
        progress: 0.25
        radius: 15
        baseColor: "black"
        fillColor: "white"
    }

    Item {
        id: interactiveTrack

        y: 40

        width: 300
        height: 30
        property real displayedPosition: 0.25
        property real targetPosition: 0.25
        property bool animate: false
        property bool pointerMoving: false
        property bool acquiringDrag: false
        property real pressX: 0
        property real clickMovement: 0

        onTargetPositionChanged: displayedPosition = targetPosition
        onDisplayedPositionChanged: {
            if (acquiringDrag && pointerMoving && Math.abs(displayedPosition - targetPosition) * width <= 3) {
                acquiringDrag = false;
                displayedPosition = targetPosition;
            }
        }

        Behavior on displayedPosition {
            enabled: interactiveTrack.animate && (!interactiveTrack.pointerMoving || interactiveTrack.acquiringDrag)
            SmoothedAnimation {
                duration: 60
                velocity: -1
                maximumEasingTime: 30
                reversingMode: SmoothedAnimation.Immediate
            }
        }

        Timer {
            id: clickKick
            interval: 45
            onTriggered: testHandle.kick(interactiveTrack.clickMovement * interactiveTrack.width * 0.25)
        }

        MaskedProgressTrack {
            anchors.fill: parent
            progress: interactiveTrack.displayedPosition
            radius: 15
            baseColor: "black"
            fillColor: "white"
        }

        MouseArea {
            id: pointer
            anchors.fill: parent
            preventStealing: true
            onPressed: mouse => {
                interactiveTrack.pointerMoving = false;
                interactiveTrack.pressX = mouse.x;
                const previousPosition = interactiveTrack.displayedPosition;
                interactiveTrack.acquiringDrag = Math.abs(previousPosition - mouse.x / width) * width > 3;
                clickKick.stop();
                testHandle.reset();
                interactiveTrack.targetPosition = mouse.x / width;
                interactiveTrack.clickMovement = interactiveTrack.targetPosition - previousPosition;
                if (Math.abs(interactiveTrack.clickMovement * width) > 3)
                    clickKick.start();
            }
            onPositionChanged: mouse => {
                if (!pressed)
                    return;
                if (!interactiveTrack.pointerMoving && Math.abs(mouse.x - interactiveTrack.pressX) >= 3) {
                    interactiveTrack.pointerMoving = true;
                    clickKick.stop();
                    testHandle.reset();
                }
                interactiveTrack.targetPosition = mouse.x / width;
            }
            onReleased: {
                interactiveTrack.acquiringDrag = false;
                interactiveTrack.pointerMoving = false;
                interactiveTrack.displayedPosition = interactiveTrack.targetPosition;
            }
        }
    }

    Flickable {
        id: scrollHost

        y: 90
        width: 300
        height: 30
        contentWidth: 300
        contentHeight: 200
        clip: true

        Item {
            id: capturedTrack

            width: 300
            height: 30
            property real draggedPosition: 0

            MouseArea {
                id: capturedPointer
                anchors.fill: parent
                preventStealing: true
                onPressed: mouse => capturedTrack.draggedPosition = mouse.x / width
                onPositionChanged: mouse => {
                    if (pressed)
                        capturedTrack.draggedPosition = mouse.x / width;
                }
            }
        }
    }

    Item {
        y: 130
        width: 300
        height: 25

        VolumeHandle {
            id: testHandle
            width: 35
            height: 25
            position: interactiveTrack.displayedPosition
            trackWidth: 300
            leftColor: "#111111"
            rightColor: "#eeeeee"
        }
    }

    TestCase {
        name: "MaskedProgressTrack"
        when: windowShown

        function init() {
            track.progress = 0.25;
            interactiveTrack.animate = false;
            interactiveTrack.acquiringDrag = false;
            interactiveTrack.pointerMoving = false;
            interactiveTrack.targetPosition = 0.25;
            interactiveTrack.displayedPosition = 0.25;
            clickKick.stop();
            scrollHost.contentY = 0;
            testHandle.reset();
            interactiveTrack.animate = true;
            wait(100);
        }

        function cleanup() {
            if (pointer.pressed)
                mouseRelease(interactiveTrack, 75, 15);
            if (capturedPointer.pressed)
                mouseRelease(capturedTrack, 75, 15);
        }

        function test_progressUpdatesWithoutAnotherInteraction() {
            compare(grabImage(track).red(150, 15), 0);
            track.progress = 0.75;
            wait(100);
            compare(grabImage(track).red(150, 15), 255);
            track.progress = 0.1;
            wait(100);
            compare(grabImage(track).red(150, 15), 0);
        }

        function test_pointerEdgeMovesBeforeRelease() {
            interactiveTrack.animate = false;
            mousePress(interactiveTrack, 75, 15);
            mouseMove(interactiveTrack, 225, 15, 0, Qt.LeftButton);
            compare(interactiveTrack.displayedPosition, 0.75);
            let image = grabImage(interactiveTrack);
            compare(image.red(220, 15), 255);
            compare(image.red(230, 15), 0);

            mouseMove(interactiveTrack, 105, 15, 0, Qt.LeftButton);
            compare(interactiveTrack.displayedPosition, 0.35);
            image = grabImage(interactiveTrack);
            compare(image.red(100, 15), 255);
            compare(image.red(110, 15), 0);
        }

        function test_dragKeepsGrabOutsideTrack() {
            mousePress(capturedTrack, 75, 15);
            mouseMove(capturedTrack, 225, 55, 0, Qt.LeftButton);
            verify(capturedPointer.pressed, "The track should keep its mouse grab outside its bounds");
            compare(scrollHost.contentY, 0);
            compare(capturedTrack.draggedPosition, 0.75);
            mouseRelease(capturedTrack, 225, 55);
        }

        function test_clickAnimates() {
            mousePress(interactiveTrack, 225, 15);
            verify(interactiveTrack.displayedPosition < 0.75, "The fill must not jump to a clicked position");
            mouseRelease(interactiveTrack, 225, 15);
            wait(120);
            fuzzyCompare(interactiveTrack.displayedPosition, 0.75, 0.01, "The click should finish quickly");
        }

        function test_clickBouncesHandleInBothDirections() {
            mousePress(interactiveTrack, 225, 15);
            wait(100);
            verify(testHandle.offset > 0, "Clicking right should kick the handle right");
            mouseRelease(interactiveTrack, 225, 15);
            wait(200);
            fuzzyCompare(testHandle.offset, 0, 0.5);

            interactiveTrack.animate = false;
            interactiveTrack.targetPosition = 0.75;
            interactiveTrack.displayedPosition = 0.75;
            interactiveTrack.animate = true;
            mousePress(interactiveTrack, 75, 15);
            wait(100);
            verify(testHandle.offset < 0, "Clicking left should kick the handle left");
            mouseRelease(interactiveTrack, 75, 15);
        }

        function test_clickAtCurrentValueDoesNotBounce() {
            mousePress(interactiveTrack, 75, 15);
            mouseRelease(interactiveTrack, 75, 15);
            wait(100);
            compare(testHandle.offset, 0);
        }

        function test_dragCancelsClickBounce() {
            mousePress(interactiveTrack, 225, 15);
            mouseMove(interactiveTrack, 270, 15, 0, Qt.LeftButton);
            wait(100);
            compare(testHandle.offset, 0);
            mouseRelease(interactiveTrack, 270, 15);
        }

        function test_handleIsTwoTone() {
            const image = grabImage(root);
            const x = Math.round(testHandle.x);
            compare(image.red(x + 1, 131), 17);
            compare(image.red(x + 14, 142), 17);
            const seam = image.red(x + 16, 142);
            verify(seam === 17 || seam === 238, "The center seam should have no third color");
            compare(image.red(x + 20, 142), 238);
            compare(image.red(x + 33, 131), 238);
        }

        function test_handleKickReversesDirection() {
            testHandle.kick(12);
            wait(55);
            verify(testHandle.offset > 5, "A rightward kick should move the handle right");
            wait(200);
            fuzzyCompare(testHandle.offset, 0, 0.5);

            testHandle.kick(-12);
            wait(55);
            verify(testHandle.offset < -5, "A leftward kick should move the handle left");
            wait(200);
            fuzzyCompare(testHandle.offset, 0, 0.5);
        }

        function test_clampsAnimationOvershoot() {
            track.progress = -0.1;
            wait(50);
            compare(grabImage(track).red(150, 15), 0);
            track.progress = 1.1;
            wait(50);
            compare(grabImage(track).red(290, 15), 255);
        }

        function test_dragStartingFarAwayDoesNotJump() {
            mousePress(interactiveTrack, 225, 15);
            verify(interactiveTrack.acquiringDrag);
            const beforeMove = interactiveTrack.displayedPosition;
            mouseMove(interactiveTrack, 270, 15, 0, Qt.LeftButton);
            verify(interactiveTrack.acquiringDrag, "The first move must not end the press animation");
            verify(interactiveTrack.displayedPosition - beforeMove < 0.1, "The fill must not jump to the pointer");
            wait(80);
            verify(interactiveTrack.displayedPosition > 0.25, "The fill should start moving promptly");
            tryVerify(() => !interactiveTrack.acquiringDrag, 350);
            fuzzyCompare(interactiveTrack.displayedPosition, 0.9, 0.01);

            mouseMove(interactiveTrack, 210, 15, 0, Qt.LeftButton);
            compare(interactiveTrack.displayedPosition, 0.7);
            mouseRelease(interactiveTrack, 210, 15);
        }

        function test_releaseDuringAcquisitionKeepsSpringing() {
            mousePress(interactiveTrack, 225, 15);
            mouseMove(interactiveTrack, 270, 15, 0, Qt.LeftButton);
            const beforeRelease = interactiveTrack.displayedPosition;
            mouseRelease(interactiveTrack, 270, 15);
            verify(interactiveTrack.displayedPosition - beforeRelease < 0.1, "Release must not jump to the pointer");
            wait(80);
            verify(interactiveTrack.displayedPosition > beforeRelease, "The fill should keep moving after release");
            tryVerify(() => Math.abs(interactiveTrack.displayedPosition - 0.9) < 0.01, 350);
        }

        function test_dragRendersBeforeRelease() {
            mousePress(interactiveTrack, 75, 15);
            root.renderedFrames = 0;
            mouseMove(interactiveTrack, 225, 15, 0, Qt.LeftButton);
            wait(300);
            compare(interactiveTrack.displayedPosition, 0.75);
            verify(root.renderedFrames > 0, "The dragged track must be rendered without another input event");
            compare(grabImage(interactiveTrack).red(150, 15), 255);
            mouseRelease(interactiveTrack, 225, 15);
        }

        function test_fillEdge() {
            track.progress = 0.5;
            wait(100);
            const image = grabImage(track);
            compare(image.red(145, 15), 255);
            compare(image.red(155, 15), 0);
            compare(image.pixel(0, 0), Qt.rgba(1, 0, 0, 1));
        }
    }
}
