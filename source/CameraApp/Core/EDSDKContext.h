#pragma once

/*=============================================================================
 * EDSDKContext.h - SDK lifecycle management (Singleton)
 *
 * Layer: Core
 * Purpose: Ensures EdsInitializeSDK/EdsTerminateSDK are called exactly once.
 *          Manages COM initialization for multi-threaded access.
 *============================================================================*/

#include "Types.h"
#include "ErrorHandler.h"
#include <mutex>

namespace CameraApp {

class EDSDKContext {
public:
    // Get singleton instance
    static EDSDKContext& instance() {
        static EDSDKContext ctx;
        return ctx;
    }

    // -----------------------------------------------------------------------
    // Initialize SDK - must be called before any EDSDK operation
    // -----------------------------------------------------------------------
    Result initialize() {
        std::lock_guard<std::mutex> lock(m_mutex);
        if (m_initialized) {
            return Result::Ok();
        }

        EdsError err = EdsInitializeSDK();
        if (err != EDS_ERR_OK) {
            return ErrorHandler::check(err, "EdsInitializeSDK");
        }

        m_initialized = true;
        ErrorHandler::log(LogLevel::Info, "EDSDK initialized successfully");
        return Result::Ok();
    }

    // -----------------------------------------------------------------------
    // Terminate SDK - releases all resources
    // -----------------------------------------------------------------------
    Result terminate() {
        std::lock_guard<std::mutex> lock(m_mutex);
        if (!m_initialized) {
            return Result::Ok();
        }

        EdsError err = EdsTerminateSDK();
        m_initialized = false;

        if (err != EDS_ERR_OK) {
            return ErrorHandler::check(err, "EdsTerminateSDK");
        }

        ErrorHandler::log(LogLevel::Info, "EDSDK terminated");
        return Result::Ok();
    }

    bool isInitialized() const { return m_initialized; }

    // -----------------------------------------------------------------------
    // Initialize COM for current thread (call from each worker thread)
    // -----------------------------------------------------------------------
    static void initComForThread() {
#ifdef _WIN32
        CoInitializeEx(NULL, COINIT_MULTITHREADED);
#endif
    }

    static void uninitComForThread() {
#ifdef _WIN32
        CoUninitialize();
#endif
    }

    ~EDSDKContext() {
        if (m_initialized) {
            EdsTerminateSDK();
            m_initialized = false;
        }
    }

private:
    EDSDKContext() = default;
    EDSDKContext(const EDSDKContext&) = delete;
    EDSDKContext& operator=(const EDSDKContext&) = delete;

    std::mutex m_mutex;
    bool       m_initialized = false;
};

// ---------------------------------------------------------------------------
// RAII guard for COM initialization per thread
// ---------------------------------------------------------------------------
class ComThreadGuard {
public:
    ComThreadGuard()  { EDSDKContext::initComForThread(); }
    ~ComThreadGuard() { EDSDKContext::uninitComForThread(); }

    ComThreadGuard(const ComThreadGuard&) = delete;
    ComThreadGuard& operator=(const ComThreadGuard&) = delete;
};

} // namespace CameraApp
