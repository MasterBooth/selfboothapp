import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../theme"

Item {
    id: root

    property string sessionId: ""
    property string bgOverride: ""

    signal nextSession()
    signal backClicked()

    readonly property string selfboothBaseUrl: "https://boothos-client.vercel.app"
    property string editorBaseUrl: eventManager.getAppSetting("selfbooth_editor_base_url", "https://boothme-vn.vercel.app")
    property bool isPortrait: eventManager.getAppSetting("selfbooth_orientation", "landscape") === "portrait"
    // Bật "Chọn frame sau khi chụp" → khách đã ghép ảnh tại booth, chỉ cần QR xem ảnh.
    // Tắt → hiện thêm QR editor để khách tự ghép ảnh với khung trên web.
    property bool frameFlowEnabled: eventManager.getAppSetting("selfbooth_frame_enabled", "false") === "true"
    readonly property bool showEditorQr: !frameFlowEnabled

    property string galleryUrl: {
        var hwid = machineAuth.hwid
        if (hwid && hwid !== "" && root.sessionId !== "")
            return root.selfboothBaseUrl + "/selfbooth/" + hwid + "/" + root.sessionId
        return ""
    }

    property string editorUrl: {
        var hwid = machineAuth.hwid
        var base = root.editorBaseUrl
        while (base.length > 0 && base.charAt(base.length - 1) === "/")
            base = base.slice(0, -1)
        if (hwid && hwid !== "" && root.sessionId !== "" && base !== "")
            return base + "/selfbooth/" + hwid + "/" + root.sessionId
        return ""
    }

    property string galleryQrSource: root.galleryUrl !== "" ? ("image://qr/" + encodeURIComponent(root.galleryUrl)) : ""
    property string editorQrSource: root.editorUrl !== "" ? ("image://qr/" + encodeURIComponent(root.editorUrl)) : ""
    property string _bgQr: bgOverride !== "" ? bgOverride : eventManager.getAppSetting("selfbooth_bg_qr", "")

    Connections {
        target: eventManager
        function onAppSettingChanged(key, value) {
            if (key === "selfbooth_orientation")
                root.isPortrait = (value === "portrait")
            if (key === "selfbooth_editor_base_url")
                root.editorBaseUrl = value
            if (key === "selfbooth_frame_enabled")
                root.frameFlowEnabled = (value === "true")
        }
    }

    component QrCard: Rectangle {
        id: card
        property string title: ""
        property string subtitle: ""
        property string targetUrl: ""
        property string qrSource: ""
        property int qrSize: 260

        width: qrSize + 36
        height: qrSize + 122
        color: "#f8fafc"
        radius: 18
        border.color: "#dbe3ef"
        border.width: 2

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            Text {
                text: card.title
                color: "#111827"
                font.pixelSize: 20
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                text: card.subtitle
                color: "#4b5563"
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                maximumLineCount: 2
            }

            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: card.qrSize
                Layout.preferredHeight: card.qrSize

                Image {
                    id: qrImage
                    anchors.fill: parent
                    source: card.qrSource
                    fillMode: Image.PreserveAspectFit
                    smooth: false
                    cache: false
                    onStatusChanged: if (status === Image.Error) console.error("[QRCodeSelf] Failed to generate QR for", card.targetUrl)
                }

                BusyIndicator {
                    anchors.centerIn: parent
                    running: qrImage.status === Image.Loading
                    visible: running
                }

                Text {
                    anchors.centerIn: parent
                    text: "Waiting..."
                    color: "#667085"
                    font.pixelSize: 16
                    visible: card.qrSource === "" && qrImage.status !== Image.Loading
                }
            }

            Text {
                text: card.targetUrl
                color: "#2563eb"
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                elide: Text.ElideMiddle
                visible: card.targetUrl !== ""
            }
        }
    }

    Image {
        anchors.fill: parent
        source: root._bgQr !== "" ? "file:///" + root._bgQr : ""
        fillMode: Image.PreserveAspectCrop
        visible: root._bgQr !== ""
    }

    Rectangle {
        anchors.fill: parent
        visible: root._bgQr === ""
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: "#0d0f1e" }
            GradientStop { position: 1.0; color: "#06080f" }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.isPortrait ? 36 : 48
        spacing: 16

        Text {
            text: "Anh cua ban da san sang"
            color: "white"
            font.pixelSize: root.isPortrait ? 36 : 44
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }

        Text {
            text: root.showEditorQr
                  ? "Quet QR de xem anh goc hoac ghep anh voi khung va filter mau"
                  : "Quet QR de xem va tai anh cua ban"
            color: "#b9c6e4"
            font.pixelSize: root.isPortrait ? 17 : 20
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 28
            visible: !root.isPortrait

            QrCard {
                title: "Xem tat ca anh"
                subtitle: "Mo gallery va tai anh goc"
                targetUrl: root.galleryUrl
                qrSource: root.galleryQrSource
                qrSize: 260
            }

            QrCard {
                visible: root.showEditorQr
                title: "Ghep anh voi khung"
                subtitle: "Chon frame, anh va filter mau"
                targetUrl: root.editorUrl
                qrSource: root.editorQrSource
                qrSize: 260
            }

            ColumnLayout {
                Layout.preferredWidth: 360
                spacing: 14

                Repeater {
                    model: root.showEditorQr
                           ? [
                               { num: "1", text: "Mo camera dien thoai" },
                               { num: "2", text: "Quet QR xem anh hoac ghep anh voi khung" },
                               { num: "3", text: "Tai anh cuoi ve may" }
                             ]
                           : [
                               { num: "1", text: "Mo camera dien thoai" },
                               { num: "2", text: "Quet QR de mo gallery" },
                               { num: "3", text: "Tai anh ve may" }
                             ]
                    delegate: RowLayout {
                        spacing: 12
                        Layout.fillWidth: true
                        Rectangle {
                            width: 42
                            height: 42
                            radius: 21
                            color: "#1e3a8a"
                            Text {
                                anchors.centerIn: parent
                                text: modelData.num
                                color: "white"
                                font.pixelSize: 18
                                font.bold: true
                            }
                        }
                        Text {
                            text: modelData.text
                            color: Theme.textMuted
                            font.pixelSize: 17
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                LinkBar { label: "Gallery"; url: root.galleryUrl }
                LinkBar { label: "Editor"; url: root.editorUrl; visible: root.showEditorQr && root.editorUrl !== "" }
                UploadNotice {}
            }
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 18
            visible: root.isPortrait

            QrCard {
                title: "Xem tat ca anh"
                subtitle: "Mo gallery va tai anh goc"
                targetUrl: root.galleryUrl
                qrSource: root.galleryQrSource
                qrSize: 300
            }

            QrCard {
                visible: root.showEditorQr
                title: "Ghep anh voi khung"
                subtitle: "Chon frame, anh va filter mau"
                targetUrl: root.editorUrl
                qrSource: root.editorQrSource
                qrSize: 300
            }

            LinkBar { label: "Gallery"; url: root.galleryUrl; Layout.preferredWidth: 640 }
            LinkBar { label: "Editor"; url: root.editorUrl; Layout.preferredWidth: 640; visible: root.showEditorQr && root.editorUrl !== "" }
            UploadNotice { Layout.preferredWidth: 640 }
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 32

            Rectangle {
                width: 220
                height: 64
                radius: 32
                color: backBtnArea.containsMouse ? "#2a2d3e" : "#1e2030"
                border.color: "#3a3d55"
                border.width: 2

                Text {
                    anchors.centerIn: parent
                    text: "Quay lai"
                    color: Theme.textMuted
                    font.pixelSize: 18
                    font.bold: true
                }

                MouseArea {
                    id: backBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.backClicked()
                }
            }

            Rectangle {
                width: 300
                height: 64
                radius: 32
                color: nextBtnArea.containsMouse ? "#16a34a" : "#15803d"

                SequentialAnimation on scale {
                    running: true
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 1.04; duration: 900; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 1.04; to: 1.0; duration: 900; easing.type: Easing.InOutQuad }
                }

                Text {
                    anchors.centerIn: parent
                    text: "Khach tiep theo"
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                }

                MouseArea {
                    id: nextBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.nextSession()
                }
            }
        }
    }

    component LinkBar: Rectangle {
        id: linkBar
        property string label: ""
        property string url: ""

        Layout.fillWidth: true
        height: 50
        radius: 8
        color: "#0d1929"
        border.color: "#1e3a8a"
        border.width: 1
        visible: url !== ""

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Text {
                text: linkBar.label
                color: "#9cc7ff"
                font.pixelSize: 12
                font.bold: true
            }

            Text {
                text: linkBar.url
                color: "#60a5fa"
                font.pixelSize: 11
                elide: Text.ElideMiddle
                Layout.fillWidth: true
            }
        }
    }

    component UploadNotice: Rectangle {
        Layout.fillWidth: true
        height: 50
        radius: 8
        color: "#0d2917"
        border.color: "#166534"
        border.width: 1

        Text {
            anchors.fill: parent
            anchors.margins: 12
            text: "Anh dang duoc tai len, co the mat vai giay."
            color: "#86efac"
            font.pixelSize: 13
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
        }
    }
}
