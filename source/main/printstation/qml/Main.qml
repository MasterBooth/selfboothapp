// Hallmark · pre-emit critique: P4 H4 E4 S4 R4 V4
// Hallmark · genre: editorial · macrostructure: Workbench · design-system: design.md · designed-as-app
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "theme"

ApplicationWindow {
    id: win
    width: 1360
    height: 860
    minimumWidth: 1120
    minimumHeight: 720
    visible: true
    title: "Booth Print Station"
    color: Theme.paper

    property var selectedJob: null
    property string selectedPrinter: printerConfig.selectedPrinter
    property string orientation: "auto"
    property int copies: Math.max(1, printerConfig.printCopies || 1)
    property string localImage: ""
    property bool printing: false
    property int printerCount: 0

    property string previewSource: localImage !== "" ? fileSource(localImage) : (selectedJob ? selectedJob.media_url : "")
    property string previewOrientation: orientation === "auto"
        ? (previewImage.sourceSize.width > previewImage.sourceSize.height && previewImage.sourceSize.height > 0 ? "landscape" : "portrait")
        : orientation
    property int previewRotation: orientation === "landscape" ? 90 : 0
    property real previewAspect: previewOrientation === "landscape" ? 1.48 : 0.68

    function fileSource(path) {
        if (!path) return ""
        if (path.indexOf("file:") === 0 || path.indexOf("http") === 0) return path
        return "file:///" + path.replace(/\\/g, "/")
    }

    function jobTitle(job) {
        if (!job) return localImage ? "Ảnh tải từ máy" : "Chọn ảnh để in"
        return job.file_name || ("Ảnh in " + job.id)
    }

    function statusLabel(job) {
        if (!job) return localImage ? "Ảnh local" : "Chưa chọn"
        if (job.status === "pending") return "Đang chờ"
        if (job.status === "claimed") return "Đã nhận"
        if (job.status === "printing") return "Đang in"
        if (job.status === "printed") return "Đã in"
        if (job.status === "failed") return "Lỗi"
        if (job.status === "cancelled") return "Đã hủy"
        return job.status || "Job"
    }

    function selectJob(job) {
        selectedJob = job
        localImage = job.local_path || ""
        copies = Math.max(1, job.copies || printerConfig.printCopies || 1)
        orientation = job.orientation || "auto"
        syncOrientationBox()
    }

    function canClaimJob(job) {
        if (!job) return false
        return job.status === "pending" || job.status === "claimed" || job.status === "printing"
    }

    function rotationForOrientation() {
        return orientation === "landscape" ? 90 : 0
    }

    function syncOrientationBox() {
        if (!orientationBox) return
        if (orientation === "portrait") orientationBox.currentIndex = 1
        else if (orientation === "landscape") orientationBox.currentIndex = 2
        else orientationBox.currentIndex = 0
    }

    function runSelectedPrint() {
        if (printing || selectedPrinter === "" || (!selectedJob && localImage === "")) return
        if (selectedJob && canClaimJob(selectedJob)) {
            printJobs.claimAndDownload(selectedJob.id)
        } else if (selectedJob) {
            printJobs.reprintAndDownload(selectedJob.id, copies, orientation, selectedPrinter)
        } else {
            printing = true
            printerManager.printFreeMode(localImage, selectedPrinter, rotationForOrientation(), copies)
        }
    }

    Component.onCompleted: {
        syncOrientationBox()
        printerManager.refreshPrinterListAsync()
        if (studioAccount.loggedIn) printJobs.start()
    }

    Connections {
        target: printerManager
        function onPrinterListReady(printers) {
            printerCount = printers.length
            printerBox.model = printers
            var idx = printers.indexOf(selectedPrinter)
            if (idx < 0 && printers.length > 0) idx = 0
            printerBox.currentIndex = idx
            selectedPrinter = idx >= 0 ? printerBox.currentText : ""
            printerStatus.text = printers.length > 0
                ? "Đã phát hiện " + printers.length + " máy in Windows"
                : "Không thấy máy in Windows nào"
        }
        function onPrinterSwitchFinished(success, message) {
            printerStatus.text = message
        }
        function onPrintFinished(success, message) {
            if (!printing) return
            printing = false
            printJobs.finishActivePrint(success, message, selectedPrinter, copies, orientation)
            statusToast.text = success ? "Đã gửi lệnh in xong" : message
            statusToast.open()
        }
    }

    Connections {
        target: printJobs
        function onJobReadyToPrint(path, jobCopies, jobOrientation) {
            localImage = path
            copies = Math.max(1, jobCopies || copies)
            orientation = jobOrientation || orientation
            syncOrientationBox()
            printing = true
            printerManager.printFreeMode(path, selectedPrinter, rotationForOrientation(), copies)
        }
        function onJobFailed(message) {
            statusToast.text = message
            statusToast.open()
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.paperTop }
            GradientStop { position: 1; color: Theme.paper }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 22
        spacing: 16

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 76
            radius: Theme.radiusXLarge
            color: Theme.surface
            border.color: Theme.border

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 22
                anchors.rightMargin: 14
                spacing: 18

                Rectangle {
                    width: 44
                    height: 44
                    radius: 22
                    color: Theme.accent
                    Text {
                        anchors.centerIn: parent
                        text: "P"
                        color: "#FFF7EF"
                        font.family: "Georgia"
                        font.pixelSize: 24
                        font.weight: Font.DemiBold
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: "Print Station"
                        color: Theme.text
                        font.family: "Georgia"
                        font.pixelSize: 28
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: studioAccount.loggedIn
                            ? studioAccount.studioName + " · " + printStationHwid
                            : "Đăng nhập đúng studio để nhận đúng ảnh khách gửi"
                        color: Theme.muted
                        font.pixelSize: 13
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 220
                    Layout.preferredHeight: 44
                    radius: Theme.radiusMedium
                    color: studioAccount.loggedIn ? Theme.accentSoft : Theme.rail
                    border.color: studioAccount.loggedIn ? Theme.accentLine : Theme.borderStrong
                    Text {
                        anchors.centerIn: parent
                        text: studioAccount.loggedIn ? "ONLINE · " + printerCount + " printers" : "CHƯA ĐĂNG NHẬP"
                        color: studioAccount.loggedIn ? Theme.accentDark : Theme.muted
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                }

                Button {
                    Layout.preferredHeight: 44
                    text: studioAccount.loggedIn ? "Đăng xuất" : "Đăng nhập"
                    onClicked: studioAccount.loggedIn ? studioAccount.logout() : loginPopup.open()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            Rectangle {
                Layout.preferredWidth: 350
                Layout.fillHeight: true
                radius: Theme.radiusXLarge
                color: Theme.surface
                border.color: Theme.border

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: "Inbox in"
                            color: Theme.text
                            font.family: "Georgia"
                            font.pixelSize: 24
                            font.weight: Font.DemiBold
                        }
                        Button {
                            text: "Quét"
                            onClicked: {
                                printerManager.refreshPrinterListAsync()
                                printJobs.refresh()
                                printJobs.refreshHistory()
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 58
                        radius: Theme.radiusMedium
                        color: Theme.cardWarm
                        border.color: Theme.border
                        Text {
                            anchors.fill: parent
                            anchors.margins: 12
                            text: printJobs.statusText
                            color: Theme.muted
                            wrapMode: Text.WordWrap
                            font.pixelSize: 13
                        }
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 10
                        model: printJobs.jobs
                        delegate: Rectangle {
                            required property var modelData
                            width: ListView.view.width
                            height: 92
                            radius: Theme.radiusLarge
                            color: selectedJob && selectedJob.id === modelData.id ? Theme.accentSoft : Theme.card
                            border.color: selectedJob && selectedJob.id === modelData.id ? Theme.accentLine : Theme.border

                            MouseArea { anchors.fill: parent; onClicked: selectJob(modelData) }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12
                                Rectangle {
                                    Layout.preferredWidth: 54
                                    Layout.fillHeight: true
                                    radius: Theme.radiusMedium
                                    color: Theme.previewSoft
                                    Text {
                                        anchors.centerIn: parent
                                        text: "PNG"
                                        color: "#F6E7DD"
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.file_name || modelData.id
                                        color: Theme.text
                                        elide: Text.ElideRight
                                        font.pixelSize: 14
                                        font.weight: Font.DemiBold
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: (modelData.copies || 1) + " bản · " + (modelData.orientation || "auto")
                                        color: Theme.muted
                                        font.pixelSize: 12
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.requested_at || ""
                                        color: Theme.faint
                                        elide: Text.ElideRight
                                        font.pixelSize: 11
                                    }
                                }
                            }
                        }

                        Label {
                            anchors.centerIn: parent
                            visible: printJobs.jobs.length === 0
                            text: studioAccount.loggedIn ? "Chưa có ảnh chờ in" : "Đăng nhập để nhận hàng chờ"
                            color: Theme.muted
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusXLarge
                color: Theme.preview
                border.color: "#4A372E"
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Text {
                                Layout.fillWidth: true
                                text: jobTitle(selectedJob)
                                color: "#FFF7EF"
                                elide: Text.ElideRight
                                font.family: "Georgia"
                                font.pixelSize: 28
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: statusLabel(selectedJob) + " · " + (orientation === "auto" ? "Auto" : orientation === "portrait" ? "Portrait" : "Landscape")
                                color: "#CDBFB5"
                                font.pixelSize: 13
                            }
                        }
                        Rectangle {
                            Layout.preferredWidth: 126
                            Layout.preferredHeight: 36
                            radius: 18
                            color: "#F6E7DD"
                            Text {
                                anchors.centerIn: parent
                                text: previewOrientation === "landscape" ? "LANDSCAPE" : "PORTRAIT"
                                color: Theme.ink
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    Item {
                        id: previewStage
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Rectangle {
                            id: printPaper
                            anchors.centerIn: parent
                            width: Math.max(120, Math.min(previewStage.width - 90, (previewStage.height - 72) * previewAspect))
                            height: Math.max(120, width / previewAspect)
                            radius: 16
                            color: "#FFFDF8"
                            border.color: "#E9D8C9"
                            clip: true

                            Behavior on width { NumberAnimation { duration: 160 } }
                            Behavior on height { NumberAnimation { duration: 160 } }

                            Image {
                                id: previewImage
                                anchors.centerIn: parent
                                width: previewRotation === 90 ? printPaper.height - 28 : printPaper.width - 28
                                height: previewRotation === 90 ? printPaper.width - 28 : printPaper.height - 28
                                source: previewSource
                                fillMode: Image.PreserveAspectFit
                                cache: false
                                rotation: previewRotation
                                transformOrigin: Item.Center
                                Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: previewSource === ""
                                text: "Ảnh in sẽ hiển thị tại đây"
                                color: Theme.faint
                                font.pixelSize: 15
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 360
                Layout.fillHeight: true
                radius: Theme.radiusXLarge
                color: Theme.surface
                border.color: Theme.border

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Text {
                        text: "Console in"
                        color: Theme.text
                        font.family: "Georgia"
                        font.pixelSize: 24
                        font.weight: Font.DemiBold
                    }

                    Label { text: "Máy in Windows"; color: Theme.muted; font.pixelSize: 12 }
                    RowLayout {
                        Layout.fillWidth: true
                        ComboBox {
                            id: printerBox
                            Layout.fillWidth: true
                            onActivated: {
                                selectedPrinter = currentText
                                printerConfig.selectedPrinter = currentText
                                printerConfig.saveGlobal()
                                printerManager.switchPrinterAsync(currentText)
                            }
                        }
                        Button {
                            text: "Scan"
                            onClicked: {
                                printerStatus.text = "Đang quét máy in Windows..."
                                printerManager.refreshPrinterListAsync()
                            }
                        }
                    }

                    Text {
                        id: printerStatus
                        Layout.fillWidth: true
                        text: "Đang quét máy in Windows..."
                        color: Theme.muted
                        wrapMode: Text.WordWrap
                        font.pixelSize: 12
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

                    Label { text: "Hướng in"; color: Theme.muted; font.pixelSize: 12 }
                    ComboBox {
                        id: orientationBox
                        Layout.fillWidth: true
                        model: [
                            { label: "Auto theo ảnh", value: "auto" },
                            { label: "Portrait", value: "portrait" },
                            { label: "Landscape", value: "landscape" }
                        ]
                        textRole: "label"
                        valueRole: "value"
                        onActivated: orientation = currentValue
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Label { text: "Số bản"; color: Theme.muted; font.pixelSize: 12 }
                            SpinBox {
                                Layout.fillWidth: true
                                from: 1
                                to: 10
                                value: copies
                                onValueModified: copies = value
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Label { text: "Nguồn ảnh"; color: Theme.muted; font.pixelSize: 12 }
                            Button {
                                Layout.fillWidth: true
                                text: "Tải ảnh"
                                onClicked: fileDialog.open()
                            }
                        }
                    }

                    Button {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 54
                        text: printing ? "Đang in..." : (selectedJob && !canClaimJob(selectedJob) ? "In lại ảnh này" : "In ảnh đang chọn")
                        enabled: !printing && selectedPrinter !== "" && (selectedJob || localImage !== "")
                        onClicked: runSelectedPrint()
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: "Lịch sử"
                            color: Theme.text
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                        }
                        Button { text: "Tải lại"; onClicked: printJobs.refreshHistory() }
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 8
                        model: printJobs.history
                        delegate: Rectangle {
                            required property var modelData
                            width: ListView.view.width
                            height: 64
                            radius: Theme.radiusMedium
                            color: Theme.card
                            border.color: Theme.border
                            MouseArea { anchors.fill: parent; onClicked: selectJob(modelData) }
                            Column {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 4
                                Text {
                                    text: modelData.file_name || modelData.id
                                    color: Theme.text
                                    elide: Text.ElideRight
                                    width: parent.width
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    text: statusLabel(modelData) + " · " + (modelData.printed_at || modelData.failed_at || modelData.requested_at || "")
                                    color: Theme.muted
                                    elide: Text.ElideRight
                                    width: parent.width
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    FileDialog {
        id: fileDialog
        title: "Chọn ảnh để in"
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.webp)"]
        onAccepted: {
            var path = selectedFile.toString()
            if (path.indexOf("file:///") === 0) path = decodeURIComponent(path.substring(8))
            localImage = path
            selectedJob = null
        }
    }

    Popup {
        id: loginPopup
        modal: true
        anchors.centerIn: parent
        width: 430
        padding: 22
        background: Rectangle { color: Theme.surface; radius: Theme.radiusXLarge; border.color: Theme.border }

        ColumnLayout {
            width: parent.width
            spacing: 12
            Text {
                text: "Đăng nhập studio"
                color: Theme.text
                font.family: "Georgia"
                font.pixelSize: 26
                font.weight: Font.DemiBold
            }
            TextField { id: emailField; Layout.fillWidth: true; placeholderText: "Email studio" }
            TextField { id: passwordField; Layout.fillWidth: true; placeholderText: "Mật khẩu"; echoMode: TextInput.Password }
            Text { id: loginError; Layout.fillWidth: true; color: Theme.danger; wrapMode: Text.WordWrap; text: "" }
            RowLayout {
                Layout.fillWidth: true
                Button { text: "Hủy"; onClicked: loginPopup.close() }
                Item { Layout.fillWidth: true }
                Button {
                    text: studioAccount.busy ? "Đang đăng nhập..." : "Đăng nhập"
                    enabled: !studioAccount.busy
                    onClicked: {
                        loginError.text = ""
                        studioAccount.login(emailField.text, passwordField.text)
                    }
                }
            }
        }
    }

    Connections {
        target: studioAccount
        function onSignedIn() {
            loginPopup.close()
            printerManager.refreshPrinterListAsync()
            printJobs.start()
        }
        function onAuthFailed(message) { loginError.text = message }
        function onSignedOut() {
            printJobs.stop()
            printJobs.refresh()
            selectedJob = null
            localImage = ""
        }
    }

    Popup {
        id: statusToast
        property alias text: toastText.text
        x: parent.width - width - 28
        y: 28
        width: 380
        padding: 14
        background: Rectangle { color: Theme.ink; radius: Theme.radiusMedium }
        Text { id: toastText; color: Theme.paper; width: parent.width; wrapMode: Text.WordWrap }
        Timer { interval: 3200; running: statusToast.visible; onTriggered: statusToast.close() }
    }
}
