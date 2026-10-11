#pragma once

/*=============================================================================
 * ErrorHandler.h - Centralized error handling with retry logic
 *
 * Layer: Core
 * Purpose: Provides retry-with-backoff for DEVICE_BUSY/OBJECT_NOTREADY,
 *          error code to string translation, and logging callback.
 *============================================================================*/

#include "Types.h"
#ifndef NOMINMAX
#define NOMINMAX
#endif

#include <functional>
#include <string>
#include <thread>
#include <chrono>
#include <ctime>
#include <cstdio>
#include <iostream>

namespace CameraApp {

// ---------------------------------------------------------------------------
// Log severity
// ---------------------------------------------------------------------------
enum class LogLevel {
    Debug,
    Info,
    Warning,
    Error
};

// ---------------------------------------------------------------------------
// Log callback type - UI layer can hook into this
// ---------------------------------------------------------------------------
using LogCallback = std::function<void(LogLevel level, const std::string& message)>;

// ---------------------------------------------------------------------------
// ErrorHandler - Static utility for error handling and retry logic
// ---------------------------------------------------------------------------
class ErrorHandler {
public:
    // Retry configuration
    struct RetryConfig {
        int    maxRetries       = 10;
        int    baseDelayMs      = 500;
        int    maxDelayMs       = 5000;
        double backoffMultiplier = 1.5;
    };

    // Set global log callback
    static void setLogCallback(LogCallback callback) {
        s_logCallback = std::move(callback);
    }

    // Set retry configuration
    static void setRetryConfig(const RetryConfig& config) {
        s_retryConfig = config;
    }

    // -----------------------------------------------------------------------
    // Execute an SDK operation with automatic retry on DEVICE_BUSY
    // -----------------------------------------------------------------------
    static Result executeWithRetry(
        const std::string& operationName,
        std::function<EdsError()> operation)
    {
        int delayMs = s_retryConfig.baseDelayMs;

        for (int attempt = 0; attempt <= s_retryConfig.maxRetries; ++attempt) {
            EdsError err = operation();

            if (err == EDS_ERR_OK) {
                return Result::Ok();
            }

            bool retryable = (err == EDS_ERR_DEVICE_BUSY) ||
                             (err == EDS_ERR_OBJECT_NOTREADY);

            if (!retryable || attempt == s_retryConfig.maxRetries) {
                std::string msg = operationName + " failed: " + errorToString(err);
                log(LogLevel::Error, msg);
                return Result::FromError(err, msg);
            }

            log(LogLevel::Debug,
                operationName + " busy, retry " + std::to_string(attempt + 1) +
                "/" + std::to_string(s_retryConfig.maxRetries) +
                " in " + std::to_string(delayMs) + "ms");

            std::this_thread::sleep_for(std::chrono::milliseconds(delayMs));
            int nextDelay = static_cast<int>(delayMs * s_retryConfig.backoffMultiplier);
            delayMs = (nextDelay < s_retryConfig.maxDelayMs)
                      ? nextDelay : s_retryConfig.maxDelayMs;
        }

        return Result::FromError(EDS_ERR_DEVICE_BUSY,
                                 operationName + " exceeded max retries");
    }

    // -----------------------------------------------------------------------
    // Check result and log if error
    // -----------------------------------------------------------------------
    static Result check(EdsError err, const std::string& context = "") {
        if (err == EDS_ERR_OK) {
            return Result::Ok();
        }
        std::string msg = context.empty()
            ? errorToString(err)
            : context + " failed with ErrorCode 0x" + toHexString(err) + ": " + errorToString(err);
        log(LogLevel::Error, msg);
        return Result::FromError(err, msg);
    }

