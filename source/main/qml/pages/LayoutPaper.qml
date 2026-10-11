import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../theme"

Rectangle {
    id: root
    width: Window.window ? Window.window._designW : 1920
    height: Window.window ? Window.window._designH : 1080

    signal backRequested()
    signal startRequested(string layoutPath, int slotCount)

    property color _themeBg: Window.window ? Window.window.appBgColor : "#000000"
    property var layouts: []
    property int currentIndex: 0
    property string backgroundImagePath: eventManager.getAppSetting("paper_layout_bg_image", "")
    property bool _lvViewerHeld: false

    function reloadLayouts() {
        layouts = eventManager.getPaperLayouts()
        if (currentIndex >= layouts.length)
            currentIndex = Math.max(0, layouts.length - 1)
    }

    function currentLayout() {
        if (layouts.length === 0 || currentIndex < 0 || currentIndex >= layouts.length)
            return null
        return layouts[currentIndex]
    }

    function currentSlotCount() {
        var layout = currentLayout()
        if (!layout || !layout.path)
            return 0
        return Math.max(1, eventManager.getLayoutSlotCount(layout.path))
    }

    function _syncLiveViewViewer() {
        var want = (StackView.status === StackView.Active || StackView.status === StackView.Activating)
        if (want && !_lvViewerHeld) {
            cameraController.addLiveViewViewer()
            _lvViewerHeld = true
        } else if (!want && _lvViewerHeld) {
            cameraController.removeLiveViewViewer()
            _lvViewerHeld = false
        }
    }

    gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.lighter(root._themeBg, 1.08) }
        GradientStop { position: 1.0; color: Qt.darker(root._themeBg, 1.30) }
    }

    BackgroundMedia {
        anchors.fill: parent
        sourcePath: root.backgroundImagePath
        visible: root.backgroundImagePath !== ""
        z: -1
    }

    LiveViewPanel {
        anchors.fill: parent
        isActive: cameraController.isLiveViewActive
        consuming: true
        panelBorderWidth: 0
        panelRadius: 0
        imageMargins: 0
        fillMode: Image.PreserveAspectFit
        z: 0
    }

    Image {
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        source: root.currentLayout() ? root.currentLayout().path : ""
        fillMode: Image.PreserveAspectFit
        cache: false
        visible: root.layouts.length > 0
        z: 1
    }

    Text {
        anchors.centerIn: parent
        visible: root.layouts.length === 0
        text: "Chưa có khung hình.\nVào Cài đặt → Khung frame để thêm."
        color: "#ffffff"
        font.pixelSize: 28
        horizontalAlignment: Text.AlignHCenter
        z: 2
    }

    Button {
        id: previousButton
        visible: root.layouts.length > 1
        anchors.left: parent.left
        anchors.leftMargin: 56
        anchors.verticalCenter: parent.verticalCenter
        width: 84
        height: 120
        text: "‹"
        font.pixelSize: 72
        onClicked: root.currentIndex = (root.currentIndex + root.layouts.length - 1) % root.layouts.length
        background: Item {}
        contentItem: Text {
            text: previousButton.text
            color: "#ccffffff"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: previousButton.font.pixelSize
        }
        z: 2
    }

    Button {
        id: nextButton
        visible: root.layouts.length > 1
        anchors.right: parent.right
        anchors.rightMargin: 56
        anchors.verticalCenter: parent.verticalCenter
        width: 84
        height: 120
        text: "›"
        font.pixelSize: 72
        onClicked: root.currentIndex = (root.currentIndex + 1) % root.layouts.length
        background: Item {}
        contentItem: Text {
            text: nextButton.text
            color: "#ccffffff"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: nextButton.font.pixelSize
        }
        z: 2
    }

    RowLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 44
        spacing: 18
        z: 3

        Button {
            id: backButton
            text: "Quay lại"
            Layout.preferredWidth: 180
            Layout.preferredHeight: 58
            onClicked: root.backRequested()
            background: Rectangle {
                color: backButton.hovered ? "#2f3542" : "#232832"
                radius: 29
            }
            contentItem: Text {
                text: backButton.text
                color: "#ffffff"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 18
                font.weight: Font.Medium
            }
        }

        Button {
            id: startButton
            text: "Bắt đầu"
            visible: root.layouts.length > 0
            Layout.preferredWidth: 180
            Layout.preferredHeight: 58
            onClicked: {
                var layout = root.currentLayout()
                if (layout && layout.path)
                    root.startRequested(layout.path, root.currentSlotCount())
            }
            background: Rectangle {
                color: startButton.hovered ? "#1e7eea" : "#1976d2"
                radius: 29
            }
            contentItem: Text {
                text: startButton.text
                color: "#ffffff"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 18
                font.weight: Font.Bold
            }
        }
    }

    StackView.onStatusChanged: _syncLiveViewViewer()
    Component.onCompleted: {
        reloadLayouts()
        _syncLiveViewViewer()
    }
    Component.onDestruction: {
        if (_lvViewerHeld) {
            cameraController.removeLiveViewViewer()
            _lvViewerHeld = false
        }
    }
}
