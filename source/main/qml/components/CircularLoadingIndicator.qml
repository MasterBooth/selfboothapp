import QtQuick
import "../theme"

Item {
    id: root

    // Public API Properties
    property int status: 0  // 0=NotChecked, 1=Checking, 2=Authenticated, 3-5=Error states
    property color loadingColor: "#ffffff"
    property color successColor: "#4CAF50"
    property real size: 60
    property real strokeWidth: 4

    width: size
    height: size

    // Rotating container for the animated arc (270° partial circle)
    Item {
        id: rotatingContainer
        anchors.centerIn: parent
        width: root.size
        height: root.size
        visible: root.status === 1
        opacity: 1
        rotation: 0

        // Canvas to draw the 270° arc
        Canvas {
            id: arcCanvas
            anchors.fill: parent
            visible: root.status === 1

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)

                var centerX = width / 2
                var centerY = height / 2
                var radius = (root.size - root.strokeWidth) / 2

                // Draw arc (270° = 1.5 * PI radians)
                ctx.strokeStyle = root.loadingColor
                ctx.lineWidth = root.strokeWidth
                ctx.lineCap = "round"

                // Start from top (-90°), draw 270° clockwise
                var startAngle = -Math.PI / 2  // -90° (top)
                var endAngle = startAngle + (3 * Math.PI / 2)  // +270°

                ctx.beginPath()
                ctx.arc(centerX, centerY, radius, startAngle, endAngle)
                ctx.stroke()
            }

            // Redraw when status changes
            Connections {
                target: root
                function onStatusChanged() {
                    arcCanvas.requestPaint()
                }
            }
        }

        // Rotation animation for the entire container
        RotationAnimation {
            target: rotatingContainer
            from: 0
            to: 360
            duration: 1200
            direction: RotationAnimation.Clockwise
            easing.type: Easing.Linear
            loops: Animation.Infinite
            running: root.status === 1
        }
    }

    // Success indicator text
    Text {
        id: successText
        anchors.centerIn: parent
        text: "THÀNH CÔNG"
        color: root.successColor
        font.bold: true
        font.pixelSize: root.size * 0.27
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        opacity: 0
        visible: opacity > 0
        scale: 0.5
    }

    // Behavior for smooth opacity transitions
    Behavior on opacity {
        NumberAnimation {
            duration: 300
            easing.type: Easing.InOutQuad
        }
    }

    // State machine for managing loading vs success states
    states: [
        State {
            name: "loading"
            when: root.status === 1
            PropertyChanges {
                target: rotatingContainer
                visible: true
                opacity: 1
            }
            PropertyChanges {
                target: successText
                opacity: 0
                scale: 0.5
            }
        },
        State {
            name: "success"
            when: root.status === 2
            PropertyChanges {
                target: rotatingContainer
                visible: false
                opacity: 0
            }
            PropertyChanges {
                target: successText
                opacity: 1
                scale: 1.0
            }
        }
    ]

    // Smooth transitions between states
    transitions: [
        Transition {
            from: "loading"
            to: "success"
            SequentialAnimation {
                // Fade out the loading animation
                NumberAnimation {
                    target: rotatingContainer
                    property: "opacity"
                    to: 0
                    duration: 200
                }
                // Then show success with fade + scale
                ParallelAnimation {
                    NumberAnimation {
                        target: successText
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: 300
                    }
                    NumberAnimation {
                        target: successText
                        property: "scale"
                        from: 0.5
                        to: 1.0
                        duration: 300
                        easing.type: Easing.OutBack
                    }
                }
            }
        },
        Transition {
            from: "success"
            to: "loading"
            SequentialAnimation {
                // Hide success
                ParallelAnimation {
                    NumberAnimation {
                        target: successText
                        property: "opacity"
                        to: 0
                        duration: 200
                    }
                    NumberAnimation {
                        target: successText
                        property: "scale"
                        to: 0.5
                        duration: 200
                    }
                }
                // Show loading
                PropertyAction {
                    target: rotatingContainer
                    property: "opacity"
                    value: 1
                }
            }
        }
    ]
}
