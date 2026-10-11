import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Khoá ký: khoá công khai cần dán vào mã nguồn + vị trí tệp khoá cần sao lưu.
ScrollView {
    id: kp
    required property var app
    contentWidth: availableWidth
    clip: true

    ColumnLayout {
        width: kp.availableWidth
        spacing: 0

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Tk.sXl
            Layout.maximumWidth: 820
            spacing: Tk.sLg

            ColumnLayout {
                spacing: Tk.s2xs
                Text {
                    text: "Khoá ký"
                    color: Tk.ink
                    font.family: Tk.display
                    font.pixelSize: Tk.textXl
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    text: "Máy này giữ khoá private duy nhất của hệ thống, mã hoá bằng mật khẩu. Máy booth và máy chủ chỉ có khoá công khai nên không tự tạo được giấy phép."
                    color: Tk.muted
                    font.family: Tk.body
                    font.pixelSize: Tk.textSm
                    wrapMode: Text.WordWrap
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Tk.sLg
                rowSpacing: Tk.sMd
                Info { label: "Mã khoá (kid)"; value: signer.keyId; mono: true }
                Info { label: "Trạng thái"; value: signer.unlocked ? "Đang mở — khoá nằm trong bộ nhớ" : "Đã khoá sổ" }
            }

            CopyBlock {
                label: "Khoá công khai"
                value: signer.publicKeyHex
            }

            CopyBlock {
                label: "Dán vào src/backend/LicenseManager.cpp → kPublicKeys"
                value: signer.unlocked ? signer.cppConstantLine() : ""
            }

            CopyBlock {
                label: "Dán vào cloudflare/selfboothvn-api/wrangler.toml → [vars]"
                value: signer.unlocked ? signer.wranglerVarLine() : ""
            }

            // Sao lưu
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: backup.implicitHeight + Tk.sLg * 2
                radius: Tk.radiusLg
                color: Tk.errorSoft
                ColumnLayout {
                    id: backup
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: Tk.sLg }
                    spacing: Tk.sSm
                    Text {
                        text: "Sao lưu tệp khoá"
                        color: Tk.error
                        font.family: Tk.display
                        font.pixelSize: Tk.textLg
                        font.weight: Font.DemiBold
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Mất tệp này hoặc quên mật khẩu thì không gia hạn, thu hồi được máy nào đã cấp phép. Chép tệp sang nơi an toàn (USB, ổ mã hoá), không gửi qua chat."
                        color: Tk.ink
                        font.family: Tk.body
                        font.pixelSize: Tk.textSm
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        Layout.fillWidth: true
                        text: signer.keyFilePath
                        color: Tk.muted
                        font.family: Tk.mono
                        font.pixelSize: Tk.textXs
                        wrapMode: Text.WrapAnywhere
                    }
                    RowLayout {
                        spacing: Tk.sSm
                        Btn {
                            variant: "secondary"
                            text: "Mở thư mục chứa khoá"
                            onClicked: Qt.openUrlExternally("file:///" + signer.keyFilePath.replace(/[\\\/][^\\\/]*$/, ""))
                        }
                        Btn {
                            variant: "quiet"
                            text: "Chép đường dẫn"
                            onClicked: kp.app.copy(signer.keyFilePath, "Đã chép đường dẫn tệp khoá")
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Btn {
                    variant: "secondary"
                    text: "Khoá sổ ngay"
                    onClicked: signer.lock()
                }
            }
        }
    }

    component Info: ColumnLayout {
        id: info
        property string label: ""
        property string value: ""
        property bool mono: false
        Layout.fillWidth: true
        spacing: 2
        Text { text: info.label; color: Tk.neutral; font.family: Tk.body; font.pixelSize: Tk.textXs }
        Text {
            text: info.value
            color: Tk.ink
            font.family: info.mono ? Tk.mono : Tk.body
            font.pixelSize: Tk.textSm
        }
    }

    component CopyBlock: ColumnLayout {
        id: cb
        property string label: ""
        property string value: ""
        Layout.fillWidth: true
        spacing: Tk.sXs
        Text { text: cb.label; color: Tk.muted; font.family: Tk.body; font.pixelSize: Tk.textXs; font.weight: Font.DemiBold }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Math.max(Tk.control + 8, codeText.implicitHeight + Tk.sSm * 2)
            radius: Tk.radiusSm
            color: Tk.paper2
            border.width: 1
            border.color: Tk.paper3
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Tk.sMd
                anchors.rightMargin: Tk.sXs
                spacing: Tk.sSm
                TextEdit {
                    id: codeText
                    Layout.fillWidth: true
                    text: cb.value || "—"
                    readOnly: true
                    selectByMouse: true
                    color: Tk.ink
                    selectionColor: Tk.accent
                    selectedTextColor: Tk.accentInk
                    font.family: Tk.mono
                    font.pixelSize: Tk.textXs + 1
                    wrapMode: TextEdit.WrapAnywhere
                }
                Btn {
                    variant: "secondary"
                    text: "Sao chép"
                    enabled: cb.value !== ""
                    onClicked: kp.app.copy(cb.value, "Đã chép")
                }
            }
        }
    }
}
