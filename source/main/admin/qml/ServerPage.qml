import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Kết nối máy chủ: địa chỉ Worker + ADMIN_API_TOKEN, lưu vào admin-config.json cạnh exe.
ScrollView {
    id: sp
    required property var app
    contentWidth: availableWidth
    clip: true

    property string saveError: ""
    property bool saved: false
    property bool showToken: false

    ColumnLayout {
        width: sp.availableWidth
        spacing: 0

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Tk.sXl
            Layout.maximumWidth: 720
            spacing: Tk.sLg

            ColumnLayout {
                spacing: Tk.s2xs
                Text {
                    text: "Máy chủ"
                    color: Tk.ink
                    font.family: Tk.display
                    font.pixelSize: Tk.textXl
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    text: "App gọi Worker selfboothvn-api bằng token quản trị riêng. Token chỉ mở được danh sách máy và cổng nộp giấy phép — không ký được gì nếu thiếu khoá."
                    color: Tk.muted
                    font.family: Tk.body
                    font.pixelSize: Tk.textSm
                    wrapMode: Text.WordWrap
                }
            }

            // Trạng thái kết nối
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: conn.implicitHeight + Tk.sMd * 2
                radius: Tk.radiusSm
                color: sp.app.lastError !== "" ? Tk.errorSoft : sp.app.lastSync ? Tk.successSoft : Tk.paper2
                RowLayout {
                    id: conn
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Tk.sMd }
                    spacing: Tk.sSm
                    Rectangle {
                        implicitWidth: 8; implicitHeight: 8; radius: 4
                        color: sp.app.lastError !== "" ? Tk.error : sp.app.lastSync ? Tk.success : Tk.neutral
                    }
                    Text {
                        Layout.fillWidth: true
                        text: sp.app.lastError !== "" ? sp.app.lastError
                            : sp.app.lastSync ? "Kết nối được · lần cuối " + Tk.dateTime(sp.app.lastSync)
                            : "Chưa kết nối"
                        color: sp.app.lastError !== "" ? Tk.error : Tk.ink
                        font.family: Tk.body
                        font.pixelSize: Tk.textSm
                        wrapMode: Text.WordWrap
                    }
                    Btn {
                        variant: "secondary"
                        text: "Kiểm tra"
                        loading: sp.app.busy
                        onClicked: sp.app.refresh()
                    }
                }
            }

            Field {
                id: urlField
                Layout.fillWidth: true
                label: "Địa chỉ máy chủ"
                placeholderText: "https://boothme.tech"
                text: api.baseUrl
                mono: true
                hint: "Không kèm /v1 ở cuối."
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tk.sSm
                Field {
                    id: tokenField
                    Layout.fillWidth: true
                    label: "ADMIN_API_TOKEN"
                    placeholderText: api.hasToken ? "Đã có — để trống nếu không đổi" : "Dán token quản trị"
                    echoMode: sp.showToken ? TextInput.Normal : TextInput.Password
                    mono: true
                }
                Btn {
                    Layout.alignment: Qt.AlignBottom
                    Layout.bottomMargin: tokenField.hint !== "" ? 20 : 0
                    variant: "quiet"
                    text: sp.showToken ? "Ẩn" : "Hiện"
                    onClicked: sp.showToken = !sp.showToken
                }
            }

            Text {
                Layout.fillWidth: true
                visible: sp.saveError !== "" || sp.saved
                text: sp.saveError !== "" ? sp.saveError : "Đã lưu vào " + api.configPath
                color: sp.saveError !== "" ? Tk.error : Tk.success
                font.family: Tk.body
                font.pixelSize: Tk.textSm
                wrapMode: Text.WrapAnywhere
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: api.configPath
                    color: Tk.neutral
                    font.family: Tk.mono
                    font.pixelSize: Tk.textXs
                    elide: Text.ElideMiddle
                }
                Btn {
                    text: "Lưu và kết nối lại"
                    enabled: urlField.text.trim() !== ""
                    onClicked: {
                        sp.saved = false
                        const err = api.saveConfig(urlField.text, tokenField.text)
                        sp.saveError = err
                        if (err === "") {
                            sp.saved = true
                            tokenField.text = ""
                            sp.app.refresh()
                        }
                    }
                }
            }
        }
    }
}
