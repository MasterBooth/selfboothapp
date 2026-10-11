#ifndef CAMERAMANAGER_H
#define CAMERAMANAGER_H

#include "CameraDevice.h"
#include <QObject>
#include <QList>

class CameraManager : public QObject {
  Q_OBJECT
  Q_PROPERTY(bool sdkInitialized READ sdkInitialized NOTIFY sdkInitializedChanged)
  Q_PROPERTY(QList<QObject*> cameras READ cameras NOTIFY camerasChanged)
  Q_PROPERTY(int currentIndex READ currentIndex WRITE setCurrentIndex NOTIFY currentIndexChanged)
  Q_PROPERTY(CameraDevice* currentCamera READ currentCamera NOTIFY currentCameraChanged)
  Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
  Q_PROPERTY(bool isLiveViewActive READ isLiveViewActive NOTIFY isLiveViewActiveChanged)

public:
  explicit CameraManager(QObject *parent = nullptr);
  ~CameraManager();

  // Properties
  bool sdkInitialized() const { return m_sdkInitialized; }
  QList<QObject*> cameras() const;
  int currentIndex() const { return m_currentIndex; }
  CameraDevice* currentCamera() const { return m_currentCamera; }
  QString lastError() const { return m_lastError; }
  bool isLiveViewActive() const { return m_isLiveViewActive; }

  // SDK Management
  Q_INVOKABLE bool initializeSDK();
  Q_INVOKABLE void terminateSDK();
  Q_INVOKABLE void refreshCameraList();

  // Camera Selection
  Q_INVOKABLE void setCurrentIndex(int index);
  Q_INVOKABLE bool connectCurrentCamera();
  Q_INVOKABLE void disconnectCurrentCamera();

  // Camera Operations
  Q_INVOKABLE bool takePicture();
  Q_INVOKABLE bool startLiveView();
  Q_INVOKABLE bool stopLiveView();

signals:
  void sdkInitializedChanged();
  void camerasChanged();
  void currentIndexChanged();
  void currentCameraChanged();
  void lastErrorChanged();
  void isLiveViewActiveChanged();
  void error(const QString &message);
  void liveViewImageReady(const QImage &image);
  void newFrameAvailable();

private:
  void clearCameras();
  void setLastError(const QString &error);

  bool m_sdkInitialized = false;
  QList<CameraDevice*> m_cameras;
  int m_currentIndex = -1;
  CameraDevice* m_currentCamera = nullptr;
  QString m_lastError;
  bool m_isLiveViewActive = false;
};

#endif // CAMERAMANAGER_H
