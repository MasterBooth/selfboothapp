import QtQuick
import QtQuick.Layouts
import "../theme"

// CameraSettingSlider — redesigned as a +/- stepper (API unchanged)
ColumnLayout {
    id: root

    // ── Public API (same as before) ──────────────────────────────────────────
    property string label: ""
    property var    model: []
    property string currentValue: ""
    property bool   invertDirection: false   // Đảo chiều +/- (dùng cho shutter speed)

    property var valueExtractor:  function(item) { return item && item.value !== undefined ? item.value : item }
    property var labelFormatter:  function(val)  { return val }

    signal valueSelected(string value)

    // ── Internal helpers ──────────────────────────────────────────────────────
    property int _idx: {
        if (!root.model || root.model.length === 0) return 0
        for (var i = 0; i < root.model.length; i++) {
            if (root.valueExtractor(root.model[i]) == root.currentValue) return i
        }
        return 0
    }

    property bool _canDec: root.model && root.model.length > 0 && _idx > 0
    property bool _canInc: root.model && root.model.length > 0 && _idx < root.model.length - 1

    function _step(delta) {
        if (!root.model || root.model.length === 0) return
        var next = Math.max(0, Math.min(root.model.length - 1, _idx + delta))
        if (next !== _idx) {
            root.valueSelected(root.valueExtractor(root.model[next]))
        }
    }

    // ── Layout ────────────────────────────────────────────────────────────────
    spacing: 6

    // Row 1 — section label (left)
    Text {
        text: root.label
        color: Theme.settingsTextMuted
        font.pixelSize: 11
        font.weight: Font.Medium
        Layout.fillWidth: true
        elide: Text.ElideRight
    }

    // Row 2 — stepper row
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        // ── "–" button ───────────────────────────────────────────────────────
        Rectangle {
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38
            radius: 12
            color: decMouse.pressed ? "#F2DED4" : (decMouse.containsMouse ? Theme.settingsCopperSoft : Theme.settingsSurface)
            border.color: root._canDec ? Theme.settingsBorder : Qt.rgba(Theme.settingsBorder.r, Theme.settingsBorder.g, Theme.settingsBorder.b, 0.45)
            border.width: 1

            Behavior on border.color { ColorAnimation { duration: 100 } }

            Text {
                anchors.centerIn: parent
                text: "−"
                color: root._canDec ? Theme.settingsCopperDark : Theme.settingsTextMuted
                font.pixelSize: 22
                font.weight: Font.Bold
            }

            MouseArea {
                id: decMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: root._canDec
                cursorShape: root._canDec ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root._step(root.invertDirection ? +1 : -1)
            }
        }

        // ── Value display (centre) ────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: 12
            color: Theme.settingsCard
            border.color: Theme.settingsBorder
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: {
                    if (!root.model || root.model.length === 0)
                        return "—"
                    var formatted = root.labelFormatter(root.valueExtractor(root.model[root._idx]))
                    return (formatted === undefined || formatted === null)
                           ? "—"
                           : String(formatted)
                }
                color: Theme.settingsText
                font.pixelSize: 13
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                width: parent.width - 12
            }
        }

        // ── "+" button ───────────────────────────────────────────────────────
        Rectangle {
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38
            radius: 12
            color: incMouse.pressed ? "#F2DED4" : (incMouse.containsMouse ? Theme.settingsCopperSoft : Theme.settingsSurface)
            border.color: root._canInc ? Theme.settingsBorder : Qt.rgba(Theme.settingsBorder.r, Theme.settingsBorder.g, Theme.settingsBorder.b, 0.45)
            border.width: 1

            Behavior on border.color { ColorAnimation { duration: 100 } }

            Text {
                anchors.centerIn: parent
                text: "+"
                color: root._canInc ? Theme.settingsCopperDark : Theme.settingsTextMuted
                font.pixelSize: 22
                font.weight: Font.Bold
            }

            MouseArea {
                id: incMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: root._canInc
                cursorShape: root._canInc ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root._step(root.invertDirection ? -1 : +1)
            }
        }
    }
}
