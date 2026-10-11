#include "CameraDevice.h"
#include "EDSDKHelper.h"
#include "AppPaths.h"
#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QThread>

CameraDevice::CameraDevice(EdsCameraRef camera, const EdsDeviceInfo &info,
                           QObject *parent)
    : QObject(parent), m_camera(camera),
      m_name(QString::fromLocal8Bit(info.szDeviceDescription)),
      m_port(QString::fromLocal8Bit(info.szPortName)) {
  // Retain camera reference
  EdsRetain(m_camera);
}

CameraDevice::~CameraDevice() {
  if (m_connected) {
    closeSession();
  }
  if (m_camera) {
    EdsRelease(m_camera);
    m_camera = nullptr;
  }
}

bool CameraDevice::openSession() {
  if (m_connected)
    return true;

  EdsError err = EdsOpenSession(m_camera);
  if (err != EDS_ERR_OK) {
    emit error(QString("Failed to open session: %1")
                   .arg(QString::fromStdString(edsdk::errorToString(err))));
    return false;
  }

  // Register event handlers
  EdsSetPropertyEventHandler(m_camera, kEdsPropertyEvent_All,
                             handlePropertyEvent, this);
  EdsSetObjectEventHandler(m_camera, kEdsObjectEvent_All, handleObjectEvent,
                           this);
  EdsSetCameraStateEventHandler(m_camera, kEdsStateEvent_All, handleStateEvent,
                                this);

  // Set save to host
  EdsUInt32 saveTo = kEdsSaveTo_Host;
  EdsSetPropertyData(m_camera, kEdsPropID_SaveTo, 0, sizeof(saveTo), &saveTo);

  // Set capacity (tell camera PC has space)
  EdsCapacity capacity = {0x7FFFFFFF, 0x1000, 1};
  EdsSetCapacity(m_camera, capacity);

  m_connected = true;
  emit connectedChanged();

  // Load initial properties
  refreshProperties();
  refreshPropertyDescriptors();

  return true;
}

void CameraDevice::closeSession() {
  if (!m_connected)
    return;

  if (m_liveViewActive) {
    stopLiveView();
  }

  EdsCloseSession(m_camera);
  m_connected = false;
  emit connectedChanged();
}

bool CameraDevice::takePicture() {
  if (!m_connected) {
    emit error("Camera not connected");
    return false;
  }

  // Simply send the command. Live View management is handled by CameraManager.
  EdsError err = EdsSendCommand(m_camera, kEdsCameraCommand_TakePicture, 0);
  if (err != EDS_ERR_OK) {
    emit error(QString("Failed to take picture: %1")
                   .arg(QString::fromStdString(edsdk::errorToString(err))));
    return false;
  }
  return true;
}

bool CameraDevice::pressShutterButton(int state) {
  if (!m_connected) {
    emit error("Camera not connected");
    return false;
  }

  EdsUInt32 shutterState;
  switch (state) {
  case 0:
    shutterState = kEdsCameraCommand_ShutterButton_OFF;
    break;
  case 1:
    shutterState = kEdsCameraCommand_ShutterButton_Halfway;
    break;
  case 2:
    shutterState = kEdsCameraCommand_ShutterButton_Completely;
    break;
  default:
    return false;
  }

  EdsError err = EdsSendCommand(m_camera, kEdsCameraCommand_PressShutterButton,
                                shutterState);
  if (err != EDS_ERR_OK) {
    emit error(QString("Failed to press shutter: %1")
                   .arg(QString::fromStdString(edsdk::errorToString(err))));
    return false;
  }
  return true;
}

bool CameraDevice::setPropertyUInt32(EdsPropertyID propId, EdsUInt32 value) {
  if (!m_connected)
    return false;

  EdsError err = EdsSetPropertyData(m_camera, propId, 0, sizeof(value), &value);
  return err == EDS_ERR_OK;
}

EdsUInt32 CameraDevice::getPropertyUInt32(EdsPropertyID propId) {
  EdsUInt32 value = 0;
  if (m_connected) {
    EdsGetPropertyData(m_camera, propId, 0, sizeof(value), &value);
  }
  return value;
}

void CameraDevice::getPropertyDesc(EdsPropertyID propId,
                                   QVariantList &outList) {
  outList.clear();
  if (!m_connected)
    return;

  EdsPropertyDesc desc;
  EdsError err = EdsGetPropertyDesc(m_camera, propId, &desc);
  if (err == EDS_ERR_OK) {
    for (int i = 0; i < desc.numElements; i++) {
      outList.append(static_cast<int>(desc.propDesc[i]));
    }
  }
}

