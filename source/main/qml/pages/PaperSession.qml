import QtQuick
import QtQuick.Controls
import "session"
import "../theme"

Item {
    id: root

    property int eventId: -1
    property var eventData: null
    property string sessionId: ""
    property int pendingRetakeIndex: -1
    property var allCapturedPhotos: []

    signal exitSession()

    StackView {
        id: sessionStack
        anchors.fill: parent
        initialItem: layoutPaperComponent

        pushEnter: Transition { PropertyAnimation { property: "opacity"; from: 0; to: 1; duration: 180 } }
        pushExit: Transition { PropertyAnimation { property: "opacity"; from: 1; to: 0; duration: 180 } }
        popEnter: Transition { PropertyAnimation { property: "opacity"; from: 0; to: 1; duration: 180 } }
        popExit: Transition { PropertyAnimation { property: "opacity"; from: 1; to: 0; duration: 180 } }
    }

    function preparePaperEvent() {
        root.eventId = eventManager.getOrCreatePaperEvent()
        if (root.eventId <= 0) {
            console.warn("PaperSession: cannot create Paper event")
            return
        }

        eventManager.updateShootingMode(root.eventId, 2, 0)
        root.eventData = eventManager.getEventDetails(root.eventId)

        var path = (root.eventData && root.eventData.rawPath) ? root.eventData.rawPath : ""
        if (path !== "")
            cameraController.setSessionStoragePath(path)

        root.createNewSession()
    }

    function createNewSession() {
        if (root.eventId <= 0)
            return
        root.sessionId = sessionManager.createSession(root.eventId, machineAuth.hwid)
        cameraController.setCurrentSessionId(root.sessionId)
    }

    function uploadCollageToS3(path) {
        if (root.sessionId === "" || !path || path === "")
            return
        var clean = path.toString().replace(/^(file:\/{3})|(file:)/, "")
        if (Qt.platform.os === "windows")
            clean = clean.replace(/^(file:\/\/\/)/, "")
        clean = decodeURIComponent(clean)
        s3Uploader.setCurrentEventRawPath((root.eventData && root.eventData.rawPath) ? root.eventData.rawPath : "")
        s3Uploader.uploadCollage(clean, machineAuth.hwid, root.eventId, root.sessionId)
    }

    function handleSessionCompletion(photos, collagePath, transforms) {

        var photosToUpload = (root.allCapturedPhotos && root.allCapturedPhotos.length > 0)
                             ? root.allCapturedPhotos : photos
        if (root.eventId > 0 && root.sessionId !== "") {
            eventManager.saveSessionPhotosAsync(root.eventId, photosToUpload, root.sessionId)
        }

        root.uploadCollageToS3(collagePath)
        root.pushToResultScreen(photos, collagePath, transforms)
    }

    function pushToResultScreen(photos, collagePath, transforms) {
        sessionStack.push(resultScreenComponent, {
            "photos": photos,
            "collagePath": collagePath,
            "displayPath": collagePath,
            "eventId": root.eventId,
            "eventData": root.eventData,
            "sessionId": root.sessionId,
            "hwid": machineAuth.hwid,
            "prePaymentDone": false,
            "prePaymentCutMode": false,
            "prePaymentCopies": 1
        })

        if (root.eventData && root.eventData.autoCut)
            eventManager.processCollageNoCutAsync(root.eventId, photos, transforms || [], root.sessionId)
    }

    Component.onCompleted: preparePaperEvent()

    Connections {
        target: eventManager


        function onPreviewReady(previewPath) {
            if (previewPath && previewPath !== "") {
                var current = sessionStack.currentItem
                if (current && typeof current.updateDisplayPath === "function")
                    current.updateDisplayPath(previewPath)
            }
        }
    }

    Component {
        id: layoutPaperComponent
        LayoutPaper {
            onBackRequested: root.exitSession()
            onStartRequested: function(layoutPath, slotCount) {
                if (root.eventId <= 0)
                    root.preparePaperEvent()
                if (root.eventId <= 0)
                    return

                eventManager.updateEventLayout(root.eventId, layoutPath)
                eventManager.updateShootingMode(root.eventId, 2, 0)
                root.eventData = eventManager.getEventDetails(root.eventId)

                sessionStack.push(captureScreenComponent, {
                    "totalPhotos": Math.max(1, slotCount),
                    "sessionPath": (root.eventData && root.eventData.rawPath) ? root.eventData.rawPath : "",
                    "sessionId": root.sessionId
                })
            }
        }
    }

    Component {
        id: captureScreenComponent
        CaptureScreen {
            eventId: root.eventId
            eventData: root.eventData
            onCloseClicked: sessionStack.pop(null)
            onSessionFinished: function(photos, collagePath) {
                root.allCapturedPhotos = photos
                root.handleSessionCompletion(photos, collagePath, [])
            }
            onManualCaptureFinished: function(photos) {
                root.allCapturedPhotos = photos
                var props = {
                    "eventId": root.eventId,
                    "eventData": root.eventData,
                    "layoutPath": (root.eventData && root.eventData.selectedLayout) ? root.eventData.selectedLayout : "",
                    "capturedPhotos": photos,
                    "sessionId": root.sessionId,
                    "newPhotoIndex": root.pendingRetakeIndex,
                    "preAssignedPhotos": photos
                }
                root.pendingRetakeIndex = -1
                sessionStack.push(photoCompositionScreenComponent, props)
            }
            onPhotoReady: function(photoPath, photoIndex) {
                if (!photoPath || photoPath === "" || root.eventId <= 0 || !root.sessionId)
                    return
                eventManager.enqueueCaptureAsset(root.eventId, photoPath, root.sessionId, photoIndex)
            }
        }
    }

    Component {
        id: photoCompositionScreenComponent
        PhotoCompositionScreen {
            eventId: root.eventId
            onCloseClicked: sessionStack.pop(null)
            onBackClicked: sessionStack.pop()
            onRetakeRequested: function(photoIndex) {
                root.pendingRetakeIndex = photoIndex
                sessionStack.pop()
                Qt.callLater(function() {
                    var captureScreen = sessionStack.currentItem
                    if (captureScreen && photoIndex >= 0 && typeof captureScreen.retakePhoto === "function")
                        captureScreen.retakePhoto(photoIndex)
                })
            }
            onSessionFinished: function(photos, collagePath, transforms) {
                root.handleSessionCompletion(photos, collagePath, transforms)
            }
        }
    }

    Component {
        id: resultScreenComponent
        ResultScreen {
            onFinished: {
                root.createNewSession()
                sessionStack.pop(null)
            }
            onBackClicked: sessionStack.pop()
            onQrCodeClicked: {
                sessionStack.push(qrScreenComponent, {
                    "sessionId": sessionId,
                    "eventId": root.eventId,
                    "hwid": machineAuth.hwid,
                    "uploadedUrl": uploadedUrl
                })
            }
        }
    }

    Component {
        id: qrScreenComponent
        QRScreen {
            onBackClicked: sessionStack.pop()
            onNextSessionClicked: {
                root.createNewSession()
                sessionStack.pop(null)
            }
        }
    }
}
