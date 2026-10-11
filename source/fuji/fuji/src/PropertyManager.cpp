#include "PropertyManager.h"
#include "Logger.h"

static const char* TAG = "PropMgr";

// ============================ ISO / sensitivity =============================

bool PropertyManager::setIso(long iso) {
    CameraContext::Lock lk(m_ctx->mtx);
    if (!m_ctx->handle || !m_ctx->lib->SetSensitivity) return false;
    if (m_ctx->lib->SetSensitivity(m_ctx->handle, iso) != XSDK_COMPLETE) {
        m_ctx->lastError();
        return false;
    }
    return true;
}

bool PropertyManager::getIso(long& iso) {
    CameraContext::Lock lk(m_ctx->mtx);
    if (!m_ctx->handle || !m_ctx->lib->GetSensitivity) return false;
    return m_ctx->lib->GetSensitivity(m_ctx->handle, &iso) == XSDK_COMPLETE;
}

// Two-pass cap through the dedicated XSDK_CapSensitivity export:
//   pass 1: (&count, NULL)   -> count
//   pass 2: (&count, buffer) -> values
std::vector<long> PropertyManager::capIso() {
    std::vector<long> out;
    CameraContext::Lock lk(m_ctx->mtx);
    if (!m_ctx->handle || !m_ctx->lib->CapSensitivity) return out;

    long count = 0;
    if (m_ctx->lib->CapSensitivity(m_ctx->handle, &count, nullptr) != XSDK_COMPLETE || count <= 0)
        return out;
    out.resize(static_cast<size_t>(count));
    if (m_ctx->lib->CapSensitivity(m_ctx->handle, &count, out.data()) != XSDK_COMPLETE) {
        out.clear();
        return out;
    }
    out.resize(static_cast<size_t>(count));
    return out;
}

// ============================== Shutter speed ==============================

bool PropertyManager::setShutterSpeed(long code, long bulb) {
    CameraContext::Lock lk(m_ctx->mtx);
    if (!m_ctx->handle || !m_ctx->lib->SetShutterSpeed) return false;
    if (m_ctx->lib->SetShutterSpeed(m_ctx->handle, code, bulb) != XSDK_COMPLETE) {
        m_ctx->lastError();
        return false;
    }
    return true;
}

bool PropertyManager::getShutterSpeed(long& code, long& bulb) {
    CameraContext::Lock lk(m_ctx->mtx);
    if (!m_ctx->handle || !m_ctx->lib->GetShutterSpeed) return false;
    bulb = 0;
    return m_ctx->lib->GetShutterSpeed(m_ctx->handle, &code, &bulb) == XSDK_COMPLETE;
}

std::vector<long> PropertyManager::capShutterSpeed() {
    std::vector<long> out;
    CameraContext::Lock lk(m_ctx->mtx);
    if (!m_ctx->handle || !m_ctx->lib->CapShutterSpeed) return out;

    long count = 0, bulbCapable = 0;
    if (m_ctx->lib->CapShutterSpeed(m_ctx->handle, &count, nullptr, &bulbCapable) != XSDK_COMPLETE
        || count <= 0)
        return out;
    out.resize(static_cast<size_t>(count));
    if (m_ctx->lib->CapShutterSpeed(m_ctx->handle, &count, out.data(), &bulbCapable) != XSDK_COMPLETE) {
        out.clear();
        return out;
    }
    out.resize(static_cast<size_t>(count));
    return out;
}

// ================================ Aperture =================================

bool PropertyManager::setAperture(long fnumberX100) {
    CameraContext::Lock lk(m_ctx->mtx);
    if (!m_ctx->handle || !m_ctx->lib->SetAperture) return false;
    if (m_ctx->lib->SetAperture(m_ctx->handle, fnumberX100) != XSDK_COMPLETE) {
        m_ctx->lastError();
        return false;
    }
    return true;
}

bool PropertyManager::getAperture(long& fnumberX100) {
    CameraContext::Lock lk(m_ctx->mtx);
    if (!m_ctx->handle || !m_ctx->lib->GetAperture) return false;
    return m_ctx->lib->GetAperture(m_ctx->handle, &fnumberX100) == XSDK_COMPLETE;
}

// XSDK_CapAperture takes a zoom position; 0 == current position.
std::vector<long> PropertyManager::capAperture() {
    std::vector<long> out;
    CameraContext::Lock lk(m_ctx->mtx);
    if (!m_ctx->handle || !m_ctx->lib->CapAperture) return out;

    long count = 0;
    if (m_ctx->lib->CapAperture(m_ctx->handle, 0, &count, nullptr) != XSDK_COMPLETE || count <= 0)
        return out;
    out.resize(static_cast<size_t>(count));
    if (m_ctx->lib->CapAperture(m_ctx->handle, 0, &count, out.data()) != XSDK_COMPLETE) {
        out.clear();
        return out;
    }
    out.resize(static_cast<size_t>(count));
    return out;
}

// ============================== Exposure bias ==============================

