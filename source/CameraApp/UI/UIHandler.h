#pragma once

/*=============================================================================
 * UIHandler.h - Bridges CameraFacade events to the Win32 MainWindow UI
 *
 * Purpose: Implements ICameraCallback. Receives events from SDK threads
 *          and marshals them to the UI thread via MainWindow methods
 *          (which use PostMessage for thread safety).
 *============================================================================*/

#include "../Interface/ICameraCallback.h"
#include "../Interface/CameraFacade.h"
#include "MainWindow.h"
#include "PropertyLabels.h"

#include <thread>

namespace CameraApp {

class UIHandler : public ICameraCallback {
public:
    UIHandler(MainWindow& window, CameraFacade& facade)
        : m_window(window), m_facade(facade) {}

    // -----------------------------------------------------------------------
    // Connection
    // -----------------------------------------------------------------------
    void onCameraConnected(const std::string& cameraName) override {
        ErrorHandler::dbg("UIHandler::onCameraConnected", "Trạng thái phản hồi: Connected to " + cameraName);
        m_window.setConnectedState(true);
        m_window.setStatus("Connected: " + cameraName);

        // Update camera info bar
        const CameraState* state = m_facade.cameraState();
        if (state) {
            std::string info = cameraName +
                "  |  Battery: " + std::to_string(state->batteryLevel()) + "%" +
                "  |  Shots: " + std::to_string(state->availableShots());
            m_window.setCameraInfo(info.c_str());
        }

        // Load property combos on a background thread to not block UI
        std::thread([this]() {
            ComThreadGuard comGuard;
            refreshAllPropertyCombos();
        }).detach();
    }

    void onCameraDisconnected() override {
        m_window.setConnectedState(false);
        m_window.setCameraInfo("No camera connected");
        m_window.setStatus("Disconnected");
    }

    // -----------------------------------------------------------------------
    // Property changes
    // -----------------------------------------------------------------------
    void onPropertyChanged(EdsPropertyID propertyId, EdsUInt32 value) override {
        // Update the corresponding combo to reflect new value
        switch (propertyId) {
        case kEdsPropID_ISOSpeed:
            selectComboValue(m_window, ID_COMBO_ISO, (EdsInt32)value);
            break;
        case kEdsPropID_Av:
            selectComboValue(m_window, ID_COMBO_AV, (EdsInt32)value);
            break;
        case kEdsPropID_Tv:
            selectComboValue(m_window, ID_COMBO_TV, (EdsInt32)value);
            break;
        case kEdsPropID_WhiteBalance:
            selectComboValue(m_window, ID_COMBO_WB, (EdsInt32)value);
            break;
        case kEdsPropID_ImageQuality:
            selectComboValue(m_window, ID_COMBO_QUALITY, (EdsInt32)value);
            break;
        case kEdsPropID_MeteringMode:
            selectComboValue(m_window, ID_COMBO_METERING, (EdsInt32)value);
            break;
        case kEdsPropID_BatteryLevel:
        case kEdsPropID_AvailableShots: {
            const CameraState* s = m_facade.cameraState();
            if (s) {
                std::string info = s->modelName() +
                    "  |  Battery: " + std::to_string(s->batteryLevel()) + "%" +
                    "  |  Shots: " + std::to_string(s->availableShots());
                m_window.setCameraInfo(info.c_str());
            }
            break;
        }
        }
    }

    void onPropertyDescChanged(EdsPropertyID propertyId,
                                const PropertyDescriptor& desc) override {
        const CameraState* state = m_facade.cameraState();
        if (!state) return;

        switch (propertyId) {
        case kEdsPropID_ISOSpeed:
            fillCombo(ID_COMBO_ISO, desc, isoLabels(), state->iso());
            break;
        case kEdsPropID_Av:
            fillCombo(ID_COMBO_AV, desc, avLabels(), state->av());
            break;
        case kEdsPropID_Tv:
            fillCombo(ID_COMBO_TV, desc, tvLabels(), state->tv());
            break;
        case kEdsPropID_WhiteBalance:
            fillCombo(ID_COMBO_WB, desc, wbLabels(), state->whiteBalance());
            break;
        case kEdsPropID_ImageQuality:
            fillCombo(ID_COMBO_QUALITY, desc, qualityLabels(), state->imageQuality());
            break;
        case kEdsPropID_MeteringMode:
            fillCombo(ID_COMBO_METERING, desc, meteringLabels(), state->meteringMode());
            break;
        }
    }

    // -----------------------------------------------------------------------
    // Capture
    // -----------------------------------------------------------------------
    void onDownloadProgress(const std::string& fileName,
                            EdsUInt32 percent) override {
        m_window.setStatus("Downloading " + fileName + "... " +
                           std::to_string(percent) + "%");
    }

    void onFileDownloaded(const DownloadedFile& file) override {
        ErrorHandler::dbg("UIHandler::onFileDownloaded", "Trạng thái phản hồi: Saved file " + file.fileName);
        m_window.notifyFileSaved(file.fileName);
        m_window.setStatus("Saved: " + file.fileName);
    }