bool CameraDevice::setIso(int value) {
  if (setPropertyUInt32(kEdsPropID_ISOSpeed, value)) {
    m_iso = value;
    emit isoChanged();
    return true;
  }
  return false;
}

bool CameraDevice::setAperture(int value) {
  if (setPropertyUInt32(kEdsPropID_Av, value)) {
    m_aperture = value;
    emit apertureChanged();
    return true;
  }
  return false;
}

bool CameraDevice::setShutterSpeed(int value) {
  if (setPropertyUInt32(kEdsPropID_Tv, value)) {
    m_shutterSpeed = value;
    emit shutterSpeedChanged();
    return true;
  }
  return false;
}

bool CameraDevice::setExposureCompensation(int value) {
  if (setPropertyUInt32(kEdsPropID_ExposureCompensation, value)) {
    m_exposureCompensation = value;
    emit exposureCompensationChanged();
    return true;
  }
  return false;
}

bool CameraDevice::setImageQuality(int value) {
  if (setPropertyUInt32(kEdsPropID_ImageQuality, value)) {
    m_imageQuality = value;
    emit imageQualityChanged();
    return true;
  }
  return false;
}

bool CameraDevice::setWhiteBalance(int value) {
  if (setPropertyUInt32(kEdsPropID_WhiteBalance, value)) {
    m_whiteBalance = value;
    emit whiteBalanceChanged();
    return true;
  }
  return false;
}

bool CameraDevice::setDriveMode(int value) {
  if (setPropertyUInt32(kEdsPropID_DriveMode, value)) {
    m_driveMode = value;
    emit driveModeChanged();
    return true;
  }
  return false;
}

bool CameraDevice::setSaveTo(int value) {
  if (!m_connected)
    return false;

  EdsUInt32 saveTo = value;
  EdsError err = EdsSetPropertyData(m_camera, kEdsPropID_SaveTo, 0,
                                    sizeof(saveTo), &saveTo);
  if (err == EDS_ERR_OK && value != kEdsSaveTo_Camera) {
    // Set capacity for host
    EdsCapacity capacity = {0x7FFFFFFF, 0x1000, 1};
    EdsSetCapacity(m_camera, capacity);
  }
  return err == EDS_ERR_OK;
}

bool CameraDevice::startLiveView() {
  qDebug() << "CameraDevice::startLiveView() called";
  if (!m_connected) return false;
  if (m_liveViewActive) return true;
  
  // 1. Get current EVF Mode
  EdsUInt32 evfMode = 0;
  EdsGetPropertyData(m_camera, kEdsPropID_Evf_Mode, 0, sizeof(evfMode), &evfMode);
  
  EdsUInt32 currentOutputDev = 0;
  EdsGetPropertyData(m_camera, kEdsPropID_Evf_OutputDevice, 0, sizeof(currentOutputDev), &currentOutputDev);
  
  qDebug() << "SDK SAMPLE LOGIC - Current EvfMode:" << evfMode << " OutputDev:" << currentOutputDev;

  // 2. Enable EVF Mode if not active
  EdsError err = EDS_ERR_OK;
  if (evfMode == 0) {
      evfMode = 1;
      // Retry loop (Enhancement over sample code to handle transient busy state)
      for (int i = 0; i < 5; i++) {
        err = EdsSetPropertyData(m_camera, kEdsPropID_Evf_Mode, 0, sizeof(evfMode), &evfMode);
        if (err == EDS_ERR_OK) break;
        if (err == EDS_ERR_DEVICE_BUSY) {
            qDebug() << "StartEvfCommand: DeviceBusy (Mode), retrying..." << i+1;
            QThread::msleep(500);
        } else {
            break;
        }
      }
  }

  // 3. Set Output Device logic (Sample: device |= PC)
  if (err == EDS_ERR_OK) {
      // Re-read output device in case enabling EVF changed it
      EdsGetPropertyData(m_camera, kEdsPropID_Evf_OutputDevice, 0, sizeof(currentOutputDev), &currentOutputDev);
      
      EdsUInt32 device = currentOutputDev | kEdsEvfOutputDevice_PC;
      
      // Only set if different (optimization)
      if (device != currentOutputDev) {
          qDebug() << "StartEvfCommand: Setting OutputDevice to" << device << "(PC | Current)";
          err = EdsSetPropertyData(m_camera, kEdsPropID_Evf_OutputDevice, 0, sizeof(device), &device);
      }
  }

  if (err != EDS_ERR_OK) {
    emit error(QString("Failed to enable Live View (Error %1). SDK Status: Mode=%2 Dev=%3")
                   .arg(err).arg(evfMode).arg(currentOutputDev));
    return false;
  }

  m_liveViewActive = true;
  emit liveViewActiveChanged();
  return true;
}

