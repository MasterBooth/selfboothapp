// SdkGuard.h -- Structured Exception Handling wrapper for FUJIFILM X SDK calls.
//
// XAPI.dll runs closed-source native code over a USB/PTP transport. A cable
// yanked mid-transfer, a firmware hiccup, or an unexpected state can make an
// XSDK_* export dereference a bad pointer and raise a hardware exception
// (0xC0000005 access violation, etc.). Without a guard that fault propagates out
// of the DLL and terminates the whole booth process -- unacceptable for an
// unattended event kiosk that must simply reconnect and carry on.
//
// sdkGuardL() runs a callable that performs one SDK call under __try/__except.
// If a hardware exception fires, it is caught HERE, logged, `faulted` is set, and
// XSDK_ERROR is returned instead of crashing. Callers treat a fault as a lost
// session and drive the normal disconnect -> reconnect path.
//
// IMPORTANT: this frame constructs no C++ object that needs unwinding (the
// callable arrives by reference), so __try/__except is legal under /EHsc. Under
// /EHsc a hardware SEH exception does NOT run C++ destructors; that is fine here
// because on a fault we tear the whole camera object down and rebuild it.
#pragma once

#include <windows.h>
#include "XsdkApi.h"   // XSDK_ERROR / XSDK_COMPLETE
#include "Logger.h"

// Filter kept separate so GetExceptionCode() is captured for logging without
// putting a function call inside the __except() expression.
inline int sdkSehFilter(unsigned long code, unsigned long* out) {
    *out = code;
    return EXCEPTION_EXECUTE_HANDLER;
}

template <typename Fn>
long sdkGuardL(const char* tag, const char* what, bool& faulted, Fn&& fn) {
    unsigned long code = 0;
    __try {
        return fn();
    }
    __except (sdkSehFilter(GetExceptionCode(), &code)) {
        faulted = true;
        Logger::instance().error(tag,
            "SEH fault 0x%08lX in XAPI.dll during %s -- treating as disconnect",
            code, what);
        return XSDK_ERROR;
    }
}