    void onCaptureError(EdsError error, const std::string& message) override {
        ErrorHandler::dbg("UIHandler::onCaptureError", "Trạng thái phản hồi: Capture error: " + message);
        m_window.setStatus("Capture error: " + message);
    }

    // -----------------------------------------------------------------------
    // Live View - Use pre-decoded bitmap if available
    // -----------------------------------------------------------------------
    void onLiveViewFrame(const uint8_t* jpegData, size_t dataSize,
                          const LiveViewFrame& metadata) override {
        // Check if streaming thread pre-decoded the frame to bitmap
        if (metadata.decodedBitmap && metadata.bitmapWidth > 0 && metadata.bitmapHeight > 0) {
            // ✅ Use pre-decoded bitmap (fast, no decoding needed in paint!)
            m_window.updateLiveViewFrame(metadata.decodedBitmap,
                                        metadata.bitmapWidth,
                                        metadata.bitmapHeight);
        } else if (jpegData && dataSize > 0) {
            // Fallback: Use JPEG bytes (shouldn't happen with new pipeline)
            m_window.updateLiveViewFrame(jpegData, dataSize);
        }
    }

    void onLiveViewStateChanged(bool active) override {
        m_window.setStatus(active ? "Live View active" : "Live View stopped");
    }

    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------
    void onError(const std::string& message) override {
        m_window.setStatus("Error: " + message);
    }

    void onStatusMessage(const std::string& message) override {
        m_window.setStatus(message);
    }

    // -----------------------------------------------------------------------
    // Refresh all property combos from current state
    // -----------------------------------------------------------------------
    void refreshAllPropertyCombos() {
        const CameraState* state = m_facade.cameraState();
        if (!state) return;

        auto loadCombo = [&](EdsPropertyID propId, int comboId,
                             const std::map<EdsInt32, std::string>& labels,
                             EdsUInt32 currentVal) {
            PropertyDescriptor desc;
            m_facade.getPropertyDescriptor(propId, desc);
            fillCombo(comboId, desc, labels, currentVal);
        };

        loadCombo(kEdsPropID_ISOSpeed, ID_COMBO_ISO, isoLabels(), state->iso());
        loadCombo(kEdsPropID_Av, ID_COMBO_AV, avLabels(), state->av());
        loadCombo(kEdsPropID_Tv, ID_COMBO_TV, tvLabels(), state->tv());
        loadCombo(kEdsPropID_WhiteBalance, ID_COMBO_WB, wbLabels(), state->whiteBalance());
        loadCombo(kEdsPropID_ImageQuality, ID_COMBO_QUALITY, qualityLabels(), state->imageQuality());
        loadCombo(kEdsPropID_MeteringMode, ID_COMBO_METERING, meteringLabels(), state->meteringMode());

        // Populate Color Temperature combo
        populateColorTemperatureCombo();
    }

    void populateColorTemperatureCombo() {
        // Get supported color temperatures
        auto temps = m_facade.getSupportedColorTemperatures();
        HWND combo = m_window.getComboByID(ID_COMBO_COLORTEMP);
        if (!combo) return;

        SendMessage(combo, CB_RESETCONTENT, 0, 0);

        // Add each temperature option
        EdsUInt32 currentTemp = m_facade.getCurrentColorTemperature();
        int selectIndex = 0;

        for (size_t i = 0; i < temps.size(); ++i) {
            SendMessageA(combo, CB_ADDSTRING, 0, (LPARAM)temps[i].label.c_str());
            SendMessage(combo, CB_SETITEMDATA, i, temps[i].kelvin);

            if (temps[i].kelvin == currentTemp) {
                selectIndex = i;
            }
        }

        SendMessage(combo, CB_SETCURSEL, selectIndex, 0);

        // Update Kelvin edit box with current value
        HWND editKelvin = m_window.getKelvinEdit();
        if (editKelvin) {
            char buf[32];
            snprintf(buf, sizeof(buf), "%u", currentTemp);
            SetWindowTextA(editKelvin, buf);
        }
    }

private:
    // Fill a combo box with property descriptor values + labels
    void fillCombo(int comboId,
                   const PropertyDescriptor& desc,
                   const std::map<EdsInt32, std::string>& labelMap,
                   EdsUInt32 currentValue) {
        std::vector<std::pair<EdsInt32, std::string>> items;
        for (auto val : desc.values) {
            items.push_back({ val, labelForValue(labelMap, val) });
        }
        m_window.setPropertyComboItems(comboId, items, (EdsInt32)currentValue);
    }

    // Select the combo item that matches a value
    void selectComboValue(MainWindow& win, int comboId, EdsInt32 value) {
        HWND combo = GetDlgItem(win.handle(), comboId);
        if (!combo) return;

        int count = (int)SendMessage(combo, CB_GETCOUNT, 0, 0);
        for (int i = 0; i < count; ++i) {
            EdsInt32 itemVal = (EdsInt32)SendMessage(combo, CB_GETITEMDATA, i, 0);
            if (itemVal == value) {
                SendMessage(combo, CB_SETCURSEL, i, 0);
                return;
            }
        }
    }

    MainWindow&   m_window;
    CameraFacade& m_facade;
};

} // namespace CameraApp
