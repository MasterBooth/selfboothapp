pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects

// Thumbnail tròn dùng chung cho frame / filter / sticker ở bố cục Mode 3.
// Ảnh được cắt (hoặc thu) vào trong một mặt nạ tròn, có vòng viền báo trạng thái chọn.
Item {
    id: root

    property url    source: ""
    property bool   selected: false
    property real   diameter: 120
    // Ký tự hiển thị khi không có ảnh (vd "✕" cho mục "Gốc", "🎨" khi thiếu thumbnail)
    property string placeholder: ""
    property color  fillColor:         "transparent"
    property color  ringColor:         "#5C4033"
    property color  selectedRingColor: "#8B5A2B"
    property int    ringWidth: 2
    property int    selectedRingWidth: 5
    property int    fitMode: Image.PreserveAspectCrop
    // Thu ảnh vào trong vòng tròn. Với fitMode = PreserveAspectFit, ảnh vuông sẽ bị
    // vòng tròn cắt 4 góc nếu inset = 0; đặt ≈ 0.15 * diameter để ảnh nội tiếp trọn vẹn.
    property real   inset: 0
    property bool   maskToCircle: root.fitMode === Image.PreserveAspectCrop
    // Đặt false cho frame: ảnh đại diện (frame_image_) có thể bị thay ở màn Cài Đặt,
    // cache sẽ giữ lại bản cũ.
    property bool   cacheImage: true

    signal clicked()

    readonly property bool hasImage: root.source.toString() !== ""

    width:  diameter
    height: diameter

    // Chỉ thu nhỏ khi nhấn — KHÔNG phóng to lúc chọn, vì hàng cuộn ngang có clip:true
    // sẽ cắt mất phần viền lồi ra. Trạng thái chọn báo bằng vòng viền dày hơn.
    scale: thumbArea.pressed ? 0.95 : 1.0
    Behavior on scale { NumberAnimation { duration: 110 } }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.fillColor
        visible: root.fillColor.a > 0
    }

    Image {
        id: thumbImage
        anchors.fill: parent
        anchors.margins: root.inset
        source: root.source
        fillMode: root.fitMode
        asynchronous: true
        cache: root.cacheImage
        visible: root.hasImage
        // Giới hạn giải nén: file frame là ảnh in (vd 1181×3543). Không đặt sourceSize
        // thì mỗi thumbnail sẽ giữ nguyên bitmap full-res trong RAM.
        sourceSize: Qt.size(Math.round(root.diameter * 3), Math.round(root.diameter * 3))

        // Chỉ cần mặt nạ khi ảnh phủ kín ô vuông (Crop). Ở chế độ Fit + inset ảnh đã
        // nằm gọn trong vòng tròn → bỏ layer để khỏi tốn thêm một FBO mỗi thumbnail.
        layer.enabled: root.maskToCircle
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: circleMask
        }
    }

    // Mặt nạ tròn (pattern giống ModePicker.qml)
    Item {
        id: circleMask
        anchors.fill: thumbImage
        layer.enabled: true
        visible: false
        Rectangle { anchors.fill: parent; radius: width / 2; color: "black" }
    }

    Text {
        anchors.centerIn: parent
        visible: !root.hasImage
        text: root.placeholder
        color: root.selected ? root.selectedRingColor : root.ringColor
        font.pixelSize: Math.round(root.diameter * 0.32)
        font.bold: true
    }

    // Vòng viền vẽ đè lên ảnh
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.color: root.selected ? root.selectedRingColor : root.ringColor
        border.width: root.selected ? root.selectedRingWidth : root.ringWidth
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        id: thumbArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