bool CameraDevice::stopLiveView() {
  qDebug() << "CameraDevice::stopLiveView() called";
  if (!m_connected) return false;
  
  // Always try to stop even if m_liveViewActive is false, to sync state
  m_liveViewActive = false; // Reset flag immediately
  emit liveViewActiveChanged();

  // Disable EVF mode
  qDebug() << "CameraDevice::stopLiveView() - Disabling EVF Mode";
  EdsUInt32 evfMode = 0;
  EdsSetPropertyData(m_camera, kEdsPropID_Evf_Mode, 0, sizeof(evfMode),
                     &evfMode);
                     
  // Set output device off
  qDebug() << "CameraDevice::stopLiveView() - Setting Output Device to TFT";
  EdsUInt32 device = kEdsEvfOutputDevice_TFT;
  EdsSetPropertyData(m_camera, kEdsPropID_Evf_OutputDevice, 0, sizeof(device),
                     &device);

  return true;
}

QImage CameraDevice::downloadLiveViewImage() {
  QImage image;
  // Permissive check: try to download even if flag says false (in case of sync issues)
  if (!m_connected)
    return image;

  EdsStreamRef stream = nullptr;
  EdsEvfImageRef evfImage = nullptr;

  // Create memory stream
  EdsError err = EdsCreateMemoryStream(0, &stream);
  if (err != EDS_ERR_OK)
    return image;

  // Create EVF image reference
  err = EdsCreateEvfImageRef(stream, &evfImage);
  if (err != EDS_ERR_OK) {
    EdsRelease(stream);
    return image;
  }

  // Download EVF image
  err = EdsDownloadEvfImage(m_camera, evfImage);
  if (err == EDS_ERR_OK) {
    // Get stream data
    EdsUInt64 length = 0;
    EdsGetLength(stream, &length);

    if (length > 0) {
      EdsVoid *data = nullptr;
      EdsGetPointer(stream, &data);

      if (data) {
        image.loadFromData(static_cast<const uchar *>(data),
                           static_cast<int>(length), "JPEG");
      }
    }
  }

  EdsRelease(evfImage);
  EdsRelease(stream);

  return image;
}

void CameraDevice::refreshProperties() {
  if (!m_connected)
    return;

  m_iso = getPropertyUInt32(kEdsPropID_ISOSpeed);
  m_aperture = getPropertyUInt32(kEdsPropID_Av);
  m_shutterSpeed = getPropertyUInt32(kEdsPropID_Tv);
  m_exposureCompensation = getPropertyUInt32(kEdsPropID_ExposureCompensation);
  m_imageQuality = getPropertyUInt32(kEdsPropID_ImageQuality);
  m_whiteBalance = getPropertyUInt32(kEdsPropID_WhiteBalance);
  m_driveMode = getPropertyUInt32(kEdsPropID_DriveMode);
  m_aeMode = getPropertyUInt32(kEdsPropID_AEModeSelect);
  m_afMode = getPropertyUInt32(kEdsPropID_AFMode);
  m_batteryLevel = getPropertyUInt32(kEdsPropID_BatteryLevel);
  m_availableShots = getPropertyUInt32(kEdsPropID_AvailableShots);

  emit isoChanged();
  emit apertureChanged();
  emit shutterSpeedChanged();
  emit exposureCompensationChanged();
  emit imageQualityChanged();
  emit whiteBalanceChanged();
  emit driveModeChanged();
  emit aeModeChanged();
  emit afModeChanged();
  emit batteryLevelChanged();
  emit availableShotsChanged();
}

void CameraDevice::refreshPropertyDescriptors() {
  if (!m_connected)
    return;

  getPropertyDesc(kEdsPropID_ISOSpeed, m_isoValues);
  getPropertyDesc(kEdsPropID_Av, m_apertureValues);
  getPropertyDesc(kEdsPropID_Tv, m_shutterSpeedValues);
  getPropertyDesc(kEdsPropID_ImageQuality, m_imageQualityValues);
  getPropertyDesc(kEdsPropID_WhiteBalance, m_whiteBalanceValues);
  getPropertyDesc(kEdsPropID_DriveMode, m_driveModeValues);

  emit isoValuesChanged();
  emit apertureValuesChanged();
  emit shutterSpeedValuesChanged();
  emit imageQualityValuesChanged();
  emit whiteBalanceValuesChanged();
  emit driveModeValuesChanged();
}

