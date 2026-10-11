import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root
    property string title: ""
    property string description: ""
    property bool checked: false
    property color accent: Theme.settingsCopper
    signal toggled(bool checked)
    implicitHeight: 78
    radius: Theme.settingsRadiusSmall
    color: Theme.settingsCard
    border.color: checked ? accent : Theme.settingsBorder
    border.width: 1

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 14
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            Text { text: root.title; color: Theme.settingsText; font.pixelSize: 15; font.weight: Font.DemiBold }
            Text { Layout.fillWidth: true; text: root.description; color: Theme.settingsTextMuted; font.pixelSize: 12; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
        }
        Switch {
            checked: root.checked
            activeFocusOnTab: true
            Accessible.name: root.title
            onToggled: root.toggled(checked)
        }
    }
}
