import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import "../theme"

// ─────────────────────────────────────────────────────────────────────────────
// ColorPicker — lightweight HSV color picker (no C++ required)
//
// Usage:
//   ColorPicker {
//       pickedColor: someColor
//       onPickedColorChanged: doSomethingWith(pickedColor)
//   }
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: cpRoot

    implicitWidth:  320
    implicitHeight: svPanel.height + 54 + 36 + 20   // sv + hue+swatch row + hex + spacing

    // ── Public API ───────────────────────────────────────────────────────────
    property color pickedColor: "#1e7eea"

    // ── Internal HSV state ───────────────────────────────────────────────────
    property real _h: 0.58   // 0..1
    property real _s: 0.87   // 0..1
    property real _v: 0.92   // 0..1

    // Prevent feedback loop when we set pickedColor ourselves
    property bool _selfUpdating: false

    // Pure-hue color used as the base of the SV panel
    property color _hueBase: Qt.hsva(_h, 1, 1, 1)

    // Sync HSV sliders when pickedColor is changed externally
    onPickedColorChanged: {
        if (_selfUpdating) return
        var h = pickedColor.hsvHue
        _h = (h >= 0) ? h : 0
        _s = pickedColor.hsvSaturation
        _v = pickedColor.hsvValue
    }

    function _emit() {
        _selfUpdating = true
        pickedColor = Qt.hsva(_h, _s, _v, 1.0)
        _selfUpdating = false
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // ── SV 2D area ───────────────────────────────────────────────────────
        Item {
            id: svPanel
            Layout.fillWidth: true
            height: Math.max(180, cpRoot.width * 0.58)

            Rectangle {
                id: svRect
                anchors.fill: parent
                radius: 10
                clip: true

                // Base = pure Hue
                color: cpRoot._hueBase

                // White → transparent  (left → right  ≙ S=0→1)
                Rectangle {
                    anchors.fill: parent
                    radius: svRect.radius
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#ffffffff" }
                        GradientStop { position: 1.0; color: "#00ffffff" }
                    }
                }

                // transparent → Black  (top → bottom  ≙ V=1→0)
                Rectangle {
                    anchors.fill: parent
                    radius: svRect.radius
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: "#00000000" }
                        GradientStop { position: 1.0; color: "#ff000000" }
                    }
                }

                // Cursor
                Rectangle {
                    id: svCursor
                    x: cpRoot._s * svRect.width  - width  / 2
                    y: (1 - cpRoot._v) * svRect.height - height / 2
                    width: 22; height: 22; radius: 11
                    color: "transparent"
                    border.color: "white"; border.width: 2.5
                    // Inner dot
                    Rectangle {
                        anchors.centerIn: parent
                        width: 10; height: 10; radius: 5
                        color: cpRoot.pickedColor
                        border.color: Qt.rgba(0,0,0,0.5); border.width: 1
                    }
                }

                MouseArea {
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.CrossCursor
                    onPressed:         pickSV(mouseX, mouseY)
                    onPositionChanged: if (pressed) pickSV(mouseX, mouseY)
                    function pickSV(mx, my) {
                        cpRoot._s = Math.max(0, Math.min(1, mx / svRect.width))
                        cpRoot._v = Math.max(0, Math.min(1, 1 - my / svRect.height))
                        cpRoot._emit()
                    }
                }
            }
        }

        // ── Hue slider + swatch ──────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Current colour swatch
            Rectangle {
                width: 44; height: 44; radius: 12
                color: cpRoot.pickedColor
                border.color: Qt.rgba(1,1,1,0.25); border.width: 1.5
            }

            // Rainbow hue strip
            Item {
                Layout.fillWidth: true
                height: 28

                Rectangle {
                    id: hueTrack
                    anchors.fill: parent
                    radius: 14; clip: true
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0       ; color: "#ff0000" }
                        GradientStop { position: 0.16667 ; color: "#ffff00" }
                        GradientStop { position: 0.33333 ; color: "#00ff00" }
                        GradientStop { position: 0.5     ; color: "#00ffff" }
                        GradientStop { position: 0.66667 ; color: "#0000ff" }
                        GradientStop { position: 0.83333 ; color: "#ff00ff" }
                        GradientStop { position: 1       ; color: "#ff0000" }
                    }
                }

                // Hue cursor
                Rectangle {
                    x: cpRoot._h * hueTrack.width - width / 2
                    y: -3
                    width: 20; height: hueTrack.height + 6
                    radius: 10
                    color: "transparent"
                    border.color: "white"; border.width: 2.5
                }

                MouseArea {
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.SizeHorCursor
                    onPressed:         pickH(mouseX)
                    onPositionChanged: if (pressed) pickH(mouseX)
                    function pickH(mx) {
                        cpRoot._h = Math.max(0, Math.min(0.9999, mx / hueTrack.width))
                        cpRoot._emit()
                    }
                }
            }
        }

        // ── HEX display (read-only) ──────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 36; radius: 8
            color: Window.window ? Window.window.appFieldColor : "#FFFFFF"
            border.color: Window.window ? Window.window.appBorderColor : Theme.border
            border.width: 1

            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 6
                Text {
                    text: "HEX"
                    color: Window.window ? Qt.rgba(Window.window.appTextColor.r, Window.window.appTextColor.g, Window.window.appTextColor.b, 0.58) : Theme.textMuted
                    font.pixelSize: 11
                    font.bold: true
                }
                Text {
                    Layout.fillWidth: true
                    text: cpRoot.pickedColor.toString().toUpperCase()
                    color: Window.window ? Window.window.appTextColor : "#1F2430"; font.pixelSize: 13; font.family: "Courier New"
                }
                // Small copy-color square
                Rectangle {
                    width: 24; height: 24; radius: 6
                    color: cpRoot.pickedColor
                    border.color: Qt.rgba(1,1,1,0.2); border.width: 1
                }
            }
        }
    }
}