    // -----------------------------------------------------------------------
    // Error code to human-readable string
    // -----------------------------------------------------------------------
    static std::string errorToString(EdsError err) {
        switch (err) {
        case EDS_ERR_OK:                        return "OK";
        case EDS_ERR_UNIMPLEMENTED:             return "Not implemented";
        case EDS_ERR_INTERNAL_ERROR:            return "Internal error";
        case EDS_ERR_MEM_ALLOC_FAILED:          return "Memory allocation failed";
        case EDS_ERR_OPERATION_CANCELLED:        return "Operation cancelled";
        case EDS_ERR_INCOMPATIBLE_VERSION:       return "Incompatible version";
        case EDS_ERR_NOT_SUPPORTED:             return "Not supported";
        case EDS_ERR_UNEXPECTED_EXCEPTION:       return "Unexpected exception";
        case EDS_ERR_PROTECTION_VIOLATION:       return "Protection violation";
        case EDS_ERR_MISSING_SUBCOMPONENT:       return "Missing subcomponent";
        case EDS_ERR_SELECTION_UNAVAILABLE:      return "Selection unavailable";
        // File errors
        case EDS_ERR_FILE_IO_ERROR:             return "File I/O error";
        case EDS_ERR_FILE_TOO_MANY_OPEN:        return "Too many open files";
        case EDS_ERR_FILE_NOT_FOUND:            return "File not found";
        case EDS_ERR_FILE_OPEN_ERROR:           return "File open error";
        case EDS_ERR_FILE_CLOSE_ERROR:          return "File close error";
        case EDS_ERR_FILE_SEEK_ERROR:           return "File seek error";
        case EDS_ERR_FILE_TELL_ERROR:           return "File tell error";
        case EDS_ERR_FILE_READ_ERROR:           return "File read error";
        case EDS_ERR_FILE_WRITE_ERROR:          return "File write error";
        case EDS_ERR_FILE_PERMISSION_ERROR:     return "File permission error";
        case EDS_ERR_FILE_DISK_FULL_ERROR:      return "Disk full";
        // Device errors
        case EDS_ERR_DEVICE_NOT_FOUND:          return "Device not found";
        case EDS_ERR_DEVICE_BUSY:               return "Device busy";
        case EDS_ERR_DEVICE_INVALID:            return "Device invalid";
        case EDS_ERR_DEVICE_EMERGENCY:          return "Device emergency";
        case EDS_ERR_DEVICE_MEMORY_FULL:        return "Device memory full";
        case EDS_ERR_DEVICE_INTERNAL_ERROR:     return "Device internal error";
        case EDS_ERR_DEVICE_INVALID_PARAMETER:  return "Device invalid parameter";
        case EDS_ERR_DEVICE_NO_DISK:            return "No memory card";
        case EDS_ERR_DEVICE_DISK_ERROR:         return "Memory card error";
        // Communication errors
        case EDS_ERR_COMM_PORT_IS_IN_USE:       return "Port in use";
        case EDS_ERR_COMM_DISCONNECTED:         return "Disconnected";
        case EDS_ERR_COMM_DEVICE_INCOMPATIBLE:  return "Device incompatible";
        case EDS_ERR_COMM_BUFFER_FULL:          return "Buffer full";
        case EDS_ERR_COMM_USB_BUS_ERR:          return "USB bus error";
        // Property errors
        case EDS_ERR_PROPERTIES_UNAVAILABLE:    return "Properties unavailable";
        case EDS_ERR_PROPERTIES_MISMATCH:       return "Properties mismatch";
        case EDS_ERR_PROPERTIES_NOT_LOADED:     return "Properties not loaded";
        // Parameter errors
        case EDS_ERR_INVALID_PARAMETER:         return "Invalid parameter";
        case EDS_ERR_INVALID_HANDLE:            return "Invalid handle";
        case EDS_ERR_INVALID_POINTER:           return "Invalid pointer";
        case EDS_ERR_INVALID_INDEX:             return "Invalid index";
        // Session errors
        case EDS_ERR_SESSION_NOT_OPEN:          return "Session not open";
        case EDS_ERR_SESSION_ALREADY_OPEN:      return "Session already open";
        // PTP errors
        case EDS_ERR_OBJECT_NOTREADY:           return "Object not ready";
        case EDS_ERR_CANNOT_MAKE_OBJECT:        return "Cannot make object";
        // Take picture errors
        case EDS_ERR_TAKE_PICTURE_AF_NG:        return "AF failed";
        case EDS_ERR_TAKE_PICTURE_MIRROR_UP_NG: return "Mirror up failed";
        case EDS_ERR_TAKE_PICTURE_NO_CARD_NG:   return "No memory card";
        case EDS_ERR_TAKE_PICTURE_CARD_NG:      return "Card error";
        case EDS_ERR_TAKE_PICTURE_CARD_PROTECT_NG: return "Card protected";
        case EDS_ERR_TAKE_PICTURE_NO_LENS_NG:   return "No lens attached";
        case EDS_ERR_TAKE_PICTURE_STROBO_CHARGE_NG: return "Flash charging";
        default:
            return "Unknown error (0x" +
                   toHexString(static_cast<uint32_t>(err)) + ")";
        }
    }

    // -----------------------------------------------------------------------
    // Logging
    // -----------------------------------------------------------------------
    static void log(LogLevel level, const std::string& message) {
        if (s_logCallback) {
            std::string timestamped = timestamp() + " " + levelStr(level) + " " + message;
            s_logCallback(level, timestamped);
        }
        // Always output to debug console for diagnostics
        std::string dbgLine = timestamp() + " " + levelStr(level) + " " + message + "\n";
        OutputDebugStringA(dbgLine.c_str());
        printf("%s", dbgLine.c_str());
        fflush(stdout);

        // Also append to file for reliable testing
        if (FILE* f = fopen("app.log", "a")) {
            fprintf(f, "%s", dbgLine.c_str());
            fclose(f);
        }
    }

    // Debug log with function name context
    static void dbg(const std::string& func, const std::string& message) {
        log(LogLevel::Debug, "[" + func + "] " + message);
    }

    // Debug log for SDK error codes
    static void dbgResult(const std::string& func, const std::string& op, EdsError err) {
        std::string msg = "[" + func + "] " + op + " => " +
            (err == EDS_ERR_OK ? "OK" : "ErrorCode 0x" + toHexString(err) + " (" + errorToString(err) + ")");
        log(err == EDS_ERR_OK ? LogLevel::Debug : LogLevel::Error, msg);
    }

private:
    static std::string timestamp() {
        auto now = std::chrono::system_clock::now();
        auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
            now.time_since_epoch()) % 1000;
        std::time_t t = std::chrono::system_clock::to_time_t(now);
        struct tm tm_buf;
        localtime_s(&tm_buf, &t);
        char buf[32];
        snprintf(buf, sizeof(buf), "%02d:%02d:%02d.%03d",
            tm_buf.tm_hour, tm_buf.tm_min, tm_buf.tm_sec, (int)ms.count());
        return buf;
    }

    static const char* levelStr(LogLevel level) {
        switch (level) {
        case LogLevel::Debug:   return "[DBG]";
        case LogLevel::Info:    return "[INF]";
        case LogLevel::Warning: return "[WRN]";
        case LogLevel::Error:   return "[ERR]";
        default: return "[???]";
        }
    }

    static std::string toHexString(uint32_t val) {
        char buf[16];
        snprintf(buf, sizeof(buf), "%08X", val);
        return buf;
    }

    static inline LogCallback  s_logCallback;
    static inline RetryConfig  s_retryConfig;
};

} // namespace CameraApp
