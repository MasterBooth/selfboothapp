import QtQuick
import QtMultimedia

Item {
    id: root

    property string sourcePath: ""
    property bool active: visible
    property int imageFillMode: Image.PreserveAspectCrop
    property int videoFillMode: VideoOutput.PreserveAspectCrop
    readonly property bool isVideo: _isVideoPath(sourcePath)

    function _isVideoPath(path) {
        if (!path || path === "")
            return false
        var clean = path.toString().split("?")[0].split("#")[0].toLowerCase()
        return clean.endsWith(".mp4")
    }

    function resolvedSource(path) {
        if (!path || path === "")
            return ""
        if (path.indexOf("file:") === 0 || path.indexOf("qrc:") === 0 || path.indexOf("http") === 0)
            return path
        return "file:///" + path.replace(/\\/g, "/")
    }

    function syncPlayback() {
        if (root.isVideo && root.active && root.visible && root.sourcePath !== "")
            bgPlayer.play()
        else
            bgPlayer.stop()
    }

    onSourcePathChanged: syncPlayback()
    onActiveChanged: syncPlayback()
    onVisibleChanged: syncPlayback()
    Component.onCompleted: syncPlayback()

    Image {
        anchors.fill: parent
        source: root.isVideo ? "" : root.resolvedSource(root.sourcePath)
        fillMode: root.imageFillMode
        visible: root.sourcePath !== "" && !root.isVideo
        smooth: true
    }

    VideoOutput {
        id: bgVideo
        anchors.fill: parent
        fillMode: root.videoFillMode
        visible: root.sourcePath !== "" && root.isVideo
    }

    AudioOutput {
        id: bgAudio
        muted: true
        volume: 0
    }

    MediaPlayer {
        id: bgPlayer
        source: root.isVideo ? root.resolvedSource(root.sourcePath) : ""
        videoOutput: bgVideo
        audioOutput: bgAudio
        loops: MediaPlayer.Infinite
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.EndOfMedia && root.isVideo && root.active)
                play()
        }
    }
}
