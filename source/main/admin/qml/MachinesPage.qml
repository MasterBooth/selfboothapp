import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Workbench: tiêu đề + tìm kiếm ở trên, danh sách máy bên trái, bảng chi tiết bên phải.
Item {
    id: page
    required property var app

    readonly property string title: app.view === "pending" ? "Chờ duyệt"
                                  : app.view === "licensed" ? "Đã kích hoạt"
                                  : app.view === "revoked" ? "Đã thu hồi" : "Tất cả máy"
    readonly property string emptyText: app.search !== "" ? "Không có máy nào khớp “" + app.search + "”."
        : app.view === "pending" ? "Chưa có máy nào chờ duyệt. Máy sẽ hiện ở đây sau khi khách đăng nhập studio trên app booth."
        : app.view === "licensed" ? "Chưa có máy nào được kích hoạt."
        : app.view === "revoked" ? "Chưa thu hồi giấy phép nào."
        : "Chưa có máy nào báo danh với máy chủ."

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Đầu trang ────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Tk.sXl
            Layout.rightMargin: Tk.sXl
            Layout.topMargin: Tk.sLg
            Layout.bottomMargin: Tk.sMd
            spacing: Tk.sMd

            ColumnLayout {
                spacing: 2
                Text {
                    text: page.title
                    color: Tk.ink
                    font.family: Tk.display
                    font.pixelSize: Tk.textXl
                    font.weight: Font.DemiBold
                }
                Text {
                    text: page.app.visibleMachines.length + " máy"
                          + (page.app.lastSync ? " · cập nhật " + Tk.relative(page.app.lastSync) : "")
                    color: Tk.neutral
                    font.family: Tk.body
                    font.pixelSize: Tk.textXs
                }
            }

            Item { Layout.fillWidth: true }

            TextField {
                id: search
                Layout.preferredWidth: 320
                implicitHeight: Tk.control
                leftPadding: Tk.sMd
                rightPadding: Tk.sMd
                placeholderText: "Tìm studio, email hoặc mã máy"
                placeholderTextColor: Tk.neutral
                color: Tk.ink
                font.family: Tk.body
                font.pixelSize: Tk.textSm
                text: page.app.search
                onTextEdited: page.app.search = text
                Keys.onEscapePressed: { text = ""; page.app.search = "" }
                background: Rectangle {
                    radius: Tk.radiusPill
                    color: Tk.surface
                    border.width: search.activeFocus ? 2 : 1
                    border.color: search.activeFocus ? Tk.focus : Tk.rule
                }
            }

            Btn {
                text: "Tải lại"
                variant: "secondary"
                loading: page.app.busy
                onClicked: page.app.refresh()
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Tk.rule }

        // ── Danh sách + chi tiết ─────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Danh sách
            Rectangle {
                Layout.preferredWidth: Math.max(340, Math.min(440, page.width * 0.36))
                Layout.fillHeight: true
                color: Tk.paper

                ListView {
                    id: list
                    anchors.fill: parent
                    clip: true
                    model: page.app.visibleMachines
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    delegate: AbstractButton {
                        id: row
                        required property var modelData
                        readonly property bool isSel: page.app.selectedHwid === modelData.hwid
                        width: ListView.view.width
                        height: 76
                        hoverEnabled: true
                        focusPolicy: Qt.StrongFocus
                        onClicked: page.app.select(modelData.hwid)

                        background: Rectangle {
                            color: row.isSel ? Tk.surface : row.hovered ? Tk.paper2 : "transparent"
                            Rectangle {
                                visible: row.isSel
                                width: 3
                                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                color: Tk.accent
                            }
                            Rectangle {
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: Tk.sLg }
                                height: 1
                                color: Tk.paper3
                            }
                            Rectangle {
                                anchors.fill: parent; anchors.margins: 2
                                color: "transparent"; border.width: 2; border.color: Tk.focus
                                visible: row.visualFocus
                            }
                        }

                        contentItem: RowLayout {
                            spacing: Tk.sSm
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: Tk.sLg - 8
                                spacing: 3
                                Text {
                                    Layout.fillWidth: true
                                    text: row.modelData.studio_name || "Chưa gắn studio"
                                    color: Tk.ink
                                    font.family: Tk.body
                                    font.pixelSize: Tk.textSm + 1
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: row.modelData.hwid
                                    color: Tk.muted
                                    font.family: Tk.mono
                                    font.pixelSize: Tk.textXs
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: row.modelData.state === "licensed"
                                          ? Tk.tierLabel(row.modelData.device_tier) + " · hạn " + Tk.date(row.modelData.not_after)
                                          : row.modelData.state === "revoked"
                                            ? "Thu hồi " + Tk.relative(row.modelData.revoked_at)
                                            : "Yêu cầu " + Tk.relative(row.modelData.request_updated_at)
                                    color: Tk.neutral
                                    font.family: Tk.body
                                    font.pixelSize: Tk.textXs
                                    elide: Text.ElideRight
                                }
                            }
                            ColumnLayout {
                                Layout.rightMargin: Tk.sMd
                                Layout.alignment: Qt.AlignVCenter
                                spacing: Tk.s2xs
                                StatusPill { Layout.alignment: Qt.AlignRight; machineState: row.modelData.state }
                                Text {
                                    Layout.alignment: Qt.AlignRight
                                    visible: !!row.modelData.otp
                                    text: "OTP đang mở"
                                    color: Tk.accent
                                    font.family: Tk.body
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - Tk.sXl * 2
                    visible: list.count === 0
                    text: page.emptyText
                    color: Tk.neutral
                    font.family: Tk.body
                    font.pixelSize: Tk.textSm
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    lineHeight: 1.3
                }

                Rectangle {
                    anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
                    width: 1
                    color: Tk.rule
                }
            }

            // Chi tiết
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0

                MachineDetail {
                    anchors.fill: parent
                    visible: page.app.selected !== null
                    app: page.app
                    machine: page.app.selected
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - Tk.sXl * 2, 380)
                    visible: page.app.selected === null
                    spacing: Tk.sXs
                    Text {
                        Layout.fillWidth: true
                        text: "Chọn một máy"
                        color: Tk.ink
                        font.family: Tk.display
                        font.pixelSize: Tk.textLg
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Chi tiết giấy phép, mã kích hoạt và thao tác cấp, gia hạn, thu hồi hiện ở đây."
                        color: Tk.neutral
                        font.family: Tk.body
                        font.pixelSize: Tk.textSm
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
