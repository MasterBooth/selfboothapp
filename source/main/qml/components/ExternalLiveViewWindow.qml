import QtQuick
import QtQuick.Window

Window {
    id: root
    title: "External Live View"
    color: "#000000"
    visible: false

    property int screenIndex: 1
    property bool fullscreen: true
    property bool displayActive: false
    property bool _viewerHeld: false

    function _screenAt(index) {
        if (typeof displayManager === "undefined" || !displayManager)
            return null
        return displayManager.screenAt(index)
    }

    function _screenGeometry(index) {
        if (typeof displayManager === "undefined" || !displayManager)
            return null
        return displayManager.screenGeometry(index)
    }

    function openWindow() {
        var target = _screenAt(screenIndex)
        if (!target) {
            console.warn("ExternalLiveViewWindow: invalid screen index", screenIndex)
            closeWindow()
            return
        }

        var geom = _screenGeometry(screenIndex)
        root.screen = target
        if (geom) {
            root.x = geom.x
            root.y = geom.y
            if (fullscreen) {
                root.width = geom.width
                root.height = geom.height
            } else {
                root.width = Math.min(Math.max(root.width, 640), geom.width)
                root.height = Math.min(Math.max(root.height, 360), geom.height)
            }
        }

        console.log("ExternalLiveViewWindow: open screen", screenIndex,
                    geom ? geom.name : "",
                    geom ? (geom.width + "x" + geom.height + "@" + geom.x + "," + geom.y) : "",
                    "fullscreen", fullscreen)

        root.visible = true
        if (fullscreen)
            root.showFullScreen()
        else
            root.show()
        _syncViewer()
    }

    function closeWindow() {
        root.visible = false
        _syncViewer()
    }

    function _syncViewer() {
        var want = root.visible && root.displayActive
        if (want && !_viewerHeld) {
            cameraController.addLiveViewViewer()
            _viewerHeld = true
        } else if (!want && _viewerHeld) {
            cameraController.removeLiveViewViewer()
            _viewerHeld = false
        }
    }

    onVisibleChanged: _syncViewer()
    onDisplayActiveChanged: _syncViewer()
    Component.onDestruction: {
        if (_viewerHeld) {
            cameraController.removeLiveViewViewer()
            _viewerHeld = false
        }
    }

    LiveViewPanel {
        anchors.fill: parent
        isActive: cameraController.isLiveViewActive
        consuming: root.visible && root.displayActive
        fillMode: Image.PreserveAspectCrop
        imageMargins: 0
        panelRadius: 0
        panelBorderWidth: 0
        color: "#000000"
        border.color: "transparent"
    }
}
