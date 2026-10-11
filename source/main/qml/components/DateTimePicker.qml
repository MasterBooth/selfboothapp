import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.VirtualKeyboard
import "../theme"

// Bộ chọn ngày + giờ dạng popup (lịch + con lăn giờ/phút).
// Giờ/phút: cuộn con lăn, bấm ▲▼, hoặc bấm vào số giữa để gõ bàn phím nhanh.
// Dùng cho khung giờ hiệu lực voucher theo ca.
//
// Cách dùng:
//   DateTimePicker { id: dtp; onAccepted: field.text = isoText }
//   ... onClicked: dtp.openWith(field.text)   // mở với giá trị hiện có
//
// Phát signal accepted() khi bấm Xong; kết quả ở các property:
//   - isoText : "yyyy-MM-ddTHH:mm:ss"  (dùng lưu DB)
//   - displayText : "yyyy-MM-dd HH:mm" (hiển thị)
Popup {
    id: root

    signal accepted()

    // chế độ chỉ chọn ngày (ẩn phần giờ) — dùng cho "ngày hết hạn"
    property bool dateOnly: false
    property string title: "Chọn ngày & giờ"

    // Trạng thái chọn
    property int    selYear:   (new Date()).getFullYear()
    property int    selMonth:  (new Date()).getMonth()   // 0..11
    property int    selDay:    (new Date()).getDate()
    property int    selHour:   0
    property int    selMinute: 0

    readonly property var _selDate: new Date(selYear, selMonth, selDay,
                                             dateOnly ? 0 : selHour,
                                             dateOnly ? 0 : selMinute, 0)

    function _pad(n) { return (n < 10 ? "0" : "") + n }

    readonly property string isoText:
        selYear + "-" + _pad(selMonth + 1) + "-" + _pad(selDay) +
        (dateOnly ? "" : ("T" + _pad(selHour) + ":" + _pad(selMinute) + ":00"))

    readonly property string displayText:
        selYear + "-" + _pad(selMonth + 1) + "-" + _pad(selDay) +
        (dateOnly ? "" : (" " + _pad(selHour) + ":" + _pad(selMinute)))

    // Mở với giá trị sẵn có (chuỗi "yyyy-MM-dd" hoặc "yyyy-MM-dd HH:mm[:ss]" hoặc ISO).
    function openWith(text) {
        var now = new Date()
        var d = now
        if (text && text.trim() !== "") {
            var t = text.trim().replace("T", " ")
            var parsed = new Date(t.replace(" ", "T"))
            if (!isNaN(parsed.getTime())) d = parsed
        }
        selYear   = d.getFullYear()
        selMonth  = d.getMonth()
        selDay    = d.getDate()
        selHour   = d.getHours()
        selMinute = d.getMinutes()
        open()
    }

    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    anchors.centerIn: Overlay.overlay
    width: 380
    padding: 0

    background: Rectangle {
        color: "#1a1d23"; radius: 16
        border.color: "#3a3d45"; border.width: 1
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    function _daysInMonth(y, m) { return new Date(y, m + 1, 0).getDate() }
    // Thứ của ngày 1 (0 = CN). Đổi sang cột bắt đầu Thứ 2 = 0.
    function _firstWeekday(y, m) {
        var wd = new Date(y, m, 1).getDay()   // 0..6 (CN..T7)
        return (wd + 6) % 7                   // 0 = T2 ... 6 = CN
    }

    readonly property var _monthNames: [
        "Tháng 1","Tháng 2","Tháng 3","Tháng 4","Tháng 5","Tháng 6",
        "Tháng 7","Tháng 8","Tháng 9","Tháng 10","Tháng 11","Tháng 12"]

    // ── Con lăn chọn giờ/phút: lớn, cuộn vòng mượt, có nút ▲▼ ──────────────────
    component TimeWheel: ColumnLayout {
        id: wheel
        property string label: ""
        property int    count: 60
        property int    value: 0
        spacing: 6

        Text { text: wheel.label; color: "#8090a8"; font.pixelSize: 12; Layout.alignment: Qt.AlignHCenter }

        // Nút tăng
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 64; height: 30; radius: 8
            color: upMa.pressed ? "#1e7eea" : (upMa.containsMouse ? "#2a3550" : "#222530")
            Behavior on color { ColorAnimation { duration: 80 } }
            Text { anchors.centerIn: parent; text: "▲"; color: Theme.textMuted; font.pixelSize: 14 }
            MouseArea {
                id: upMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: wheel.value = (wheel.value + 1) % wheel.count
            }
        }

        // Tumbler lớn, cuộn vòng — bấm vào số giữa để gõ bàn phím
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 64; height: 132; radius: 10
            color: "#12151d"; border.color: "#2a2d38"; border.width: 1
            clip: true

            property bool editing: false

            // Dải highlight ở giữa (vị trí item đang chọn)
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 8; height: 40; radius: 8
                color: "#1a2f52"; border.color: parent.editing ? "#4FA4F2" : "#1e7eea"; border.width: parent.editing ? 2 : 1
            }

            Tumbler {
                id: tmb
                anchors.fill: parent
                visible: !parent.editing
                model: wheel.count
                visibleItemCount: 3
                wrap: true
                currentIndex: wheel.value
                onCurrentIndexChanged: if (currentIndex !== wheel.value) wheel.value = currentIndex

                // Đồng bộ khi value đổi từ bên ngoài (nút ▲▼ hoặc nhập tay)
                Connections {
                    target: wheel
                    function onValueChanged() {
                        if (tmb.currentIndex !== wheel.value) tmb.currentIndex = wheel.value
                    }
                }

                delegate: Text {
                    text: root._pad(modelData)
                    color: Tumbler.displacement === 0 ? "#ffffff" : "#5a5d68"
                    font.pixelSize: Tumbler.displacement === 0 ? 24 : 17
                    font.bold: Tumbler.displacement === 0
                    opacity: 1.0 - Math.min(1, Math.abs(Tumbler.displacement) * 0.45)
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
            }

            // Ô nhập bằng bàn phím — chỉ hiện khi đang sửa
            TextField {
                id: editField
                anchors.centerIn: parent
                width: parent.width - 10; height: 40
                visible: parent.editing
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: "#ffffff"; font.pixelSize: 24; font.bold: true
                inputMethodHints: Qt.ImhDigitsOnly
                maximumLength: 2
                background: Item {}
                onActiveFocusChanged: if (!activeFocus) _commit()
                Keys.onReturnPressed: _commit()
                Keys.onEnterPressed:  _commit()
                function _commit() {
                    var n = parseInt(editField.text)
                    if (!isNaN(n)) wheel.value = Math.max(0, Math.min(wheel.count - 1, n))
                    editField.parent.editing = false
                    Qt.inputMethod.hide()
                }
            }

            // Bấm vùng giữa để bật chế độ gõ
            MouseArea {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 44
                enabled: !parent.editing
                cursorShape: Qt.IBeamCursor
                onClicked: {
                    parent.editing = true
                    editField.text = root._pad(wheel.value)
                    editField.forceActiveFocus()
                    editField.selectAll()
                }
            }
        }

        // Nút giảm
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 64; height: 30; radius: 8
            color: downMa.pressed ? "#1e7eea" : (downMa.containsMouse ? "#2a3550" : "#222530")
            Behavior on color { ColorAnimation { duration: 80 } }
            Text { anchors.centerIn: parent; text: "▼"; color: Theme.textMuted; font.pixelSize: 14 }
            MouseArea {
                id: downMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: wheel.value = (wheel.value - 1 + wheel.count) % wheel.count
            }
        }
    }

    contentItem: ColumnLayout {
        spacing: 0

        // ── Header: tiêu đề + giá trị đang chọn ───────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: 18
            Layout.bottomMargin: 8
            spacing: 4
            Text { text: root.title; color: "#8090a8"; font.pixelSize: 13 }
            Text { text: root.displayText; color: "#ffffff"; font.pixelSize: 22; font.bold: true }
        }

        // ── Điều hướng tháng ──────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 16; Layout.rightMargin: 16
            spacing: 8

            Rectangle {
                width: 36; height: 36; radius: 8
                color: prevMa.containsMouse ? "#2a2d35" : "#222530"
                Text { anchors.centerIn: parent; text: "‹"; color: Theme.textMuted; font.pixelSize: 20; font.bold: true }
                MouseArea {
                    id: prevMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.selMonth === 0) { root.selMonth = 11; root.selYear-- }
                        else root.selMonth--
                        var dim = root._daysInMonth(root.selYear, root.selMonth)
                        if (root.selDay > dim) root.selDay = dim
                    }
                }
            }
            Text {
                Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                text: root._monthNames[root.selMonth] + " " + root.selYear
                color: "#ffffff"; font.pixelSize: 15; font.bold: true
            }
            Rectangle {
                width: 36; height: 36; radius: 8
                color: nextMa.containsMouse ? "#2a2d35" : "#222530"
                Text { anchors.centerIn: parent; text: "›"; color: Theme.textMuted; font.pixelSize: 20; font.bold: true }
                MouseArea {
                    id: nextMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.selMonth === 11) { root.selMonth = 0; root.selYear++ }
                        else root.selMonth++
                        var dim = root._daysInMonth(root.selYear, root.selMonth)
                        if (root.selDay > dim) root.selDay = dim
                    }
                }
            }
        }

        // ── Tên các thứ ───────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 16; Layout.rightMargin: 16; Layout.topMargin: 10
            spacing: 0
            Repeater {
                model: ["T2","T3","T4","T5","T6","T7","CN"]
                delegate: Text {
                    Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: index >= 5 ? "#ef8080" : "#8090a8"
                    font.pixelSize: 11; font.bold: true
                }
            }
        }

        // ── Lưới ngày ─────────────────────────────────────────────────────────
        Grid {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            Layout.leftMargin: 16; Layout.rightMargin: 16
            columns: 7
            spacing: 2

            Repeater {
                model: 42
                delegate: Item {
                    width: 44; height: 38
                    property int dayNum: index - root._firstWeekday(root.selYear, root.selMonth) + 1
                    property bool inMonth: dayNum >= 1 && dayNum <= root._daysInMonth(root.selYear, root.selMonth)
                    property bool isSel: inMonth && dayNum === root.selDay

                    Rectangle {
                        anchors.centerIn: parent
                        width: 34; height: 34; radius: 17
                        visible: parent.inMonth
                        color: parent.isSel ? "#1e7eea" : (dayMa.containsMouse ? "#2a3550" : "transparent")
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text {
                            anchors.centerIn: parent
                            text: parent.parent.dayNum
                            color: parent.parent.isSel ? "#ffffff" : Theme.border
                            font.pixelSize: 14; font.bold: parent.parent.isSel
                        }
                        MouseArea {
                            id: dayMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            enabled: parent.parent.inMonth
                            onClicked: root.selDay = parent.parent.dayNum
                        }
                    }
                }
            }
        }

        // ── Chọn giờ / phút (con lăn lớn, mượt + nút ▲▼) ───────────────────────
        RowLayout {
            visible: !root.dateOnly
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 12
            spacing: 6

            TimeWheel {
                id: hourWheel
                label: "Giờ"
                count: 24
                value: root.selHour
                onValueChanged: root.selHour = value
            }
            Text { text: ":"; color: "#ffffff"; font.pixelSize: 26; font.bold: true; Layout.bottomMargin: 6 }
            TimeWheel {
                id: minWheel
                label: "Phút"
                count: 60
                value: root.selMinute
                onValueChanged: root.selMinute = value
            }
        }

        // ── Nút ───────────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 16
            spacing: 12

            Rectangle {
                Layout.fillWidth: true; height: 46; radius: 12
                color: cancelMa.containsMouse ? "#2e1a1a" : "#1f2229"
                border.color: "#aa3322"; border.width: 1
                Text { anchors.centerIn: parent; text: "Hủy"; color: "#ff6644"; font.pixelSize: 15; font.bold: true }
                MouseArea { id: cancelMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.close() }
            }
            Rectangle {
                Layout.fillWidth: true; height: 46; radius: 12
                color: okMa.containsMouse ? "#1a6fd0" : "#1e7eea"
                Text { anchors.centerIn: parent; text: "Xong"; color: "#ffffff"; font.pixelSize: 15; font.bold: true }
                MouseArea {
                    id: okMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { root.close(); root.accepted() }
                }
            }
        }

        // Bàn phím ảo cho việc gõ nhanh giờ/phút
        InputPanel {
            id: dtpInputPanel
            Layout.fillWidth: true
            visible: Qt.inputMethod.visible
            active: Qt.inputMethod.visible
        }
    }
}
