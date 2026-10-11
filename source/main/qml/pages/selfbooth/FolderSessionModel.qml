import QtQuick
import Qt.labs.folderlistmodel
import "../../theme"

// Enumerates session subdirectories under baseDir and builds a ListModel
// with { name, path } entries sorted newest-first up to `limit`.
QtObject {
    id: root

    property string baseDir: ""
    property int limit: 5   // 0 = unlimited
    property alias count: _out.count
    function get(i) { return _out.get(i) }

    function refresh() {
        _dirModel.folder = baseDir !== "" ? "file:///" + baseDir : ""
    }

    onBaseDirChanged: refresh()
    onLimitChanged:   _rebuild()

    property var _dirModel: FolderListModel {
        showDirs:     true
        showFiles:    false
        sortField:    FolderListModel.Name
        sortReversed: true
        onStatusChanged: {
            if (status === FolderListModel.Ready)
                root._rebuild()
        }
        onCountChanged: root._rebuild()
    }

    property var _out: ListModel { id: _out }

    function _rebuild() {
        _out.clear()
        var total = _dirModel.count
        var max   = (root.limit > 0 && root.limit < total) ? root.limit : total
        for (var i = 0; i < max; i++) {
            var name = _dirModel.get(i, "fileName")
            var path = _dirModel.get(i, "filePath")
            if (name && name !== "")
                _out.append({ name: name, path: path })
        }
    }
}
