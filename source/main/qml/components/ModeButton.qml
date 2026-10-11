import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Item {
    id: root
    
    // Public Properties
    property string label: "Mode"
    property string iconText: "📷" // Placeholder for icon (can replace with Image source)
    property color circleColor: "#ffffff"
    property color textColor: "#ffffff"
    property color iconColor: "#1a1d23" // Dark charcoal for the icon inside white circle
    property bool isSelected: false
    
    signal clicked()
    
    // Size config
    implicitWidth: 160
    implicitHeight: 200 // Includes text space
    
    property real circleSize: 120
    
    // Main interaction area
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
    
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 20
        
        // The Circle Button
        Rectangle {
            id: circle
            Layout.alignment: Qt.AlignHCenter
            width: root.circleSize
            height: root.circleSize
            radius: width / 2
            
            color: root.circleColor
            
            // Simple Shadow Implementation (Rectangle behind)
            Rectangle {
                z: -1
                anchors.fill: parent
                anchors.topMargin: 4
                anchors.leftMargin: 2 // slight offset
                radius: parent.radius
                color: "#40000000"
                visible: true
            }
            
            // Animation for Hover/Press
            scale: mouseArea.pressed ? 0.95 : (mouseArea.containsMouse ? 1.05 : 1.0)
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
            
            // Icon (Centered) - Using Text for now, can be swapped for Image
            Text {
                anchors.centerIn: parent
                text: root.iconText
                font.pixelSize: root.circleSize * 0.4
                color: root.iconColor
                font.family: "Segoe UI Emoji" // Win10/11 standard
            }
        }
        
        // Brief Label below
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.label
            color: root.textColor
            font.pixelSize: 18
            font.weight: Font.Medium
            font.letterSpacing: 1.2
            opacity: mouseArea.containsMouse ? 1.0 : 0.8
            
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }
}
