import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../components"
import "../../theme"

Item {
    id: root
    width: Window.window ? Window.window._designW : 1920
    height: Window.window ? Window.window._designH : 1080
    readonly property bool portrait: Window.window && Window.window.isPortrait

    // Properties
    property var photos: []
    property string collagePath: ""
    property string displayPath: ""   // ảnh hiển thị UI (strip no-cut); fallback sang collagePath nếu rỗng
    property string _displaySource: displayPath !== "" ? displayPath : collagePath
    property int selectedIndex: -1
    property int eventId: -1
    property var eventData: null
    property string sessionId: ""
    property string hwid: ""

    property string qrImageUrl: (sessionId !== "" && hwid !== "")
        ? ("image://qr/" + encodeURIComponent(s3Uploader.buildSessionUrl(hwid, eventId, sessionId)))
        : ""

    property bool _prePaymentPrintRequested: false
    property bool _paymentEnabled: eventManager.getAppSetting("payment_enabled", "false") === "true"
    property string backgroundImagePath: {
        var s = eventManager.getAppSetting("result_bg_image", "")
        return s !== "" ? s : "qrc:/assets/bg/result.png"
    }
    property int resultCountdownTime: parseInt(eventManager.getAppSetting("result_screen_countdown", "30")) || 30

    Component.onCompleted: {
        // Đếm ngược tự chuyển lượt mới đã chuyển sang WaitingResults (sau khi In).
        // ResultScreen chỉ chờ người dùng bấm In.
    }

    // Print-related properties
    property bool isPrinting: false
    property string printStatus: ""
    property string printError: ""
    property bool lastPrintCutMode: false
    property int lastPrintPhotos: 0
    property bool pendingPrintCutMode: false
    property int pendingPrintPhotos: 1
    property string _lastAutoScanPath: ""   // path đã xử lý gửi cho printer, dùng lại khi auto-scan
    property bool _autoScanActive: false    // đang trong quá trình auto-scan
    property bool _awaitingQr: false        // đang chờ applyQrOverlayAsync trả kết quả

    // Payment flow: khi đã thanh toán từ trước (pre-payment), truyền vào để bỏ qua hỏi lại
    property bool prePaymentDone: false   // true = đã thanh toán ở bước trước khi chụp
    property bool prePaymentCutMode: false
    property int  prePaymentCopies: 1

    signal finished()
    signal qrCodeClicked()
    signal backClicked()
    // X = thoát lượt → BoothSession đưa về CutModeScreen (lượt mới).
    signal closeClicked()

    // Độ mờ nút điều khiển (⚙ / ✕) — 1.0 bình thường, 0.25 mờ, 0.0 tàng hình.
    // Dùng opacity nên nút vẫn bấm được ở đúng vị trí cũ dù không nhìn thấy.
    readonly property real _chromeOpacity: Window.window ? Window.window.appChromeOpacity : 1.0
    // Phát khi người dùng bấm In → BoothSession chuyển ngay sang WaitingResults.
    signal printRequested()

    // Gate all Infinite animations — pause when this screen is not the active StackView item
    property bool _isActiveScreen: StackView.status === StackView.Active
                                || StackView.status === StackView.Activating

    // Derived theme background — direct expression so QML tracks appBgColor changes
    property color _themeBg: Window.window ? Window.window.appBgColor : "#000000"
    property color _themeText: Window.window ? Window.window.appTextColor : "#FFFFFF"
    property color _themeSurface: Window.window ? Window.window.appSurfaceColor : "#121212"
    property color _themeField: Window.window ? Window.window.appFieldColor : "#1A1A1A"
    property color _themeBorder: Window.window ? Window.window.appBorderColor : "#3A3A3A"
    property color _themeMutedText: Qt.rgba(_themeText.r, _themeText.g, _themeText.b, 0.65)

    // Called async from BoothSession when autoCut preview strip is ready
    function updateDisplayPath(newPath) {
        if (newPath && newPath !== "")
            root.displayPath = newPath
    }

    // Convert local Windows path → file:/// URL for QML Image
    function toUrl(path) {
        if (!path || path === "") return ""
        if (path.startsWith("file:")) return path
        return "file:///" + path.replace(/\\/g, "/")
    }

    function preparePrePaymentPrint() {
        if (!root.prePaymentDone) return true

        if (!root.collagePath || root.collagePath === "") {
            root.printError = "Image path is empty"
            return false
        }

        root.pendingPrintCutMode = root.prePaymentCutMode
        var sheets = root.prePaymentCopies
        root.pendingPrintPhotos = root.prePaymentCutMode
            ? sheets * printOptionsDialog.photosPerSheet
            : sheets
        return true
    }

    function ensurePrePaymentPrinted() {
        if (!root.prePaymentDone || (root._prePaymentPrintRequested && root.printError === ""))
            return true

        if (!root.preparePrePaymentPrint())
            return false

        root.executePrint()
        return true
    }

    function executePrint() {
        root._autoScanActive = false   // reset mỗi lần bắt đầu in mới
        root._awaitingQr = false
        var cutMode = root.pendingPrintCutMode
        var photos = root.pendingPrintPhotos
        var imagePath = root.collagePath

        console.log("[ResultScreen] executePrint: collagePath=" + root.collagePath + " | displayPath=" + root.displayPath + " | cutMode=" + cutMode + " | photos=" + photos)

        if (!imagePath || imagePath === "") {
            root.printError = "Image path is empty"
            printOptionsDialog.close()
            return
        }

        // Bấm In → chuyển NGAY sang WaitingResults; việc in tiếp tục chạy nền.
        printOptionsDialog.close()
        root.printRequested()

        if (root.prePaymentDone)
            root._prePaymentPrintRequested = true

        root.isPrinting = true
        root.printError = ""
        root.printStatus = "Processing..."
        root.lastPrintCutMode = cutMode
        root.lastPrintPhotos = photos

        // Apply QR overlay if enabled — chạy async (tải QR qua mạng), không treo UI.
        // Kết quả về qua signal eventManager.qrOverlayReady → onQrOverlayReady().
        if (overlayArea.showQrInPrint && overlayArea.qrUrlPath !== "") {
            if (!overlayArea.hasUsablePrintPosition())
                overlayArea.calculateInitialPosition()

            var nx = overlayArea.printNormalizedX()
            var ny = overlayArea.printNormalizedY()
            var nw = overlayArea.printNormalizedW()
            var nh = overlayArea.printNormalizedH()
            console.log("[ResultScreen] QR print normalized rect:", nx, ny, nw, nh,
                        "box=", qrBox.x, qrBox.y, qrBox.width, qrBox.height,
                        "strip=", overlayArea.stripW, overlayArea.stripH,
                        "userAdjusted=", qrBox.userAdjusted)

            root._awaitingQr = true

            var stripSource = root.displayPath !== "" ? root.displayPath : ""
            var hasSingleStrip = stripSource !== "" && stripSource !== root.collagePath
            if (cutMode && hasSingleStrip) {
                eventManager.applyQrOverlayRectAsync(stripSource, overlayArea.qrUrlPath, "cutstrip", nx, ny, nw, nh, root.eventId)
            } else {
                eventManager.applyQrOverlayRectAsync(imagePath, overlayArea.qrUrlPath, "single", nx, ny, nw, nh, root.eventId)
            }
            // Tiếp tục trong onQrOverlayReady()
        } else {
            root._sendToPrinter(imagePath)
        }

        printOptionsDialog.close()
    }

    // Làm sạch path + gửi lệnh in. Dùng chung cho cả nhánh có/không QR overlay.
    function _sendToPrinter(imagePath) {
        var cleanPath = imagePath.toString().replace(/^(file:\/{3})|(file:)/, "")
        if (Qt.platform.os === "windows") cleanPath = cleanPath.replace(/^(file:\/\/\/)/, "")
        cleanPath = decodeURIComponent(cleanPath)

        console.log("[ResultScreen] Sending to printer: cleanPath=" + cleanPath)
        root._lastAutoScanPath = cleanPath   // lưu lại để auto-scan dùng lại nếu cần
        var paperSize = root.eventData && root.eventData.paperSize ? root.eventData.paperSize : "6x4"
        printerManager.printImageWithSettings(cleanPath, root.lastPrintPhotos, paperSize, 300,
                                              root.lastPrintCutMode, false)
    }

    // QR overlay async hoàn thành → gửi in.
    // resultPath đã là ảnh sẵn sàng in: với mode "qw410cut" việc ghép canvas cắt
    // đã thực hiện trong worker thread của EventManager nên KHÔNG còn lệnh đồng bộ
    // nào chặn UI ở đây.
    Connections {
        target: eventManager
        function onQrOverlayReady(resultPath) {
            if (!root._awaitingQr) return   // không phải request của màn hình này
            root._awaitingQr = false
            root._sendToPrinter(resultPath)
        }
    }

    // Background
    BackgroundMedia {
        anchors.fill: parent
        sourcePath: root.backgroundImagePath
        visible: root.backgroundImagePath !== ""
    }

    Rectangle {
        anchors.fill: parent
        color: root.backgroundImagePath !== "" ? "transparent" : root._themeBg
    }

    property string uploadedUrl: ""
    property bool isUploading: false
    property string uploadError: ""

    Connections {
        target: s3Uploader
        function onUploadStarted() {
            console.log("Upload started...")
            root.isUploading = true
            root.uploadError = ""
        }
        function onUploadFinished(url) {
            console.log("Upload finished: " + url)
            root.isUploading = false
            root.uploadedUrl = url
        }
        function onUploadError(msg) {
            console.log("Upload error: " + msg)
            root.isUploading = false
            root.uploadError = msg
        }
    }

    Connections {
        target: printerManager

        function onPrintFinished(success, message) {
            console.log("Print finished - Success:", success, "Message:", message)

            if (!success && !root._autoScanActive) {
                // Lần in đầu thất bại → kích hoạt auto-scan, không hiện lỗi ngay
                console.log("[ResultScreen] Print failed, starting auto-scan...")
                root._autoScanActive = true
                // tryPrintOnePrinterSilent loop theo số tờ, không tự convert như printImageWithSettings
                // → phải tính số tờ trước khi truyền vào autoFindAndPrint
                var sheetsToSend = root.pendingPrintCutMode
                    ? Math.ceil(root.pendingPrintPhotos / printOptionsDialog.photosPerSheet)
                    : root.pendingPrintPhotos
                console.log("[ResultScreen] autoFindAndPrint sheets=", sheetsToSend,
                            "(photos=", root.pendingPrintPhotos, "cutMode=", root.pendingPrintCutMode, ")")
                printerManager.autoFindAndPrint(
                    root._lastAutoScanPath,
                    sheetsToSend,
                    root.pendingPrintCutMode,
                    300)
                return
            }

            // Kết quả cuối cùng (từ auto-scan hoặc in bình thường)
            root.isPrinting = false
            root._autoScanActive = false

            // Đóng popup sau 1.5s để "Đang in ảnh..." hiển thị trước khi tắt
            autoScanPopupCloseTimer.start()

            if (success) {
                root.printStatus = message
                root.printError = ""
                if (root.eventId > 0 && root.lastPrintPhotos > 0) {
                    eventManager.incrementPrintCount(root.eventId, root.lastPrintPhotos, root.lastPrintCutMode)
                }
                printSuccessTimer.start()
            } else {
                root.printError = message
                root.printStatus = ""
            }
        }

        function onErrorOccurred(error) {
            console.log("Printer error:", error)
            root.isPrinting = false
            root._autoScanActive = false
            autoScanPopup.visible = false
            root.printError = error
            root.printStatus = ""
        }

        function onAutoPrintScanStarted() {
            autoScanPopup.visible = true
            autoScanStatusText.text = "Đang quét máy in..."
        }

        function onAutoPrintScanProgress(message) {
            autoScanStatusText.text = message
        }

        function onAutoPrintScanFinished(success, printerName) {
            if (success) {
                // Giữ popup, đổi trạng thái → "Đang in ảnh..."
                // printFinished sẽ emit ngay sau → popup đóng sau 1.5s qua timer
                autoScanStatusText.text = "Đang in ảnh..."
            } else {
                autoScanPopup.visible = false
            }
        }
    }

    Timer {
        id: printSuccessTimer
        interval: 3000
        running: false
        onTriggered: {
            root.printStatus = ""
        }
    }

    Timer {
        id: autoScanPopupCloseTimer
        interval: 1500
        repeat: false
        onTriggered: autoScanPopup.visible = false
    }

    Timer {
        id: resultCountdownTimer
        interval: 1000
        repeat: true
        running: false
        onTriggered: {
            root.resultCountdownTime--
            if (root.resultCountdownTime <= 0) {
                stop()
                qrConfirmDialog.visible = false
                if (!root.ensurePrePaymentPrinted())
                    return
                root.finished()
            }
        }
    }

    // Upload handled in BoothSession.qml with session folder structure
    // onCollagePathChanged removed to prevent duplicate upload to root

    // ── Main layout: header on top, collage + button panel below ──
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 0

        // Header removed to give full height to body

        // Body: collage (left) + button panel (right)
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // ── Collage image – fills area to the left of the button panel ──
            Rectangle {
                id: imagePane
                anchors {
                    left:   parent.left
                    top:    parent.top
                    bottom: parent.bottom
                    right:  buttonPanel.left
                }
                anchors.leftMargin:   root.portrait ? 12 : 24
                anchors.topMargin:    root.portrait ? 12 : 16
                anchors.bottomMargin: root.portrait ? 12 : 24
                anchors.rightMargin:  root.portrait ? 10 : 16
                color: "transparent"
                radius: 16
                clip: true

                states: [
                    State {
                        when: root.portrait
                        AnchorChanges {
                            target: imagePane
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: buttonPanel.top
                        }
                        PropertyChanges {
                            imagePane.anchors.leftMargin: 24
                            imagePane.anchors.rightMargin: 24
                            imagePane.anchors.topMargin: 18
                            imagePane.anchors.bottomMargin: 12
                        }
                    },
                    State {
                        when: !root.portrait
                        AnchorChanges {
                            target: imagePane
                            anchors.left: parent.left
                            anchors.right: buttonPanel.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                        }
                        PropertyChanges {
                            imagePane.anchors.leftMargin: 24
                            imagePane.anchors.rightMargin: 16
                            imagePane.anchors.topMargin: 16
                            imagePane.anchors.bottomMargin: 24
                        }
                    }
                ]

                // Placeholder khi ảnh chưa sẵn sàng (loading hoặc lỗi)
                Rectangle {
                    anchors.fill: parent
                    color: Theme.field
                    radius: 12
                    visible: mainImage.status !== Image.Ready

                    Column {
                        anchors.centerIn: parent
                        spacing: 14

                        // Spinner khi đang tải
                        Rectangle {
                            id: spinnerRect
                            visible: mainImage.status === Image.Loading || root._displaySource === ""
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 48; height: 48; radius: 24
                            color: "transparent"
                            border.color: "#1e7eea"; border.width: 4
                            RotationAnimator on rotation {
                                running: spinnerRect.visible
                                from: 0; to: 360; duration: 900; loops: Animation.Infinite
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: mainImage.status === Image.Error
                                  ? "Không thể tải ảnh kết quả"
                                  : "Đang xử lý ảnh..."
                            color: mainImage.status === Image.Error ? "#c0392b" : "#7a7d85"
                            font.pixelSize: 16
                            font.bold: mainImage.status === Image.Error
                        }
                    }
                }

                Image {
                    id: mainImage
                    anchors.centerIn: parent
                    // Giảm kích thước hiển thị: giới hạn chiều cao để strip không quá cao.
                    width:  parent.width
                    height: parent.height * (root.portrait ? 0.72 : 0.86)
                    fillMode: Image.PreserveAspectFit
                    source: toUrl(root._displaySource)
                    cache: false
                    visible: status === Image.Ready
                    asynchronous: true
                    sourceSize: Qt.size(width, height)

                    onStatusChanged: {
                        if (status === Image.Ready)
                            Qt.callLater(overlayArea.calculateInitialPosition)
                    }
                    onSourceChanged: Qt.callLater(overlayArea.calculateInitialPosition)

                    Item {
                        id: overlayArea
                        width: mainImage.paintedWidth
                        height: mainImage.paintedHeight
                        anchors.centerIn: parent
                        // Không hiển thị QR trên ResultScreen (QR đã có ở WaitingResults).
                        // Vẫn giữ logic tính vị trí để QR vào BẢN IN nếu bật qr_code_enabled.
                        visible: false

                        property bool qrSettingEnabled: eventManager.getAppSetting("qr_code_enabled", "false") === "true"
                        property bool showQrInPrint: qrSettingEnabled
                        property string qrUrlPath: (root.sessionId && root.hwid)
                                ? s3Uploader.buildSessionUrl(root.hwid, root.eventId, root.sessionId)
                                : ""

                        // Detect printer & layout
                        property bool isQW410: printerConfig.selectedPrinter.indexOf("QW410") >= 0
                                            || printerConfig.selectedPrinter.indexOf("QW-410") >= 0
                        property real layoutAspect: {
                            var lp = root.eventData && root.eventData.selectedLayout ? root.eventData.selectedLayout : ""
                            return eventManager.getLayoutAspect(lp)
                        }
                        property bool is5x10Layout: layoutAspect > 0.38 && layoutAspect <= 0.58
                        property bool is5x15Layout: layoutAspect <= 0.38
                        property bool is15x5Layout: layoutAspect > 2.0   // landscape 15×5

                        // QW410 5x10 cut: displayPath = 1 strip dọc, composeCutFromStrip nhân 3 + xoay
                        property bool isQW410Cut: isQW410 && is5x10Layout && printerConfig.cutMode
                        // QW410 5x15: displayPath có 2 cột ngang thực sự → hiện mirror QR box
                        property bool isQW4105x15: isQW410 && is5x15Layout
                        // RX1/620 cut dọc (5×15): displayPath = 1 strip, backend replicate sang collagePath 2 strip
                        property bool isRX1Cut: !isQW410 && is5x15Layout && (root.eventData && root.eventData.autoCut) && printerConfig.cutMode
                        // RX1/620 cut ngang (15×5): displayPath = 1 strip ngang, backend stack dọc thành 15×10
                        property bool isRX1HCut: !isQW410 && is15x5Layout && (root.eventData && root.eventData.autoCut) && printerConfig.cutMode
                        // isTwoQR: backend cần replicate QR ngang (2 strips side-by-side): RX1 5×15, QW410 5×15
                        // isRX1HCut (15×5) xử lý riêng với applyQrOverlayFor2Vertical (strips xếp dọc)
                        property bool isTwoQR: isRX1Cut || isQW4105x15

                        property string selectedLayoutPath: root.eventData && root.eventData.selectedLayout
                                                            ? root.eventData.selectedLayout : ""
                        property var qrSlot: ({})
                        property real qrLayoutW: 0
                        property real qrLayoutH: 0

                        // numStrips dùng để hiện hint label
                        property int numStrips: isQW410Cut ? 3 : (isTwoQR ? 2 : 1)

                        // QW410 5x15: displayPath có 2 cột thực → drag trong nửa trái (width/2)
                        // RX1 15×5: displayPath là 1 strip ngang → toàn width (strip trên cùng)
                        // Còn lại (QW410Cut, RX1Cut, single): displayPath là 1 strip → toàn width
                        property real stripW: isQW4105x15 ? overlayArea.width / 2 : overlayArea.width
                        property real stripH: overlayArea.height

                        // Normalized (0..1) in the same strip coordinate system the UI shows.
                        property real normalizedX:    overlayArea.stripW > 0 ? (qrBox.x / overlayArea.stripW) : 0
                        property real normalizedY:    overlayArea.stripH > 0 ? (qrBox.y / overlayArea.stripH) : 0
                        property real normalizedW:    overlayArea.stripW > 0 ? (qrBox.width / overlayArea.stripW) : 0
                        property real normalizedH:    overlayArea.stripH > 0 ? (qrBox.height / overlayArea.stripH) : 0
                        property real normalizedSize: Math.min(overlayArea.stripW, overlayArea.stripH) > 0
                                                     ? (qrBox.width / Math.min(overlayArea.stripW, overlayArea.stripH)) : 0

                        function reloadQrSlot() {
                            qrSlot = ({})
                            qrLayoutW = 0
                            qrLayoutH = 0
                            if (!selectedLayoutPath) return
                            var meta = eventManager.loadLayoutMetadata(selectedLayoutPath)
                            if (!meta || !meta.qr_slot) return
                            qrSlot = meta.qr_slot
                            qrLayoutW = meta.width || 0
                            qrLayoutH = meta.height || 0
                            Qt.callLater(calculateInitialPosition)
                        }

                        function hasQrSlot() {
                            return qrSlot && qrSlot.width > 0 && qrSlot.height > 0
                                   && qrLayoutW > 0 && qrLayoutH > 0
                        }

                        function qrSlotBaseW() {
                            return qrLayoutW > 0 ? qrLayoutW : overlayArea.stripW
                        }

                        function qrSlotBaseH() {
                            return qrLayoutH > 0 ? qrLayoutH : overlayArea.stripH
                        }

                        function qrSlotNormalizedX() {
                            return Math.max(0, Math.min(1, (qrSlot.x || 0) / Math.max(1, qrSlotBaseW())))
                        }

                        function qrSlotNormalizedY() {
                            return Math.max(0, Math.min(1, (qrSlot.y || 0) / Math.max(1, qrSlotBaseH())))
                        }

                        function qrSlotNormalizedW() {
                            return Math.max(0.02, Math.min(1, (qrSlot.width || 0) / Math.max(1, qrSlotBaseW())))
                        }

                        function qrSlotNormalizedH() {
                            return Math.max(0.02, Math.min(1, (qrSlot.height || 0) / Math.max(1, qrSlotBaseH())))
                        }

                        function applyQrSlotPosition() {
                            if (qrBox.userAdjusted || !overlayArea.hasQrSlot())
                                return false
                            var sx = overlayArea.stripW / Math.max(1, overlayArea.qrSlotBaseW())
                            var sy = overlayArea.stripH / Math.max(1, overlayArea.qrSlotBaseH())
                            var w = Math.max(1, Math.round((qrSlot.width || 0) * sx))
                            var h = Math.max(1, Math.round((qrSlot.height || 0) * sy))
                            qrBox.width = w
                            qrBox.height = h
                            qrBox.x = Math.max(0, Math.min(overlayArea.stripW - w, Math.round((qrSlot.x || 0) * sx)))
                            qrBox.y = Math.max(0, Math.min(overlayArea.stripH - h, Math.round((qrSlot.y || 0) * sy)))
                            return true
                        }

                        function hasUsablePrintPosition() {
                            return overlayArea.normalizedSize > 0
                                   && (qrBox.userAdjusted || qrBox.x > 1 || qrBox.y > 1)
                        }

                        function fallbackLowerRightNorm() {
                            var ns = overlayArea.printNormalizedSize()
                            return Math.max(0, Math.min(0.95, 1.0 - ns - 0.04))
                        }

                        function printNormalizedX() {
                            if (!qrBox.userAdjusted && overlayArea.hasQrSlot())
                                return overlayArea.qrSlotNormalizedX()
                            if (overlayArea.hasUsablePrintPosition())
                                return Math.max(0, Math.min(1, overlayArea.normalizedX))
                            return overlayArea.fallbackLowerRightNorm()
                        }

                        function printNormalizedY() {
                            if (!qrBox.userAdjusted && overlayArea.hasQrSlot())
                                return overlayArea.qrSlotNormalizedY()
                            if (overlayArea.hasUsablePrintPosition())
                                return Math.max(0, Math.min(1, overlayArea.normalizedY))
                            return overlayArea.fallbackLowerRightNorm()
                        }

                        function printNormalizedSize() {
                            if (!qrBox.userAdjusted && overlayArea.hasQrSlot())
                                return Math.max(overlayArea.qrSlotNormalizedW(), overlayArea.qrSlotNormalizedH())
                            if (overlayArea.normalizedSize > 0)
                                return Math.max(0.02, Math.min(0.8, overlayArea.normalizedSize))
                            return 0.12
                        }
                        function printNormalizedW() {
                            if (!qrBox.userAdjusted && overlayArea.hasQrSlot())
                                return overlayArea.qrSlotNormalizedW()
                            if (overlayArea.normalizedW > 0)
                                return Math.max(0.02, Math.min(1, overlayArea.normalizedW))
                            return overlayArea.printNormalizedSize()
                        }

                        function printNormalizedH() {
                            if (!qrBox.userAdjusted && overlayArea.hasQrSlot())
                                return overlayArea.qrSlotNormalizedH()
                            if (overlayArea.normalizedH > 0)
                                return Math.max(0.02, Math.min(1, overlayArea.normalizedH))
                            return overlayArea.printNormalizedSize()
                        }

                        function calculateInitialPosition() {
                            if (overlayArea.width <= 0 || overlayArea.height <= 0) return
                            if (qrBox.userAdjusted) return
                            if (overlayArea.applyQrSlotPosition()) return
                            var sw = overlayArea.stripW
                            var fullH = overlayArea.height
                            var em = 25

                            var sz, targetX, targetY

                            if (overlayArea.isQW410Cut) {
                                // QW410 5x10: 3 ảnh dọc — QR góc dưới phải ảnh cuối
                                sz = Math.max(Math.round(Math.min(sw, fullH) * 0.12), 50)
                                sz = Math.min(sz, sw - em * 2)
                                targetX = Math.max(0, sw - sz - em)
                                targetY = Math.max(0, fullH - sz - em)

                            } else if (overlayArea.isQW4105x15) {
                                // QW410 5x15: 2 cột ngang — QR góc dưới phải cột trái (~88% chiều cao)
                                sz = Math.max(Math.round(Math.min(sw, fullH) * 0.11), 50)
                                sz = Math.min(sz, sw - em * 2)
                                targetX = Math.max(0, sw - sz - em)
                                targetY = Math.max(0, Math.round(fullH * 0.88) - sz - em)

                            } else if (overlayArea.isRX1Cut) {
                                // RX1/620 cut dọc (5×15): 1 strip dọc — QR góc dưới phải toàn strip
                                sz = Math.max(Math.round(Math.min(sw, fullH) * 0.12), 50)
                                sz = Math.min(sz, sw - em * 2)
                                targetX = Math.max(0, sw - sz - em)
                                targetY = Math.max(0, fullH - sz - em)

                            } else if (overlayArea.isRX1HCut) {
                                // RX1/620 cut ngang (15×5): 1 strip ngang — QR góc dưới phải strip
                                sz = Math.max(Math.round(Math.min(sw, fullH) * 0.12), 50)
                                sz = Math.min(sz, fullH - em * 2)
                                targetX = Math.max(0, sw - sz - em)
                                targetY = Math.max(0, fullH - sz - em)

                            } else {
                                // Single strip không cắt
                                sz = Math.max(Math.round(Math.min(sw, fullH) * 0.14), 50)
                                sz = Math.min(sz, sw - em * 2)
                                targetX = Math.max(0, sw - sz - em)
                                targetY = Math.max(0, fullH - sz - em)
                            }

                            qrBox.width  = sz; qrBox.height = sz
                            qrBox.x = targetX
                            qrBox.y = targetY
                        }

                        onWidthChanged:         Qt.callLater(calculateInitialPosition)
                        onHeightChanged:        Qt.callLater(calculateInitialPosition)
                        onIsQW410CutChanged:    Qt.callLater(calculateInitialPosition)
                        onIsQW4105x15Changed:   Qt.callLater(calculateInitialPosition)
                        onIsRX1CutChanged:      Qt.callLater(calculateInitialPosition)
                        onIsRX1HCutChanged:     Qt.callLater(calculateInitialPosition)
                        onIsTwoQRChanged:       Qt.callLater(calculateInitialPosition)
                        onSelectedLayoutPathChanged: reloadQrSlot()
                        Component.onCompleted: reloadQrSlot()

                        // ── QR Box chính — kéo trong strip 1 (trái hoặc toàn ảnh) ───
                        Rectangle {
                            id: qrBox
                            color: "white"; radius: 8
                            border.color: "#1e7eea"; border.width: 2
                            visible: overlayArea.showQrInPrint && overlayArea.qrUrlPath !== ""

                            property bool userAdjusted: false
                            property real minSize: 40
                            property real maxSize: Math.min(overlayArea.stripW, overlayArea.stripH) * 0.8

                            Image {
                                anchors.fill: parent
                                source: overlayArea.qrUrlPath !== ""
                                    ? ("image://qr/" + encodeURIComponent(overlayArea.qrUrlPath))
                                    : ""
                                fillMode: Image.PreserveAspectFit; cache: false
                            }

                            // Hint label khi multi-strip
                            Rectangle {
                                visible: overlayArea.numStrips > 1
                                anchors.bottom: parent.top; anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottomMargin: 3; color: "#1e7eea"; radius: 3
                                width: lbHint.implicitWidth + 8; height: 16
                                Text { id: lbHint; anchors.centerIn: parent
                                    text: overlayArea.isQW410Cut ? "vị trí áp dụng cho cả 3 ảnh" : "vị trí áp dụng cho cả 2 ảnh"
                                    color: "white"; font.pixelSize: 9; font.bold: true }
                            }

                            MouseArea {
                                id: dragArea; anchors.fill: parent
                                drag.target: qrBox; drag.axis: Drag.XAndYAxis
                                drag.minimumX: 0
                                drag.maximumX: overlayArea.stripW - qrBox.width
                                drag.minimumY: 0
                                drag.maximumY: overlayArea.height - qrBox.height
                                cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                onPressed: qrBox.userAdjusted = true
                            }

                            Rectangle {
                                id: resizeHandle
                                width: 28; height: 28; radius: 6
                                anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 3
                                color: resizeMA.containsMouse || resizeMA.pressed ? "#1e7eea" : "#3a8ff0"
                                border.color: "white"; border.width: 1.5; z: 10
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Text { anchors.centerIn: parent; text: "⤡"; color: "white"; font.pixelSize: 14; font.bold: true }
                                MouseArea {
                                    id: resizeMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.SizeFDiagCursor
                                    property real startX: 0; property real startY: 0; property real startW: 0
                                    onPressed: (mouse) => {
                                        qrBox.userAdjusted = true
                                        startX = mouse.x + resizeHandle.x + qrBox.x
                                        startY = mouse.y + resizeHandle.y + qrBox.y
                                        startW = qrBox.width
                                    }
                                    onPositionChanged: (mouse) => {
                                        if (!pressed) return
                                        var dx = (mouse.x + resizeHandle.x + qrBox.x) - startX
                                        var dy = (mouse.y + resizeHandle.y + qrBox.y) - startY
                                        var delta = (Math.abs(dx) > Math.abs(dy)) ? dx : dy
                                        var s = Math.round(startW + delta)
                                        s = Math.max(qrBox.minSize, Math.min(qrBox.maxSize, s))
                                        s = Math.min(s, overlayArea.stripW - qrBox.x)
                                        s = Math.min(s, overlayArea.height - qrBox.y)
                                        qrBox.width = s; qrBox.height = s
                                    }
                                }
                            }

                            Rectangle {
                                width: 36; height: 36; radius: 18
                                color: qrCloseMA.containsMouse ? "#ff4757" : "#e74c3c"
                                anchors.top: parent.top; anchors.right: parent.right; anchors.margins: -12
                                border.color: "white"; border.width: 2.5; z: 10
                                Text { text: "✕"; color: "white"; font.pixelSize: 18; font.bold: true; anchors.centerIn: parent }
                                MouseArea {
                                    id: qrCloseMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: overlayArea.showQrInPrint = false
                                }
                            }
                        }

                        // ── QR Box mirror — chỉ hiển thị khi QW410 5x15 (2 cột thực trên UI) ──
                        Rectangle {
                            id: qrBoxMirror
                            visible: overlayArea.showQrInPrint && overlayArea.qrUrlPath !== ""
                                  && overlayArea.isQW4105x15
                            color: "white"; radius: 8
                            border.color: "#1e7eea"; border.width: 2
                            opacity: 0.85

                            // Luôn khớp vị trí và kích thước với qrBox, nhưng lệch sang strip 2
                            x: qrBox.x + overlayArea.stripW
                            y: qrBox.y
                            width: qrBox.width
                            height: qrBox.height

                            Image {
                                anchors.fill: parent
                                source: overlayArea.qrUrlPath !== ""
                                    ? ("image://qr/" + encodeURIComponent(overlayArea.qrUrlPath))
                                    : ""
                                fillMode: Image.PreserveAspectFit; cache: false
                            }
                        }
                    }
                }
            }

            // ── Right button panel ──
            ColumnLayout {
                id: buttonPanel
                anchors {
                    right:  parent.right
                    top:    parent.top
                    bottom: parent.bottom
                }
                anchors.rightMargin:  root.portrait ? 16 : 40
                anchors.topMargin:    root.portrait ? 16 : 24
                anchors.bottomMargin: root.portrait ? 16 : 24
                width: root.portrait ? 320 : 400
                spacing: root.portrait ? 16 : 24

                states: [
                    State {
                        when: root.portrait
                        AnchorChanges {
                            target: buttonPanel
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: undefined
                            anchors.bottom: parent.bottom
                        }
                        PropertyChanges {
                            buttonPanel.height: root.prePaymentDone ? 560 : 500
                            buttonPanel.anchors.leftMargin: 32
                            buttonPanel.anchors.rightMargin: 32
                            buttonPanel.anchors.topMargin: 0
                            buttonPanel.anchors.bottomMargin: 24
                        }
                    },
                    State {
                        when: !root.portrait
                        AnchorChanges {
                            target: buttonPanel
                            anchors.left: undefined
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                        }
                        PropertyChanges {
                            buttonPanel.width: 400
                            buttonPanel.anchors.rightMargin: 40
                            buttonPanel.anchors.topMargin: 24
                            buttonPanel.anchors.bottomMargin: 24
                        }
                    }
                ]

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.border
                    opacity: 0.5
                    visible: root.portrait
                }
                
                // Countdown badge — đã chuyển sang WaitingResults, ẩn ở đây
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    visible: false
                    width: 160; height: 44; radius: 22
                    color: root.resultCountdownTime <= 10 ? "#CC3300" : "#1A1A2E"
                    border.color: root.resultCountdownTime <= 10 ? "#FF4422" : Theme.textMuted
                    border.width: 2
                    Behavior on color { ColorAnimation { duration: 300 } }
                    Behavior on border.color { ColorAnimation { duration: 300 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: "⏱"; color: "white"; font.pixelSize: 15; font.bold: true }
                        Text {
                            text: root.resultCountdownTime + "s"
                            color: "white"
                            font.pixelSize: 18
                            font.bold: true
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (resultCountdownTimer.running) resultCountdownTimer.stop()
                            else resultCountdownTimer.start()
                        }
                    }
                }

                // Status messages
                Rectangle {
                    id: statusMessage
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.printStatus !== "" || root.printError !== "" ? 52 : 0
                    color: root.printStatus !== "" ? "#27ae60" : "#c0392b"
                    radius: 10
                    visible: Layout.preferredHeight > 0
                    clip: true

                    Behavior on Layout.preferredHeight {
                        NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                    }

                    Text {
                        anchors.centerIn: parent
                        anchors.margins: 10
                        width: parent.width - 20
                        text: root.printStatus !== "" ? root.printStatus : root.printError
                        color: "white"
                        font.pixelSize: 14
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }

                // Spacer top
                Item { Layout.fillHeight: true; visible: !root.portrait }

                GridLayout {
                    id: resultActionArea
                    Layout.fillWidth: !(root.prePaymentDone && root.portrait)
                    Layout.alignment: Qt.AlignHCenter
                    columns: root.prePaymentDone && root.portrait ? 3 : 1
                    columnSpacing: root.prePaymentDone && root.portrait ? 28 : 0
                    rowSpacing: root.portrait ? 12 : 16
                    layoutDirection: Qt.LeftToRight

                // ── Layout khi BẬT thanh toán (prePaymentDone = true) ──────────────
                // Portrait keeps buttons left of QR; landscape stacks buttons below QR.

                // QR Code Display — chỉ hiện khi BẬT thanh toán
                // Pre-payment shows QR centered; printing is triggered by the print/new-session buttons.
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: root.portrait ? 420 : 300
                    Layout.alignment: Qt.AlignHCenter
                    Layout.row: 0
                    Layout.column: root.prePaymentDone && root.portrait ? 1 : 0
                    spacing: 8
                    visible: false   // QR chuyển sang WaitingResults, không hiển thị ở đây

                    Text {
                        text: root.isUploading ? "⏳ Đang tải ảnh lên..." : "📱 Quét QR để xem ảnh"
                        color: root.isUploading ? "#f0c040" : Theme.textMuted
                        font.pixelSize: 14
                        font.bold: root.isUploading
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: root.portrait ? 300 : 280
                        Layout.preferredHeight: root.portrait ? 300 : 280
                        color: "white"
                        radius: 12
                        border.color: root.qrImageUrl !== "" ? "#4FA4F2" : Theme.border
                        border.width: 3

                        Image {
                            id: qrCodeImage
                            anchors.fill: parent
                            anchors.margins: 8
                            source: root.qrImageUrl
                            fillMode: Image.PreserveAspectFit
                            cache: false
                            visible: root.qrImageUrl !== ""
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            visible: root.qrImageUrl === ""

                            Rectangle {
                                width: 32; height: 32; radius: 16
                                color: "transparent"
                                border.color: Theme.textMuted; border.width: 3
                                Layout.alignment: Qt.AlignHCenter
                                RotationAnimator on rotation {
                                    running: root.qrImageUrl === ""
                                    from: 0; to: 360; duration: 1000; loops: Animation.Infinite
                                }
                            }

                            Text {
                                text: "Đang tạo QR..."
                                color: "#888"
                                font.pixelSize: 13
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                }

                // ── Layout khi TẮT thanh toán (prePaymentDone = false) ─────────────
                // 4 nút: In ảnh, Xem mã QR code, Quay lại, Chụp lượt mới

                // In ảnh
                GridLayout {
                    id: compactActionGrid
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    Layout.row: root.prePaymentDone && !root.portrait ? 1 : 0
                    Layout.column: 0
                    columns: root.portrait ? 2 : 1
                    columnSpacing: root.portrait ? 18 : 0
                    rowSpacing: root.portrait ? 14 : 16

                    property int _buttonH: root.portrait ? 64 : 76
                    property int _buttonPad: root.portrait ? 44 : 48
                    property int _buttonMaxW: root.portrait ? 330 : 300

                Button {
                    id: printButton
                    visible: true
                    implicitWidth: contentItem.implicitWidth + compactActionGrid._buttonPad
                    Layout.fillWidth: false
                    Layout.preferredWidth: Math.min(compactActionGrid._buttonMaxW, implicitWidth)
                    Layout.maximumWidth: compactActionGrid._buttonMaxW
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: compactActionGrid._buttonH
                    enabled: !root.isPrinting && root.collagePath !== "" && (!root.prePaymentDone || !root._prePaymentPrintRequested || root.printError !== "")
                    text: root.isPrinting ? "⏳ Đang in..." : "🖸️ In Ảnh"

                    background: Rectangle {
                        color: printButton.hovered && printButton.enabled ? "#bd4f79" : "#ad436d"
                        radius: 16
                        opacity: printButton.enabled ? 1.0 : 0.5
                    }

                    contentItem: Text {
                        text: printButton.text
                        color: "white"
                        font.pixelSize: root.portrait ? 19 : 22
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        if (root.prePaymentDone) {
                            if (root.preparePrePaymentPrint())
                                root.executePrint()
                        } else {
                            printOptionsDialog.open()
                        }
                    }
                }

                // Xem mã QR code — chỉ hiện khi TẮT thanh toán
                Button {
                    id: viewQrButton
                    visible: false   // QR chuyển sang WaitingResults
                    implicitWidth: contentItem.implicitWidth + compactActionGrid._buttonPad
                    Layout.fillWidth: false
                    Layout.preferredWidth: Math.min(compactActionGrid._buttonMaxW, implicitWidth)
                    Layout.maximumWidth: compactActionGrid._buttonMaxW
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: compactActionGrid._buttonH
                    text: "📱 Xem mã QR code"

                    background: Rectangle {
                        color: viewQrButton.hovered ? "#1565c0" : "#1976d2"
                        radius: 16
                    }

                    contentItem: Text {
                        text: viewQrButton.text
                        color: "white"
                        font.pixelSize: root.portrait ? 19 : 22
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: root.qrCodeClicked()
                }

                // Quay lại
                Button {
                    id: backButton
                    implicitWidth: contentItem.implicitWidth + compactActionGrid._buttonPad
                    Layout.fillWidth: false
                    Layout.preferredWidth: Math.min(compactActionGrid._buttonMaxW, implicitWidth)
                    Layout.maximumWidth: compactActionGrid._buttonMaxW
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: compactActionGrid._buttonH
                    visible: false   // chỉ còn nút In trên ResultScreen
                    text: "🔙 Quay lại"

                    background: Rectangle {
                        color: backButton.hovered ? "#e67e22" : "#d35400"
                        radius: 16
                    }

                    contentItem: Text {
                        text: backButton.text
                        color: "white"
                        font.pixelSize: root.portrait ? 19 : 22
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: root.backClicked()
                }

                // Separator line
                Rectangle {
                    Layout.fillWidth: true
                    Layout.maximumWidth: root.portrait ? 760 : 16777215
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: 1
                    color: Theme.border
                    opacity: 0.6
                    visible: false
                }

                // Chụp lượt mới
                Button {
                    id: nextButton
                    visible: false   // "Chụp Lượt Mới" chuyển sang WaitingResults
                    implicitWidth: contentItem.implicitWidth + compactActionGrid._buttonPad
                    Layout.alignment: root.prePaymentDone && root.portrait ? Qt.AlignLeft : Qt.AlignHCenter
                    Layout.preferredWidth: Math.min(compactActionGrid._buttonMaxW, implicitWidth)
                    Layout.maximumWidth: compactActionGrid._buttonMaxW
                    Layout.preferredHeight: compactActionGrid._buttonH
                    text: "▶ Chụp Lượt Mới"
                    enabled: !root.isPrinting

                    background: Rectangle {
                        id: nextBtnBg
                        color: nextButton.hovered ? "#ad436d" : "#ad436d"
                        radius: 16

                        SequentialAnimation on scale {
                            running: !nextButton.hovered && root._isActiveScreen
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 1.04; duration: 900; easing.type: Easing.InOutQuad }
                            NumberAnimation { from: 1.04; to: 1.0; duration: 900; easing.type: Easing.InOutQuad }
                        }
                    }

                    contentItem: Text {
                        text: nextButton.text
                        color: "white"
                        font.pixelSize: root.portrait ? 19 : 22
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        if (root.prePaymentDone) {
                            if (!root.ensurePrePaymentPrinted())
                                return
                            qrConfirmDialog.visible = true
                        } else {
                            root.finished()
                        }
                    }
                }
                }

                Item {
                    visible: root.prePaymentDone && root.portrait
                    Layout.row: 0
                    Layout.column: 2
                    Layout.preferredWidth: compactActionGrid.implicitWidth
                    Layout.preferredHeight: 1
                }
                }


                // Spacer bottom
                Item { Layout.fillHeight: true; visible: !root.portrait }
            }
        }
    }

    // QR Confirmation Dialog
    Rectangle {
        id: qrConfirmDialog
        anchors.fill: parent
        color: "#AA000000"
        visible: false
        z: 500

        Rectangle {
            anchors.centerIn: parent
            width: 500
            height: 280
            color: Theme.field
            radius: 20
            border.color: Theme.border
            border.width: 2

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 36
                spacing: 20

                Text {
                    text: "Bạn đã quét QR chưa?"
                    color: "#ffffff"
                    font.pixelSize: 26
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: "Quét QR để xem và lưu ảnh của bạn trước khi kết thúc phiên."
                    color: Theme.textMuted
                    font.pixelSize: 15
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    Button {
                        text: "Chưa quét"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        background: Rectangle {
                            color: parent.hovered ? "#c0392b" : "#a93226"
                            radius: 10
                        }
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            font.pixelSize: 18
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: qrConfirmDialog.visible = false
                    }

                    Button {
                        text: "Đã quét, tiếp tục"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        background: Rectangle {
                            color: parent.hovered ? "#ad436d" : "#ad436d"
                            radius: 10
                        }
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            font.pixelSize: 18
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: {
                            qrConfirmDialog.visible = false
                            if (!root.ensurePrePaymentPrinted())
                                return
                            root.finished()
                        }
                    }
                }
            }
        }
    }

    // Print Options Dialog
    Rectangle {
        id: printOptionsDialog

        // Số ảnh trên 1 tờ khi cut mode:
        //   QW410    → 3 (15×10 cắt thành 3 strip 5×10)
        //   RX1/620S → 2 (4×6 cắt thành 2 strip 2×6 dọc, hoặc 15×10 cắt thành 2 strip 15×5 ngang)
        property int photosPerSheet: {
            var p = printerConfig.selectedPrinter
            if (p.indexOf("QW410") >= 0 || p.indexOf("QW-410") >= 0 || p.indexOf("410") >= 0)
                return 3
            return 2
        }

        // User-selectable cut mode.
        // Mặc định PHẢI khớp điều kiện dùng khi GHÉP ảnh ở EventManager:
        //   cutMode_compose = event.autoCut && printerConfig.cutMode
        // Nếu chỉ lấy autoCut, khi printerConfig.cutMode=OFF ảnh được ghép dạng
        // strip đơn nhưng vẫn gửi cờ cắt xuống driver → máy cắt đôi 1 tấm ảnh.
        property bool canCut: !!(root.eventData && root.eventData.autoCut) && printerConfig.cutMode
        property bool selectedCutMode: printOptionsDialog.canCut

        anchors.centerIn: parent
        width: 500
        height: 620
        color: Theme.field
        radius: 20
        border.color: Theme.border
        border.width: 2
        visible: false
        z: 1000

        // Semi-transparent overlay
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.5
            z: -1
            anchors.centerIn: parent
            width: parent.parent.width
            height: parent.parent.height
        }

        function open() {
            printOptionsDialog.visible = true
            printOptionsDialog.selectedCutMode = printOptionsDialog.canCut
            var isCut = printOptionsDialog.selectedCutMode
            photosSpinner.value = isCut ? printOptionsDialog.photosPerSheet : 1
        }

        function close() {
            printOptionsDialog.visible = false
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 30
            spacing: 20

            // Title
            Text {
                text: ""
                color: "white"
                font.pixelSize: 28
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            // Cut Mode Toggle
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 68
                radius: 10
                border.width: 1
                color: cutModeMouse.containsMouse
                       ? (printOptionsDialog.selectedCutMode ? "#1e2d40" : Theme.field)
                       : "#FFFFFF"
                border.color: printOptionsDialog.selectedCutMode ? "#4ade80" : Theme.border
                Behavior on color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 14

                    // Toggle switch
                    Rectangle {
                        implicitWidth: 48; implicitHeight: 26; radius: 13
                        color: printOptionsDialog.selectedCutMode ? "#4ade80" : Theme.border
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Rectangle {
                            x: printOptionsDialog.selectedCutMode ? parent.width - width - 2 : 2
                            width: 22; height: 22; radius: 11; color: "#ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on x { NumberAnimation { duration: 200 } }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "🔪 Chế độ cắt: " + (printOptionsDialog.selectedCutMode ? "CẮT" : "KHÔNG CẮT")
                            color: printOptionsDialog.selectedCutMode ? "#4ade80" : Theme.textMuted
                            font.pixelSize: 14; font.bold: true
                        }
                        Text {
                            text: printOptionsDialog.selectedCutMode
                                  ? ("Cắt thành " + printOptionsDialog.photosPerSheet + " ảnh / tờ")
                                  : "In nguyên tờ không cắt"
                            color: Theme.textMuted; font.pixelSize: 12
                        }
                    }
                }

                MouseArea {
                    id: cutModeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        // Chỉ cho phép BẬT cắt khi ảnh đã thực sự được ghép thành
                        // canvas 2 strip (canCut). Bật cắt trên ảnh strip đơn sẽ
                        // khiến máy in xẻ đôi một tấm ảnh.
                        if (!printOptionsDialog.canCut && !printOptionsDialog.selectedCutMode) {
                            console.log("[ResultScreen] Bỏ qua bật cắt: ảnh không được ghép ở chế độ cắt",
                                        "(autoCut=", !!(root.eventData && root.eventData.autoCut),
                                        ", printerConfig.cutMode=", printerConfig.cutMode, ")")
                            return
                        }
                        printOptionsDialog.selectedCutMode = !printOptionsDialog.selectedCutMode
                        var isCut = printOptionsDialog.selectedCutMode
                        photosSpinner.value = isCut ? printOptionsDialog.photosPerSheet : 1
                    }
                }
            }

            // Image Preview
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                color: "#000000"
                radius: 10
                border.color: Theme.border
                border.width: 1

                Image {
                    id: previewImage
                    anchors.fill: parent
                    anchors.margins: 5
                    source: toUrl(root._displaySource)
                    fillMode: Image.PreserveAspectFit
                    cache: false
                    asynchronous: true
                    sourceSize: Qt.size(480, 140)
                }

                Text {
                    anchors.centerIn: parent
                    text: "Ảnh Xem Trước"
                    color: Theme.textMuted
                    font.pixelSize: 18
                    visible: previewImage.status !== Image.Ready
                }
            }

            // Copies Section
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                color: Theme.field
                radius: 10
                border.color: Theme.border
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 10

                    Text {
                        text: "Số ảnh in"
                        color: Theme.textMuted
                        font.pixelSize: 18
                        font.bold: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 15

                        Button {
                            text: "-"
                            Layout.preferredWidth: 50
                            Layout.preferredHeight: 45
                            property int step: printOptionsDialog.selectedCutMode ? printOptionsDialog.photosPerSheet : 1
                            enabled: photosSpinner.value > step

                            background: Rectangle {
                                color: parent.hovered && parent.enabled ? Theme.border : Theme.field
                                radius: 8
                                border.color: Theme.border
                                border.width: 1
                            }

                            contentItem: Text {
                                text: parent.text
                                color: parent.enabled ? "white" : Theme.textMuted
                                font.pixelSize: 20
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: if (photosSpinner.value > step) photosSpinner.value -= step
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 45
                            color: Theme.field
                            radius: 8
                            border.color: Theme.border
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: photosSpinner.value + " ảnh"
                                color: "white"
                                font.pixelSize: 22
                                font.bold: true
                            }
                        }

                        Button {
                            text: "+"
                            Layout.preferredWidth: 50
                            Layout.preferredHeight: 45
                            property int step: printOptionsDialog.selectedCutMode ? printOptionsDialog.photosPerSheet : 1
                            property int max: printOptionsDialog.selectedCutMode ? printOptionsDialog.photosPerSheet * 4 : 4
                            enabled: photosSpinner.value < max

                            background: Rectangle {
                                color: parent.hovered && parent.enabled ? Theme.border : Theme.field
                                radius: 8
                                border.color: Theme.border
                                border.width: 1
                            }

                            contentItem: Text {
                                text: parent.text
                                color: parent.enabled ? "white" : Theme.textMuted
                                font.pixelSize: 20
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: if (photosSpinner.value < max) photosSpinner.value += step
                        }
                    }

                    // Hiển thị số bản gửi máy in
                    Text {
                        property int toSend: printOptionsDialog.selectedCutMode
                                             ? Math.ceil(photosSpinner.value / printOptionsDialog.photosPerSheet)
                                             : photosSpinner.value
                        text: "→ Gửi máy in: " + toSend + " bản"
                        color: "#4ade80"
                        font.pixelSize: 13
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                }
            }

            Item { Layout.fillHeight: true }


            // Action Buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 15

                Button {
                    text: "Huỷ"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50

                    background: Rectangle {
                        color: parent.hovered ? "#e74c3c" : "#c0392b"
                        radius: 10
                    }

                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 16
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: printOptionsDialog.close()
                }

                Button {
                    text: "In Ảnh"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50

                    background: Rectangle {
                        color: parent.hovered ? "#2a8fff" : "#1e7eea"
                        radius: 10
                    }

                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 16
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        var cutMode = printOptionsDialog.selectedCutMode
                        var photos = photosSpinner.value

                        root.pendingPrintCutMode = cutMode
                        root.pendingPrintPhotos = photos

                        // Nếu đã thanh toán từ bước trước → in luôn, không hỏi lại
                        if (root.prePaymentDone) {
                            root.executePrint()
                            return
                        }

                        var paymentEnabled = eventManager.getAppSetting("payment_enabled", "false") === "true"
                        if (paymentEnabled) {
                            printOptionsDialog.close()
                            root.isPrinting = true
                            paymentScreenLoader.active = true
                        } else {
                            root.executePrint()
                        }
                    }
                }
            }
        }
    }

    // Spinner value holder
    Item {
        property int value: 1
        id: photosSpinner
    }

    // ── Auto-scan popup: hiện khi máy in mặc định không phản hồi ──────────────
    Rectangle {
        id: autoScanPopup
        anchors.fill: parent
        color: "#BB000000"
        visible: false
        z: 3000

        Rectangle {
            anchors.centerIn: parent
            width: 480
            height: 260
            color: Theme.field
            radius: 20
            border.color: Theme.textMuted
            border.width: 2

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 36
                spacing: 20

                // Spinner animation
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 52; height: 52; radius: 26
                    color: "transparent"
                    border.color: "#1e7eea"; border.width: 4
                    RotationAnimator on rotation {
                        running: autoScanPopup.visible
                        from: 0; to: 360; duration: 800; loops: Animation.Infinite
                    }
                }

                Text {
                    text: "Vui lòng chờ"
                    color: "#ffffff"
                    font.pixelSize: 26
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    id: autoScanStatusText
                    text: "Đang kiểm tra máy in..."
                    color: Theme.textMuted
                    font.pixelSize: 15
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    Loader {
        id: paymentScreenLoader
        anchors.fill: parent
        active: false
        z: 2000
        sourceComponent: Component {
            PaymentScreen {
                eventId: root.eventId
                eventData: root.eventData
                sessionId: root.sessionId
                printCopies: root.pendingPrintPhotos
                directCutMode: root.pendingPrintCutMode ? 1 : 0

                onCloseClicked: {
                    paymentScreenLoader.active = false
                    root.isPrinting = false
                }
                onPaymentSuccess: {
                    paymentScreenLoader.active = false
                    var priceKey = root.pendingPrintCutMode ? "price_cut" : "price_nocut"
                    var ppCopy = parseInt(eventManager.getAppSetting(priceKey, "0"), 10) || 0
                    var totalPay = ppCopy * root.pendingPrintPhotos
                    var evName3 = (root.eventData && root.eventData.name) ? root.eventData.name : ""
                    eventManager.logRevenue(root.eventId, evName3, root.sessionId,
                        root.pendingPrintPhotos, totalPay,
                        0, totalPay, 0, "transfer")
                    root.executePrint()
                }
                onPaymentSkipped: {
                    paymentScreenLoader.active = false
                    root.executePrint()
                }
            }
        }
    }

    // ── Nút X tròn — bấm → về CutModeScreen (lượt mới). Ẩn ở chế độ thanh toán. ──
    Rectangle {
        id: resultCloseBtn
        anchors.right: parent.right
        anchors.top:   parent.top
        anchors.rightMargin: 20
        anchors.topMargin:   16
        width: 52; height: 52; radius: 26
        visible: !root._paymentEnabled
        opacity: resultCloseGuard.holding ? 0.65 : root._chromeOpacity
        Behavior on opacity { NumberAnimation { duration: 180 } }
        color: closeResultArea.containsMouse ? "#c0392b" : "#e74c3c"
        border.color: "white"; border.width: 2
        z: 50
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: "✕"
            color: "white"; font.pixelSize: 22; font.bold: true
        }
        MouseArea {
            id: closeResultArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.closeClicked()
        }
    }

    // Chống khách chạm nhầm khi nút ✕ tàng hình: phải giữ 1 giây mới thoát.
    HoldToActivate {
        id: resultCloseGuard
        anchors.fill: resultCloseBtn
        visible: resultCloseBtn.visible && enabled
        z: 51
        onActivated: root.closeClicked()
    }
}