bool PropertyManager::setExposureBias(long code) {
    CameraContext::Lock lk(m_ctx->mtx);
    if (!m_ctx->handle || !m_ctx->lib->SetExposureBias) return false;
    if (m_ctx->lib->SetExposureBias(m_ctx->handle, code) != XSDK_COMPLETE) {
        m_ctx->lastError();
        return false;
    }
    return true;
}

bool PropertyManager::getExposureBias(long& code) {
    CameraContext::Lock lk(m_ctx->mtx);
    if (!m_ctx->handle || !m_ctx->lib->GetExposureBias) return false;
    return m_ctx->lib->GetExposureBias(m_ctx->handle, &code) == XSDK_COMPLETE;
}

std::vector<long> PropertyManager::capExposureBias() {
    std::vector<long> out;
    CameraContext::Lock lk(m_ctx->mtx);
    if (!m_ctx->handle || !m_ctx->lib->CapExposureBias) return out;

    long count = 0;
    if (m_ctx->lib->CapExposureBias(m_ctx->handle, &count, nullptr) != XSDK_COMPLETE || count <= 0)
        return out;
    out.resize(static_cast<size_t>(count));
    if (m_ctx->lib->CapExposureBias(m_ctx->handle, &count, out.data()) != XSDK_COMPLETE) {
        out.clear();
        return out;
    }
    out.resize(static_cast<size_t>(count));
    return out;
}

// =============== Model-dependent properties (SetProp/GetProp) ===============

// Generic 2-pass enumeration through the model-dependent CapProp.
// Pass 1: (&count, NULL) -> count. Pass 2: (&count, buffer) -> values.
std::vector<long> PropertyManager::capProp(long apiCapCode) {
    std::vector<long> out;
    if (!m_ctx->lib->CapProp) return out;
    long count = 0;
    if (m_ctx->lib->CapProp(m_ctx->handle, apiCapCode, 0, &count, (long*)nullptr) != XSDK_COMPLETE
        || count <= 0)
        return out;
    out.resize(static_cast<size_t>(count));
    long n = count;
    if (m_ctx->lib->CapProp(m_ctx->handle, apiCapCode, 0, &n, out.data()) != XSDK_COMPLETE) {
        out.clear();
        return out;
    }
    out.resize(static_cast<size_t>(n));
    return out;
}

bool PropertyManager::setFilmSimulation(long sim) {
    CameraContext::Lock lk(m_ctx->mtx);
    if (!m_ctx->handle) return false;
    return m_ctx->lib->SetProp(m_ctx->handle, API_CODE_SetFilmSimulationMode, 1, sim) == XSDK_COMPLETE;
}

bool PropertyManager::getFilmSimulation(long& sim) {
    CameraContext::Lock lk(m_ctx->mtx);
    if (!m_ctx->handle) return false;
    return m_ctx->lib->GetProp(m_ctx->handle, API_CODE_GetFilmSimulationMode, 1, &sim) == XSDK_COMPLETE;
}

bool PropertyManager::setImageQuality(long q) {
    CameraContext::Lock lk(m_ctx->mtx);
    if (!m_ctx->handle) return false;
    return m_ctx->lib->SetProp(m_ctx->handle, API_CODE_SetImageQuality, 1, q) == XSDK_COMPLETE;
}

bool PropertyManager::getImageQuality(long& q) {
    CameraContext::Lock lk(m_ctx->mtx);
    if (!m_ctx->handle) return false;
    return m_ctx->lib->GetProp(m_ctx->handle, API_CODE_GetImageQuality, 1, &q) == XSDK_COMPLETE;
}

std::vector<long> PropertyManager::capImageQuality() {
    CameraContext::Lock lk(m_ctx->mtx);
    if (!m_ctx->handle) return {};
    return capProp(API_CODE_CapImageQuality);
}

bool PropertyManager::setImageSize(long size) {
    CameraContext::Lock lk(m_ctx->mtx);
    if (!m_ctx->handle) return false;
    return m_ctx->lib->SetProp(m_ctx->handle, API_CODE_SetImageSize, 1, size) == XSDK_COMPLETE;
}

bool PropertyManager::getImageSize(long& size) {
    CameraContext::Lock lk(m_ctx->mtx);
    if (!m_ctx->handle) return false;
    return m_ctx->lib->GetProp(m_ctx->handle, API_CODE_GetImageSize, 1, &size) == XSDK_COMPLETE;
}

std::vector<long> PropertyManager::capImageSize() {
    CameraContext::Lock lk(m_ctx->mtx);
    if (!m_ctx->handle) return {};
    return capProp(API_CODE_CapImageSize);
}

bool PropertyManager::setWhiteBalance(long wb) {
    CameraContext::Lock lk(m_ctx->mtx);
    if (!m_ctx->handle) return false;
    return m_ctx->lib->SetProp(m_ctx->handle, API_CODE_SetWhiteBalanceMode, 1, wb) == XSDK_COMPLETE;
}

bool PropertyManager::getWhiteBalance(long& wb) {
    CameraContext::Lock lk(m_ctx->mtx);
    if (!m_ctx->handle) return false;
    return m_ctx->lib->GetProp(m_ctx->handle, API_CODE_GetWhiteBalanceMode, 1, &wb) == XSDK_COMPLETE;
}
