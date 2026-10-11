import QtQuick
import QtQuick.Controls
import "../theme"

/**
 * LayoutOverlay - Displays layout PNG image over live view
 * The layout PNG has transparent areas where the photo should be taken
 * This helps users pose within the frame
 */
Item {
    id: root

    // Properties
    property string layoutPath: ""        // Path to layout PNG
    property real overlayOpacity: 1.0     // Opacity of the overlay (default: fully opaque)

    // Display the layout PNG image as overlay
    Image {
        id: layoutImage
        anchors.fill: parent
        source: root.layoutPath
        fillMode: Image.PreserveAspectFit
        opacity: root.overlayOpacity
        visible: root.visible && root.layoutPath !== ""

        onStatusChanged: {
            if (status === Image.Error) {
                console.error("[LayoutOverlay] Failed to load layout image:", root.layoutPath)
            } else if (status === Image.Ready) {
                console.log("[LayoutOverlay] Layout image loaded successfully!")
                console.log("[LayoutOverlay] Image size:", sourceSize.width, "x", sourceSize.height)
            }
        }
    }

    // Helper text when overlay is active
    Text {
        visible: root.visible && root.layoutPath !== ""
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 40
        text: "📷 Pose within the frame"
        color: "#ffffff"
        font.pixelSize: 18
        font.weight: Font.Bold
        style: Text.Outline
        styleColor: "#000000"

        // Breathing animation
        SequentialAnimation on opacity {
            running: parent.visible
            loops: Animation.Infinite
            NumberAnimation { from: 0.6; to: 1.0; duration: 1000; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 1.0; to: 0.6; duration: 1000; easing.type: Easing.InOutQuad }
        }
    }
}
