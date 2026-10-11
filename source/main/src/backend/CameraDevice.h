#pragma once

#ifdef _WIN32
#include <windows.h>
#endif

#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QImage>
#include <memory>
#include "EDSDK.h"

class CameraDevice : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString name READ name CONSTANT)
    Q_PROPERTY(QString port READ port CONSTANT)
    Q_PROPERTY(bool connected READ isConnected NOTIFY connectedChanged)
    Q_PROPERTY(bool liveViewActive READ isLiveViewActive NOTIFY liveViewActiveChanged)

    // Camera properties
    Q_PROPERTY(int iso READ iso NOTIFY isoChanged)
    Q_PROPERTY(int aperture READ aperture NOTIFY apertureChanged)
    Q_PROPERTY(int shutterSpeed READ shutterSpeed NOTIFY shutterSpeedChanged)
    Q_PROPERTY(int exposureCompensation READ exposureCompensation NOTIFY exposureCompensationChanged)
    Q_PROPERTY(int imageQuality READ imageQuality NOTIFY imageQualityChanged)
    Q_PROPERTY(int whiteBalance READ whiteBalance NOTIFY whiteBalanceChanged)
    Q_PROPERTY(int driveMode READ driveMode NOTIFY driveModeChanged)
    Q_PROPERTY(int aeMode READ aeMode NOTIFY aeModeChanged)
    Q_PROPERTY(int afMode READ afMode NOTIFY afModeChanged)
    Q_PROPERTY(int batteryLevel READ batteryLevel NOTIFY batteryLevelChanged)
    Q_PROPERTY(int availableShots READ availableShots NOTIFY availableShotsChanged)

    // Property descriptors (available values)
    Q_PROPERTY(QVariantList isoValues READ isoValues NOTIFY isoValuesChanged)
    Q_PROPERTY(QVariantList apertureValues READ apertureValues NOTIFY apertureValuesChanged)
    Q_PROPERTY(QVariantList shutterSpeedValues READ shutterSpeedValues NOTIFY shutterSpeedValuesChanged)
    Q_PROPERTY(QVariantList imageQualityValues READ imageQualityValues NOTIFY imageQualityValuesChanged)
    Q_PROPERTY(QVariantList whiteBalanceValues READ whiteBalanceValues NOTIFY whiteBalanceValuesChanged)
    Q_PROPERTY(QVariantList driveModeValues READ driveModeValues NOTIFY driveModeValuesChanged)

public:
    explicit CameraDevice(EdsCameraRef camera, const EdsDeviceInfo& info, QObject* parent = nullptr);
    ~CameraDevice();

    // Basic info
    QString name() const { return m_name; }
    QString port() const { return m_port; }
    bool isConnected() const { return m_connected; }
    bool isLiveViewActive() const { return m_liveViewActive; }

    // Property getters
    int iso() const { return m_iso; }
    int aperture() const { return m_aperture; }
    int shutterSpeed() const { return m_shutterSpeed; }
    int exposureCompensation() const { return m_exposureCompensation; }
    int imageQuality() const { return m_imageQuality; }
    int whiteBalance() const { return m_whiteBalance; }
    int driveMode() const { return m_driveMode; }
    int aeMode() const { return m_aeMode; }
    int afMode() const { return m_afMode; }
    int batteryLevel() const { return m_batteryLevel; }
    int availableShots() const { return m_availableShots; }

    // Property descriptors
    QVariantList isoValues() const { return m_isoValues; }
    QVariantList apertureValues() const { return m_apertureValues; }
    QVariantList shutterSpeedValues() const { return m_shutterSpeedValues; }
    QVariantList imageQualityValues() const { return m_imageQualityValues; }
    QVariantList whiteBalanceValues() const { return m_whiteBalanceValues; }
    QVariantList driveModeValues() const { return m_driveModeValues; }

    EdsCameraRef handle() const { return m_camera; }

public slots:
    // Connection
    bool openSession();
    void closeSession();

    // Shooting
    bool takePicture();
    bool pressShutterButton(int state); // 0=off, 1=halfway, 2=completely

    // Property setters
    bool setIso(int value);
    bool setAperture(int value);
    bool setShutterSpeed(int value);
    bool setExposureCompensation(int value);
    bool setImageQuality(int value);
    bool setWhiteBalance(int value);
    bool setDriveMode(int value);
    bool setSaveTo(int value); // 1=Camera, 2=Host, 3=Both

    // Live View
    bool startLiveView();
    bool stopLiveView();
    QImage downloadLiveViewImage();

    // Refresh all properties
    void refreshProperties();
    void refreshPropertyDescriptors();

signals:
    void connectedChanged();
    void liveViewActiveChanged();
    void isoChanged();
    void apertureChanged();
    void shutterSpeedChanged();
    void exposureCompensationChanged();
    void imageQualityChanged();
    void whiteBalanceChanged();
    void driveModeChanged();
    void aeModeChanged();
    void afModeChanged();
    void batteryLevelChanged();
    void availableShotsChanged();

    void isoValuesChanged();
    void apertureValuesChanged();
    void shutterSpeedValuesChanged();
    void imageQualityValuesChanged();
    void whiteBalanceValuesChanged();
    void driveModeValuesChanged();

    void error(const QString& message);
    void pictureDownloaded(const QString& path);
    void liveViewImageReady(const QImage& image);

private:
    bool setPropertyUInt32(EdsPropertyID propId, EdsUInt32 value);
    EdsUInt32 getPropertyUInt32(EdsPropertyID propId);
    void getPropertyDesc(EdsPropertyID propId, QVariantList& outList);

    // Event handlers (static for EDSDK callback)
    static EdsError EDSCALLBACK handlePropertyEvent(EdsPropertyEvent inEvent, EdsPropertyID inPropertyID, EdsUInt32 inParam, EdsVoid* inContext);
    static EdsError EDSCALLBACK handleObjectEvent(EdsObjectEvent inEvent, EdsBaseRef inRef, EdsVoid* inContext);
    static EdsError EDSCALLBACK handleStateEvent(EdsStateEvent inEvent, EdsUInt32 inEventData, EdsVoid* inContext);

    EdsCameraRef m_camera = nullptr;
    QString m_name;
    QString m_port;
    bool m_connected = false;
    bool m_liveViewActive = false;

    // Current property values
    int m_iso = 0;
    int m_aperture = 0;
    int m_shutterSpeed = 0;
    int m_exposureCompensation = 0;
    int m_imageQuality = 0;
    int m_whiteBalance = 0;
    int m_driveMode = 0;
    int m_aeMode = 0;
    int m_afMode = 0;
    int m_batteryLevel = 0;
    int m_availableShots = 0;

    // Available values
    QVariantList m_isoValues;
    QVariantList m_apertureValues;
    QVariantList m_shutterSpeedValues;
    QVariantList m_imageQualityValues;
    QVariantList m_whiteBalanceValues;
    QVariantList m_driveModeValues;
};
