#pragma once

#include <QObject>
#include <QString>
#include <QVariantMap>

class PropertyHelper : public QObject {
    Q_OBJECT

public:
    explicit PropertyHelper(QObject* parent = nullptr);

    // Convert raw values to display strings
    Q_INVOKABLE QString isoToString(int value) const;
    Q_INVOKABLE QString apertureToString(int value) const;
    Q_INVOKABLE QString shutterSpeedToString(int value) const;
    Q_INVOKABLE QString exposureCompToString(int value) const;
    Q_INVOKABLE QString whiteBalanceToString(int value) const;
    Q_INVOKABLE QString driveModeToString(int value) const;
    Q_INVOKABLE QString aeModeToString(int value) const;
    Q_INVOKABLE QString afModeToString(int value) const;
    Q_INVOKABLE QString batteryLevelToString(int value) const;
    Q_INVOKABLE QString imageQualityToString(int value) const;
};
