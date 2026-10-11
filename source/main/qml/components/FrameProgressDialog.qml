import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// Dialog tiến trình cho các thao tác khung hình theo lô (tải lên / xoá / đổi tên).
//
// Điều khiển bằng 3 tín hiệu của EventManager: frameTaskStarted / frameTaskProgress /
// frameTaskFinished. Trang cài đặt chỉ cần gọi begin() / update() / finish().
//
// Trong lúc chạy dialog là modal và không tự đóng (NoAutoClose) để chặn người dùng
// bấm Xoá/Đổi tên chồng lên lô đang chạy. Khi xong: không lỗi thì tự đóng sau một
// nhịp ngắn, có lỗi thì ở lại để hiện danh sách tệp hỏng.
Popup {
    id: root

    // Người dùng bấm "Chạy nền" — trang cha có thể hiện toast khi lô kết thúc.
    signal dismissedToBackground()

    property string op: ""            // "upload" | "delete" | "rename"
    property int    current: 0
    property int    total: 1
    property string currentFile: ""
    property bool   running: false
    property int    okCount: 0
    property int    failedCount: 0
    property var    errors: []

    // Cho phép trang cha truyền màu riêng; mặc định bám theme Cài đặt.
    property color surfaceColor: Theme.settingsSurface
    property color textColor:    Theme.settingsText
    property color mutedColor:   Theme.settingsTextMuted
    property color borderColor:  Theme.settingsBorder
    property color trackColor:   Theme.settingsCard
    property color accentColor:  Theme.settingsCopper
    property color dangerColor:  Theme.settingsDanger

    readonly property string opTitle: {
        if (op === "upload") return "Đang tải khung hình..."
        if (op === "delete") return "Đang xóa khung hình..."
        if (op === "rename") return "Đang đổi tên khung hình..."
        return "Đang xử lý khung hình..."
    }
    readonly property string doneTitle: {
        if (failedCount > 0) return "Hoàn tất — có " + failedCount + " khung lỗi"
        if (op === "upload") return "Đã tải xong " + okCount + " khung"
        if (op === "delete") return "Đã xóa " + okCount + " khung"
        if (op === "rename") return "Đã đổi tên " + okCount + " khung"
        return "Hoàn tất"
    }

    modal: true
    closePolicy: Popup.NoAutoClose
    anchors.centerIn: parent
    width: 460
    // Cao thêm khi cần liệt kê lỗi cuối lô.
    height: (!running && failedCount > 0) ? 340 : 220
    padding: 24

    Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.35) }

    background: Rectangle {
        color: root.surfaceColor
        border.color: root.borderColor
        border.width: 1
        radius: 12
    }

    // Đóng dialog sau khi lô xong mà không có lỗi.
    Timer {
        id: autoCloseTimer
        interval: 450
        repeat: false
        onTriggered: root.close()
    }

    function begin(operation, totalCount) {
        root.op          = operation
        root.total       = Math.max(1, totalCount)
        root.current     = 0
        root.currentFile = ""
        root.okCount     = 0
        root.failedCount = 0
        root.errors      = []
        root.running     = true
        autoCloseTimer.stop()
        if (!root.opened) root.open()
    }

    function update(cur, totalCount, fileName) {
        root.current     = cur
        root.total       = Math.max(1, totalCount)
        root.currentFile = fileName || ""
    }

    function finish(ok, failed, errorList) {
        root.running     = false
        root.okCount     = ok
        root.failedCount = failed
        root.errors      = errorList || []
        root.current     = root.total
        root.currentFile = ""
        if (failed === 0) autoCloseTimer.start()
    }

    contentItem: ColumnLayout {
        spacing: 14

        Text {
            text: root.running ? root.opTitle : root.doneTitle
            color: (!root.running && root.failedCount > 0) ? root.dangerColor : root.textColor
            font.pixelSize: 16
            font.weight: Font.Bold
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        BusyIndicator {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            visible: root.running
            running: root.running
        }

        ProgressBar {
            Layout.fillWidth: true
            from: 0
            to: root.total
            value: root.current

            background: Rectangle {
                implicitHeight: 8
                color: root.trackColor
                border.color: root.borderColor
                border.width: 1
                radius: 4
            }

            contentItem: Item {
                implicitHeight: 8
                Rectangle {
                    width: root.total > 0 ? parent.width * (root.current / root.total) : 0
                    height: parent.height
                    radius: 4
                    color: (!root.running && root.failedCount > 0) ? root.dangerColor : root.accentColor
                    Behavior on width { NumberAnimation { duration: 180 } }
                }
            }
        }

        Text {
            text: root.current + " / " + root.total
            color: root.mutedColor
            font.pixelSize: 13
            Layout.alignment: Qt.AlignHCenter
        }

        // Tên tệp đang xử lý — trước đây có gán giá trị nhưng không hiển thị ở đâu.
        Text {
            text: root.currentFile
            visible: root.running && root.currentFile !== ""
            color: root.mutedColor
            font.pixelSize: 12
            elide: Text.ElideMiddle
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }

        // Danh sách lỗi cuối lô — thay cho việc bắn nhiều toast chồng nhau.
        Rectangle {
            visible: !root.running && root.failedCount > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 80
            color: "transparent"
            border.color: root.borderColor
            border.width: 1
            radius: 8

            ListView {
                anchors.fill: parent
                anchors.margins: 8
                clip: true
                model: root.errors
                spacing: 4
                delegate: Text {
                    width: ListView.view.width
                    text: "• " + modelData
                    color: root.dangerColor
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Item { Layout.fillWidth: true }

            Button {
                text: root.running ? "Chạy nền" : "Đóng"
                implicitHeight: 32
                leftPadding: 16; rightPadding: 16
                background: Rectangle {
                    radius: 8
                    color: parent.hovered ? Qt.rgba(root.accentColor.r, root.accentColor.g,
                                                    root.accentColor.b, 0.12) : "transparent"
                    border.width: 1
                    border.color: parent.hovered ? root.accentColor : root.borderColor
                }
                contentItem: Text {
                    text: parent.text
                    color: root.accentColor
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    var wasRunning = root.running
                    autoCloseTimer.stop()
                    root.close()
                    if (wasRunning) root.dismissedToBackground()
                }
            }
        }
    }
}
