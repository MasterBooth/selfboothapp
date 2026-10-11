#include "CameraManager.h"
#include "EDSDKHelper.h"
#include <QDebug>
#include <QThread>

CameraManager::CameraManager(QObject *parent) : QObject(parent) {}

CameraManager::~CameraManager() {
  clearCameras();
  if (m_sdkInitialized) {
    terminateSDK();
  }
}

QList<QObject *> CameraManager::cameras() const {
  QList<QObject *> list;
  for (auto *cam : m_cameras) {
    list.append(cam);
  }
  return list;
}

bool CameraManager::initializeSDK() {
  if (m_sdkInitialized)
    return true;

  if (edsdk::initializeSDK()) {
    m_sdkInitialized = true;
    emit sdkInitializedChanged();
    refreshCameraList();
    return true;
  } else {
    setLastError("Failed to initialize Canon SDK");
    return false;
  }
}

void CameraManager::terminateSDK() {
  clearCameras();
  edsdk::terminateSDK();
  m_sdkInitialized = false;
  emit sdkInitializedChanged();
}

void CameraManager::refreshCameraList() {
  if (!m_sdkInitialized) {
    setLastError("SDK not initialized");
    return;
  }

  clearCameras();

  EdsCameraListRef cameraList = nullptr;
  EdsError err = EdsGetCameraList(&cameraList);

  if (err != EDS_ERR_OK) {
    setLastError(QString("Failed to get camera list: %1")
                     .arg(QString::fromStdString(edsdk::errorToString(err))));
    return;
  }

  EdsUInt32 count = 0;
  err = EdsGetChildCount(cameraList, &count);

  if (err == EDS_ERR_OK && count > 0) {
    for (EdsUInt32 i = 0; i < count; i++) {
      EdsCameraRef camera = nullptr;
      err = EdsGetChildAtIndex(cameraList, i, &camera);

      if (err == EDS_ERR_OK && camera) {
        EdsDeviceInfo deviceInfo;
        err = EdsGetDeviceInfo(camera, &deviceInfo);

        if (err == EDS_ERR_OK) {
          CameraDevice *device = new CameraDevice(camera, deviceInfo, this);
          connect(device, &CameraDevice::error, this, &CameraManager::error);
          connect(device, &CameraDevice::liveViewImageReady, this, [this](const QImage &img) {
              emit liveViewImageReady(img);
              emit newFrameAvailable();
          });
          m_cameras.append(device);
        }

        EdsRelease(camera);
      }
    }
  }

  EdsRelease(cameraList);
  emit camerasChanged();

  // Auto-select first camera if available
  if (!m_cameras.isEmpty() && m_currentIndex < 0) {
    setCurrentIndex(0);
  }
}

void CameraManager::setCurrentIndex(int index) {
  if (index == m_currentIndex)
    return;

  // Cleanup previous camera connection
  if (m_currentCamera) {
    disconnect(m_currentCamera, &CameraDevice::error, this, &CameraManager::error);
    m_currentCamera->closeSession();
  }

  if (index < 0 || index >= m_cameras.size()) {
    m_currentIndex = -1;
    m_currentCamera = nullptr;
  } else {
    m_currentIndex = index;
    m_currentCamera = m_cameras.at(index);
    // Connect error signal
    if (m_currentCamera) {
      connect(m_currentCamera, &CameraDevice::error, this, &CameraManager::error);
      
      // Auto connect to the new camera
      if (!m_currentCamera->openSession()) {
        setLastError("Failed to auto-connect to camera");
      }
    }
  }

  emit currentIndexChanged();
  emit currentCameraChanged();
}

bool CameraManager::connectCurrentCamera() {
  if (!m_currentCamera) {
    setLastError("No camera selected");
    return false;
  }
  return m_currentCamera->openSession();
}

void CameraManager::disconnectCurrentCamera() {
  if (m_currentCamera) {
    m_currentCamera->closeSession();
  }
}

bool CameraManager::takePicture() {
  if (!m_currentCamera) {
    setLastError("No camera selected");
    return false;
  }
  
  bool restartLiveView = m_isLiveViewActive;
  if (restartLiveView) {
      qDebug() << "Manager: Auto-stopping Live View for capture";
      stopLiveView();
      QThread::msleep(500);
  }

  bool result = m_currentCamera->takePicture();

  if (restartLiveView) {
      qDebug() << "Manager: Auto-restoring Live View";
      QThread::msleep(1000);
      startLiveView();
  }
  return result;
}

bool CameraManager::startLiveView() {
  qDebug() << "CameraManager::startLiveView() called";
  if (!m_currentCamera) {
    qDebug() << "CameraManager::startLiveView() - No camera selected";
    setLastError("No camera selected");
    return false;
  }
  qDebug() << "CameraManager::startLiveView() - Calling camera->startLiveView()";
  bool result = m_currentCamera->startLiveView();
  qDebug() << "CameraManager::startLiveView() - Result:" << result;
  if (result) {
      m_isLiveViewActive = true;
      emit isLiveViewActiveChanged();
  }
  return result;
}

bool CameraManager::stopLiveView() {
  qDebug() << "CameraManager::stopLiveView() called";
  if (!m_currentCamera) {
    qDebug() << "CameraManager::stopLiveView() - No camera selected";
    setLastError("No camera selected");
    return false;
  }
  qDebug() << "CameraManager::stopLiveView() - Calling camera->stopLiveView()";
  bool result = m_currentCamera->stopLiveView();
  qDebug() << "CameraManager::stopLiveView() - Result:" << result;
  m_isLiveViewActive = false;
  emit isLiveViewActiveChanged();
  return result;
}

void CameraManager::clearCameras() {
  if (m_currentCamera) {
    m_currentCamera = nullptr;
    emit currentCameraChanged();
  }
  m_currentIndex = -1;
  emit currentIndexChanged();

  qDeleteAll(m_cameras);
  m_cameras.clear();
  emit camerasChanged();
}

void CameraManager::setLastError(const QString &error) {
  m_lastError = error;
  emit lastErrorChanged();
  emit this->error(error);
}
