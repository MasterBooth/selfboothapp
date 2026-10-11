import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// Styled GroupBox Component
Rectangle {
    id: root
    color: "#1f2229"
    radius: 8
    border.color: "#3a3d45"
    border.width: 1
    
    property string title: ""
    property alias content: contentLoader.sourceComponent
    
    implicitHeight: column.height + 32
    
    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16
        
        // Title
        Text {
            text: root.title
            color: "#ffffff"
            font.pixelSize: 15
            font.weight: Font.Bold
            visible: root.title !== ""
        }
        
        // Divider
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#2a2d35"
            visible: root.title !== ""
        }
        
        // Content
        Loader {
            id: contentLoader
            Layout.fillWidth: true
        }
    }
}
