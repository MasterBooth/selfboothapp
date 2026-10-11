import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../utils/Money.js" as Money
import "../../theme"
import "../../components"

Rectangle {
    id: root
    width: Window.window ? Window.window._designW : 1920
    height: Window.window ? Window.window._designH : 1080
    readonly property bool portrait: Window.window && Window.window.isPortrait

    // ── Public inputs ─────────────────────────────────────────────────────────
    property string layoutPath: ""   // đường dẫn layout đã chọn (file layout thật)
    property int    slotCount:  3    // số ảnh chụp của layout
    property bool   isCut:      false
    // Ảnh hiển thị riêng của nhóm (cate_image_). Nếu có → dùng làm preview thay cho
    // layoutPath; rỗng → vẫn dùng layoutPath (cate_thumb_) như cũ.
    property string displayImagePath: ""
    // Giá của nhóm khung (category) khi bật "thanh toán theo giá khung frame".
    // >= 0 → giá mỗi lựa chọn = categoryPrice × số bản in (bỏ giá cố định trong print_options_*).
    // -1   → giữ chế độ cũ: dùng giá cố định theo số lượng.
    property int categoryPrice: -1
    // Ẩn nút X khi flow đã có nút Quay lại riêng.
    property bool showCloseButton: true

    // ── Resolved from settings ────────────────────────────────────────────────
    // Danh sách lựa chọn in đã cài sẵn: [{ qty, price }, ...]
    // qty = số ảnh in hiển thị · price = tổng tiền cố định cho lựa chọn đó
    property var printOptions: []

    // ── Output signal ─────────────────────────────────────────────────────────
    signal continueClicked(int copies, int totalPrice)
    signal closeClicked()

    // Độ mờ nút điều khiển (⚙ / ✕) — 1.0 bình thường, 0.25 mờ, 0.0 tàng hình.
    // Dùng opacity nên nút vẫn bấm được ở đúng vị trí cũ dù không nhìn thấy.
    readonly property real _chromeOpacity: Window.window ? Window.window.appChromeOpacity : 1.0
    // Điều hướng về bước trước (LayoutSelection).
    signal backClicked()

    // ── Theme ─────────────────────────────────────────────────────────────────
    property color _themeBg: Window.window ? Window.window.appBgColor : "#000000"
    property color _themeText: Window.window ? Window.window.appTextColor : "#FFFFFF"
    property color _themeSurface: Window.window ? Window.window.appSurfaceColor : "#121212"
    property color _themeField: Window.window ? Window.window.appFieldColor : "#1A1A1A"
    property color _themeBorder: Window.window ? Window.window.appBorderColor : "#3A3A3A"
    property color _themeMutedText: Qt.rgba(_themeText.r, _themeText.g, _themeText.b, 0.65)
    property string backgroundImagePath: {
        var s = eventManager.getAppSetting("print_quantity_bg_image", "")
        return s !== "" ? s : "qrc:/assets/bg/print_quantity.png"
    }
    property bool _isActiveScreen: StackView.status === StackView.Active
                                || StackView.status === StackView.Activating

    color: "transparent"

    Rectangle {
        anchors.fill: parent
        visible: root.backgroundImagePath === ""
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.lighter(root._themeBg, 1.08) }
            GradientStop { position: 1.0; color: Qt.darker(root._themeBg,  1.30) }
        }
    }

    BackgroundMedia {
        anchors.fill: parent
        sourcePath: root.backgroundImagePath
        visible: root.backgroundImagePath !== ""
    }

    Component.onCompleted: {
        var defJson = root.isCut
            ? '[{"qty":2,"price":0,"discount":0},{"qty":4,"price":0,"discount":0},{"qty":6,"price":0,"discount":0},{"qty":8,"price":0,"discount":0},{"qty":10,"price":0,"discount":0}]'
            : '[{"qty":1,"price":0,"discount":0},{"qty":2,"price":0,"discount":0},{"qty":3,"price":0,"discount":0},{"qty":4,"price":0,"discount":0},{"qty":5,"price":0,"discount":0}]'
        var optKey = root.isCut ? "print_options_cut" : "print_options_nocut"
        var en5Key = root.isCut ? "print_option4_cut_enabled" : "print_option4_nocut_enabled"

        var arr = []
        try {
            arr = JSON.parse(eventManager.getAppSetting(optKey, defJson))
        } catch (e) {
            arr = JSON.parse(defJson)
        }
        if (!Array.isArray(arr) || arr.length === 0)
            arr = JSON.parse(defJson)

        // Pad đủ 5 phần tử bằng giá trị mặc định — tránh lỗi setting cũ chỉ lưu 3-4
        // phần tử khiến ô thứ 4/5 không bao giờ hiện dù đã bật.
        var defArr = JSON.parse(defJson)
        while (arr.length < 5)
            arr.push(arr.length < defArr.length ? defArr[arr.length] : { qty: 1, price: 0, discount: 0 })

        // 4 lựa chọn cố định; lựa chọn thứ 5 chỉ thêm khi được bật
        var opts = arr.slice(0, 4)
        var option5Enabled = eventManager.getAppSetting(en5Key, "false") === "true"
        if (option5Enabled && arr.length >= 5)
            opts.push(arr[4])

        // Chuẩn hoá số → int. Khi bật giá theo nhóm khung (categoryPrice >= 0):
        // giá mỗi lựa chọn = (categoryPrice × số bản in) - discount của lựa chọn đó.
        root.printOptions = opts.map(function(o) {
            var q = parseInt(o.qty, 10) || 0
            var p = parseInt(o.price, 10) || 0
            var d = parseInt(o.discount, 10) || 0
            if (root.categoryPrice >= 0) {
                var base = root.categoryPrice * root.photosToSheets(q)
                p = Math.max(0, base - d)
            }
            return { qty: q, price: p }
        })

        if (root.printOptions.length > 0) {
            root.selectedPhotos = root.printOptions[0].qty
            root.selectedPrice  = root.printOptions[0].price
        }
    }

    // ── Số lượng đang chọn (đơn vị: ảnh in) ─────────────────────────────────
    property int selectedPhotos: root.isCut ? 2 : 1   // số ảnh hiển thị
    property int selectedPrice:  0                     // giá cố định của lựa chọn đang chọn

    // Chuyển đổi số ảnh → số bản gửi máy in
    function photosToSheets(photos) {
        return root.isCut ? Math.round(photos / 2) : photos
    }

    function _resolveImg(p) {
        if (!p) return ""
        if (p.startsWith("http") || p.startsWith("file:") || p.startsWith("qrc:")) return p
        return "file:///" + p.replace(/\\/g, "/")
    }

    // ── Top bar ───────────────────────────────────────────────────────────────
    Item {
        id: topBar
        width: parent.width
        height: 100
        anchors.top: parent.top
        z: 10

        Text {
            anchors.centerIn: parent
            text: ""
            color: "#ffffff"
            font.pixelSize: 36
            font.weight: Font.Bold
            visible: false
        }

        Button {
            id: closeBtn
            visible: root.showCloseButton
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 20
            width: 60
            height: 60
            opacity: closeGuard.holding ? 0.65 : root._chromeOpacity
            Behavior on opacity { NumberAnimation { duration: 180 } }

            background: Rectangle {
                color: closeBtn.hovered ? "#ff4757" : Theme.field
                radius: 30
                border.color: closeBtn.hovered ? "#ff4757" : Theme.border
                border.width: 2
                opacity: closeBtn.hovered ? 1.0 : 0.8
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }
            }

            contentItem: Text {
                text: "✕"
                color: "white"
                font.pixelSize: 28
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            scale: closeBtn.hovered ? 1.08 : 1.0
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

            onClicked: root.closeClicked()
        }

        // Chống khách chạm nhầm khi nút ✕ tàng hình: phải giữ 1 giây mới thoát.
        HoldToActivate {
            id: closeGuard
            anchors.fill: closeBtn
            onActivated: root.closeClicked()
        }
    }

    // ── Main content ──────────────────────────────────────────────────────────
    Item {
        anchors.top: topBar.bottom
        anchors.topMargin: root.portrait ? 24 : 48
        anchors.bottom: parent.bottom
        // Chừa chỗ cho hàng nút Quay lại / Tiếp tục ở dưới để nội dung (thumbnail)
        // không bị dồn xuống sát/khuất sau các nút.
        anchors.bottomMargin: 150
        anchors.left: parent.left
        anchors.right: parent.right

        GridLayout {
            anchors.fill: parent
            anchors.margins: 24
            columns: root.portrait ? 1 : 2
            columnSpacing: root.portrait ? 0 : 36
            rowSpacing: root.portrait ? 24 : 0

            // ── Left: layout preview ──────────────────────────────────────────
            ColumnLayout {
                Layout.preferredWidth: root.portrait ? parent.width : parent.width * 0.42
                Layout.preferredHeight: root.portrait ? parent.height * 0.5 : -1
                Layout.fillWidth: root.portrait
                Layout.fillHeight: !root.portrait
                Layout.alignment: Qt.AlignHCenter
                spacing: 12

                Image {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillHeight: true
                    Layout.preferredWidth: Math.min(parent.width, root.portrait ? 620 : 560)
                    // Ưu tiên ảnh hiển thị của nhóm (nếu có), nếu không thì layout thật.
                    source: root._resolveImg(root.displayImagePath !== "" ? root.displayImagePath : root.layoutPath)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    cache: true
                }
            }

            // ── Right: quantity selector ──────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.maximumWidth: root.portrait ? 720 : 16777215
                Layout.alignment: root.portrait ? Qt.AlignHCenter | Qt.AlignTop : Qt.AlignLeft
                Layout.fillHeight: !root.portrait
                spacing: root.portrait ? 22 : 32

                // Spacer trên — cùng spacer dưới để căn giữa nội dung theo chiều dọc
                Item { Layout.fillHeight: !root.portrait }

                // Các lựa chọn in đã cài sẵn — nút tròn trắng nằm 1 hàng ngang, căn giữa
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: root.portrait ? 16 : 28

                    Repeater {
                        model: root.printOptions

                        delegate: QuantityOption {
                            copies: modelData.qty          // số ảnh in hiển thị
                            fixedPrice: modelData.price    // giá cố định đã cài
                            isCutMode: root.isCut
                            selected: root.selectedPhotos === modelData.qty
                            onChosen: {
                                root.selectedPhotos = modelData.qty
                                root.selectedPrice  = modelData.price
                            }
                        }
                    }
                }

                // Tổng tiền — nền trong suốt, căn giữa cùng hàng nút
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 8
                    spacing: 12

                    Text {
                        text: "Tổng thanh toán:"
                        color: "#c9a94f"
                        font.pixelSize: 20
                        font.bold: true
                    }
                    Text {
                        text: Money.vnd(root.selectedPrice)
                        color: "#f0c040"
                        font.pixelSize: 30
                        font.bold: true
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }

    // ── Nút Quay lại — mũi tên trần căn giữa, chữ nằm dưới (góc dưới trái) ────
    Item {
        id: backPill
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 40
        anchors.bottomMargin: 40
        width: 160; height: 150
        z: 100

        scale: pqBackMouse.pressed ? 0.92 : 1.0
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

        Column {
            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "‹"
                color: "#7A4B2A"
                opacity: pqBackMouse.containsMouse ? 1.0 : 0.85
                font.pixelSize: 84; font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Behavior on opacity { NumberAnimation { duration: 130 } }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Back"
                color: "#7A4B2A"
                opacity: pqBackMouse.containsMouse ? 1.0 : 0.85
                font.pixelSize: 30; font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                Behavior on opacity { NumberAnimation { duration: 130 } }
            }
        }

        MouseArea {
            id: pqBackMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.backClicked()
        }
    }

    // ── Nút Tiếp tục — mũi tên trần căn giữa, chữ nằm dưới (góc dưới phải) ────
    Item {
        id: continueBtn
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 40
        anchors.bottomMargin: 40
        width: 160; height: 150
        z: 100

        scale: pqContMouse.pressed ? 0.92 : 1.0
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

        Column {
            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "›"
                color: "#ad436d"
                opacity: pqContMouse.containsMouse ? 1.0 : 0.9
                font.pixelSize: 84; font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Behavior on opacity { NumberAnimation { duration: 130 } }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Next"
                color: "#ad436d"
                opacity: pqContMouse.containsMouse ? 1.0 : 0.9
                font.pixelSize: 30; font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                Behavior on opacity { NumberAnimation { duration: 130 } }
            }
        }

        MouseArea {
            id: pqContMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                var sheets = root.photosToSheets(root.selectedPhotos)
                root.continueClicked(sheets, root.selectedPrice)
            }
        }
    }

    // ── Inline option button — nút tròn nền trắng ─────────────────────────────
    component QuantityOption: Rectangle {
        id: opt
        implicitWidth:  root.portrait ? 118 : 146
        implicitHeight: implicitWidth
        radius: width / 2
        clip: true
        color: "#ffffff"

        property int  copies: 2       // số ảnh in hiển thị
        property int  fixedPrice: 0   // giá cố định đã cài cho lựa chọn này
        property bool isCutMode: false
        property bool selected: false

        signal chosen()

        scale: optMouse.pressed ? 0.96 : (optMouse.containsMouse ? 1.04 : 1.0)
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

        // ── Nền trắng: trạng thái chọn có sắc ấm nhẹ để vẫn rõ lựa chọn hiện tại ──
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            antialiasing: true
            color: opt.selected ? "#fff6dc" : "#ffffff"
            Behavior on opacity { NumberAnimation { duration: 120 } }
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        // ── Lớp bóng nhẹ để nút tròn tách khỏi nền ảnh ─────────────────────────
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.color: Qt.rgba(0, 0, 0, 0.10)
            border.width: 1
        }

        // ── Viền trạng thái chọn ───────────────────────────────────────────────
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            antialiasing: true
            border.color: opt.selected ? "#7A4B2A" : "#ffffff"
            border.width: opt.selected ? 4 : 2
            Behavior on border.color { ColorAnimation { duration: 120 } }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 2

            Text {
                Layout.preferredWidth: opt.width * 0.86
                text: opt.copies
                color: "#7A4B2A"
                font.pixelSize: root.portrait ? 40 : 48
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                fontSizeMode: Text.Fit
                minimumPixelSize: 28
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                Layout.preferredWidth: opt.width * 0.86
                text: "ảnh in"
                color: "#7A4B2A"
                font.pixelSize: root.portrait ? 13 : 14
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                fontSizeMode: Text.Fit
                minimumPixelSize: 10
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                Layout.preferredWidth: opt.width * 0.86
                text: Money.vnd(opt.fixedPrice)
                color: "#7A4B2A"
                font.pixelSize: root.portrait ? 13 : 14
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                fontSizeMode: Text.Fit
                minimumPixelSize: 9
                Layout.topMargin: 2
                Layout.alignment: Qt.AlignHCenter
            }
        }

        MouseArea {
            id: optMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: opt.chosen()
        }
    }
}
