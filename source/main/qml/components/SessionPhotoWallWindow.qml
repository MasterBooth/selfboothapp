import QtQuick
import QtQuick.Window

Window {
    id: root
    title: "Session Photos"
    color: "#000000"
    visible: false

    property int screenIndex: 2
    property bool fullscreen: true
    property var photoModel: null
    readonly property int columns: width >= 1800 ? 5 : width >= 1300 ? 4 : 3

    function _screenAt(index) {
        // Guard: context property có thể null nếu binary chưa expose displayManager.
        if (typeof displayManager === "undefined" || !displayManager)
            return null
        return displayManager.screenAt(index)
    }

    function openWindow() {
        var target = _screenAt(screenIndex)
        if (target)
            root.screen = target
        root.visible = true
        if (fullscreen)
            root.showFullScreen()
        else
            root.show()
    }

    function closeWindow() {
        root.visible = false
    }

    GridView {
        id: photoGrid
        anchors.fill: parent
        anchors.margins: 24
        clip: true
        model: root.photoModel
        cellWidth: Math.max(160, Math.floor(width / Math.max(1, root.columns)))
        cellHeight: Math.max(120, Math.floor(cellWidth * 0.66))
        boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
            width: photoGrid.cellWidth
            height: photoGrid.cellHeight

            Image {
                anchors.fill: parent
                anchors.margins: 8
                source: model.path || ""
                fillMode: Image.PreserveAspectFit
                cache: false
                asynchronous: true
                sourceSize: Qt.size(width, height)
            }
        }
    }
}
