import QtQuick
import QtQuick.Window
import "../../theme"
import "../../components"

Rectangle {
    id: root
    width: Window.window ? Window.window._designW : 1920
    height: Window.window ? Window.window._designH : 1080

    property string backgroundImage: ""

    // Effective background: use the externally-provided image when set; otherwise
    // fall back to the default page background image (waiting.png).
    readonly property string _effectiveBackground:
        backgroundImage !== "" ? backgroundImage : "qrc:/assets/2.png"

    signal continueClicked()
    signal backClicked()

    color: root._effectiveBackground !== "" ? "transparent" : "#ffffff"

    function resolveImageSource(path) {
        if (!path || path === "")
            return ""
        if (path.indexOf("file:") === 0 || path.indexOf("qrc:") === 0 || path.indexOf("http") === 0)
            return path
        return "file:///" + path.replace(/\\/g, "/")
    }

    BackgroundMedia {
        anchors.fill: parent
        sourcePath: root._effectiveBackground
        visible: root._effectiveBackground !== ""
    }

    Text {
        anchors.centerIn: parent
        visible: root._effectiveBackground === ""
        text: "selfbooth"
        color: "#7A4B2A"
        font.pixelSize: Math.round(Math.min(root.width, root.height) * 0.08)
        font.bold: true
        font.family: "Raleway"
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.continueClicked()
    }

    Item {
        id: backPill
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 40
        anchors.bottomMargin: 40
        width: 160; height: 150
        z: 100

        scale: waitingBackMouse.pressed ? 0.92 : 1.0
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

        Column {
            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "‹"
                color: "#7A4B2A"
                opacity: waitingBackMouse.containsMouse ? 1.0 : 0.85
                font.pixelSize: 84; font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Behavior on opacity { NumberAnimation { duration: 130 } }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Back"
                color: "#7A4B2A"
                opacity: waitingBackMouse.containsMouse ? 1.0 : 0.85
                font.pixelSize: 30; font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                Behavior on opacity { NumberAnimation { duration: 130 } }
            }
        }

        MouseArea {
            id: waitingBackMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.backClicked()
        }
    }

    Item {
        id: nextPill
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 40
        anchors.bottomMargin: 40
        width: 160; height: 150
        z: 100

        scale: waitingNextMouse.pressed ? 0.92 : 1.0
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

        Column {
            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "›"
                color: "#ad436d"
                opacity: waitingNextMouse.containsMouse ? 1.0 : 0.9
                font.pixelSize: 84; font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Behavior on opacity { NumberAnimation { duration: 130 } }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Next"
                color: "#ad436d"
                opacity: waitingNextMouse.containsMouse ? 1.0 : 0.9
                font.pixelSize: 30; font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                Behavior on opacity { NumberAnimation { duration: 130 } }
            }
        }

        MouseArea {
            id: waitingNextMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.continueClicked()
        }
    }
}