// Static event handlers
EdsError EDSCALLBACK CameraDevice::handlePropertyEvent(
    EdsPropertyEvent inEvent, EdsPropertyID inPropertyID, EdsUInt32 inParam,
    EdsVoid *inContext) {
  Q_UNUSED(inParam);
  CameraDevice *device = static_cast<CameraDevice *>(inContext);
  if (!device)
    return EDS_ERR_OK;

  if (inEvent == kEdsPropertyEvent_PropertyChanged) {
    // Update specific property
    switch (inPropertyID) {
    case kEdsPropID_ISOSpeed:
      device->m_iso = device->getPropertyUInt32(kEdsPropID_ISOSpeed);
      emit device->isoChanged();
      break;
    case kEdsPropID_Av:
      device->m_aperture = device->getPropertyUInt32(kEdsPropID_Av);
      emit device->apertureChanged();
      break;
    case kEdsPropID_Tv:
      device->m_shutterSpeed = device->getPropertyUInt32(kEdsPropID_Tv);
      emit device->shutterSpeedChanged();
      break;
    case kEdsPropID_BatteryLevel:
      device->m_batteryLevel =
          device->getPropertyUInt32(kEdsPropID_BatteryLevel);
      emit device->batteryLevelChanged();
      break;
    case kEdsPropID_AvailableShots:
      device->m_availableShots =
          device->getPropertyUInt32(kEdsPropID_AvailableShots);
      emit device->availableShotsChanged();
      break;
    }
  } else if (inEvent == kEdsPropertyEvent_PropertyDescChanged) {
    device->refreshPropertyDescriptors();
  }

  return EDS_ERR_OK;
}

EdsError EDSCALLBACK CameraDevice::handleObjectEvent(EdsObjectEvent inEvent,
                                                     EdsBaseRef inRef,
                                                     EdsVoid *inContext) {
  CameraDevice *device = static_cast<CameraDevice *>(inContext);
  if (!device) {
    if (inRef)
      EdsRelease(inRef);
    return EDS_ERR_OK;
  }

  if (inEvent == kEdsObjectEvent_DirItemRequestTransfer) {
    // Download the image
    EdsDirectoryItemInfo dirItemInfo;
    EdsError err = EdsGetDirectoryItemInfo(inRef, &dirItemInfo);

    if (err == EDS_ERR_OK) {
      // Create output directory with error checking
      QString outputDir = QDir::currentPath() + "/captured";
      QString errorMsg;
      if (!AppPaths::instance().ensureDirectoryExists(outputDir, &errorMsg)) {
        qCritical() << "Failed to create capture directory:" << errorMsg;
        return EDS_ERR_DIR_NOT_FOUND;
      }

      QString fileName =
          QString("%1/%2_%3")
              .arg(outputDir)
              .arg(QDateTime::currentDateTime().toString("yyyyMMdd_hhmmss"))
              .arg(QString::fromLocal8Bit(dirItemInfo.szFileName));

      EdsStreamRef stream = nullptr;
      err = EdsCreateFileStream(fileName.toLocal8Bit().constData(),
                                kEdsFileCreateDisposition_CreateAlways,
                                kEdsAccess_ReadWrite, &stream);

      if (err == EDS_ERR_OK) {
        err = EdsDownload(inRef, dirItemInfo.size, stream);
        if (err == EDS_ERR_OK) {
          EdsDownloadComplete(inRef);
          emit device->pictureDownloaded(fileName);
        }
        EdsRelease(stream);
      }
    }
  }

  if (inRef)
    EdsRelease(inRef);
  return EDS_ERR_OK;
}

EdsError EDSCALLBACK CameraDevice::handleStateEvent(EdsStateEvent inEvent,
                                                    EdsUInt32 inEventData,
                                                    EdsVoid *inContext) {
  Q_UNUSED(inEventData);
  CameraDevice *device = static_cast<CameraDevice *>(inContext);
  if (!device)
    return EDS_ERR_OK;

  if (inEvent == kEdsStateEvent_Shutdown) {
    device->closeSession();
  }

  return EDS_ERR_OK;
}
