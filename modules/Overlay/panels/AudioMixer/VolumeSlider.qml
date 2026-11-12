import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire as PW

import QtQuick

import qs.config
import qs.components
import qs.services

Row {
    id: root

    required property PW.PwNodeAudio audio
    required property PW.PwNode node
    required property string category

    readonly property bool supportsDefaultSelection: category === "playbacks" || category === "mics"
    readonly property bool isDefaultNode: root.supportsDefaultSelection && AudioService.isDefaultNode(root.node, root.category)
    readonly property real volumeWriteEpsilon: 0.01
    readonly property real rapidMovementThreshold: 0.08

    property real requestedVolume: 1
    property real pendingVolume: 1
    property real lastSentVolume: -1
    property real displayedPosition: 1
    property real sampledVolume: 1
    property real pressX: 0
    property real clickMovement: 0
    property bool acquiringDrag: false
    property bool pointerMoving: false
    property bool dragging: false
    property bool awaitingConfirmation: false
    property bool animateDisplay: false

    onRequestedVolumeChanged: displayedPosition = requestedVolume
    onDisplayedPositionChanged: {
        if (acquiringDrag && pointerMoving && Math.abs(displayedPosition - requestedVolume) * volumeTrack.width <= 3) {
            acquiringDrag = false;
            displayedPosition = requestedVolume;
        }
    }
    onAudioChanged: {
        if (animateDisplay)
            resetFromAudio();
    }

    Behavior on displayedPosition {
        enabled: root.animateDisplay && (!root.pointerMoving || root.acquiringDrag)
        SmoothedAnimation {
            duration: 60
            velocity: -1
            maximumEasingTime: 30
            reversingMode: SmoothedAnimation.Immediate
        }
    }

    Component.onCompleted: resetFromAudio()

    spacing: Appearance.padding.sm

    Item {
        id: defaultSelector
        visible: root.supportsDefaultSelection
        enabled: !!root.node

        implicitWidth: indicatorIcon.implicitWidth
        implicitHeight: indicatorIcon.implicitHeight

        MaterialIcon {
            id: indicatorIcon

            anchors.centerIn: parent

            name: root.isDefaultNode ? "radio_button_checked" : "radio_button_unchecked"
            size: Appearance.font.size.lg
        }

        MouseArea {
            anchors.fill: parent
            enabled: parent.enabled

            onClicked: AudioService.setPreferredDefault(root.node, root.category)
        }
    }

    ClippingRectangle {
        id: volumeTrack

        implicitWidth: Appearance.elementSize.audioMixer_sliderWidth
        implicitHeight: Appearance.elementSize.audioMixer_sliderThickness
        radius: height / 2
        color: "transparent"

        MaskedProgressTrack {
            anchors.fill: parent

            progress: root.displayedPosition
            radius: Appearance.rounding.full
            baseColor: Appearance.colors.tertiary
            fillColor: Appearance.colors.tertiary_contrast
        }

        VolumeHandle {
            id: handle

            width: volumeTrack.height * 1.4
            height: volumeTrack.height
            anchors.verticalCenter: parent.verticalCenter
            position: root.displayedPosition
            trackWidth: volumeTrack.width
            leftColor: Appearance.colors.tertiary_contrast
            rightColor: Appearance.colors.tertiary
        }

        MouseArea {
            anchors.fill: parent
            enabled: !!root.audio
            preventStealing: true

            onPressed: mouse => {
                root.dragging = true;
                root.pointerMoving = false;
                root.pressX = mouse.x;
                const previousPosition = root.displayedPosition;
                root.acquiringDrag = Math.abs(previousPosition - root.clampVolume(mouse.x / volumeTrack.width)) * volumeTrack.width > 3;
                clickKick.stop();
                handle.reset();
                root.awaitingConfirmation = false;
                volumeConfirmation.stop();
                root.requestFromX(mouse.x);
                root.clickMovement = root.requestedVolume - previousPosition;
                if (Math.abs(root.clickMovement * volumeTrack.width) > 3)
                    clickKick.start();
                root.sampledVolume = root.requestedVolume;
                motionSample.start();
                root.flushPendingVolume(false);
                volumeFlush.start();
            }

            onPositionChanged: mouse => {
                if (!pressed)
                    return;

                if (!root.pointerMoving && Math.abs(mouse.x - root.pressX) >= 3) {
                    root.pointerMoving = true;
                    clickKick.stop();
                    handle.reset();
                }
                root.requestFromX(mouse.x);
            }

            onReleased: mouse => {
                root.requestFromX(mouse.x);
                root.finishDrag();
            }

            onCanceled: {
                clickKick.stop();
                root.finishDrag();
            }
        }
    }

    Connections {
        target: root.audio

        function onVolumeChanged() {
            root.syncFromAudio();
        }
    }

    Timer {
        id: volumeFlush

        interval: 30
        repeat: true

        onTriggered: root.flushPendingVolume(false)
    }

    Timer {
        id: clickKick

        interval: 45

        onTriggered: handle.kick(root.clickMovement * volumeTrack.width * 0.25)
    }

    Timer {
        id: motionSample

        interval: 50
        repeat: true

        onTriggered: root.sampleMotion()
    }

    Timer {
        id: volumeConfirmation

        interval: 500

        onTriggered: {
            root.awaitingConfirmation = false;
            root.syncFromAudio();
        }
    }

    function clampVolume(value: real): real {
        return Math.max(0, Math.min(1, value));
    }

    function resetFromAudio() {
        volumeFlush.stop();
        volumeConfirmation.stop();
        motionSample.stop();
        clickKick.stop();
        handle.reset();
        acquiringDrag = false;
        pointerMoving = false;
        dragging = false;
        awaitingConfirmation = false;
        lastSentVolume = -1;
        animateDisplay = false;
        requestedVolume = audio ? clampVolume(audio.volume) : 1;
        pendingVolume = requestedVolume;
        sampledVolume = requestedVolume;
        displayedPosition = requestedVolume;
        animateDisplay = true;
    }

    function syncFromAudio() {
        if (!audio || dragging)
            return;

        const reportedVolume = clampVolume(audio.volume);
        if (awaitingConfirmation) {
            // Ignore older write responses until the final volume is confirmed.
            if (Math.abs(reportedVolume - requestedVolume) > volumeWriteEpsilon)
                return;
            awaitingConfirmation = false;
            volumeConfirmation.stop();
        }
        requestedVolume = reportedVolume;
    }

    function requestFromX(x: real) {
        if (!audio || volumeTrack.width <= 0)
            return;

        requestedVolume = clampVolume(x / volumeTrack.width);
        pendingVolume = requestedVolume;
    }

    function sampleMotion() {
        const movement = requestedVolume - sampledVolume;
        sampledVolume = requestedVolume;
        if (!pointerMoving || Math.abs(movement) < rapidMovementThreshold)
            return;

        handle.kick(movement * volumeTrack.width * 0.25);
    }

    function finishDrag() {
        if (!dragging)
            return;

        motionSample.stop();
        sampleMotion();
        volumeFlush.stop();
        dragging = false;
        acquiringDrag = false;
        pointerMoving = false;
        displayedPosition = requestedVolume;
        awaitingConfirmation = true;
        volumeConfirmation.start();
        flushPendingVolume(true);
    }

    function flushPendingVolume(force: bool) {
        if (!audio)
            return;

        if (!force && Math.abs(pendingVolume - lastSentVolume) < volumeWriteEpsilon)
            return;

        audio.volume = pendingVolume;
        lastSentVolume = pendingVolume;
    }
}
