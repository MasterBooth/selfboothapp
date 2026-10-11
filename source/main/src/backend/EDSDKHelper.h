#pragma once

#ifdef _WIN32
#include <windows.h>
#endif

#include "EDSDK.h"
#include <string>

namespace edsdk {

// Error code to string conversion
std::string errorToString(EdsError err);

// Initialize SDK (call once at app start)
bool initializeSDK();

// Terminate SDK (call once at app exit)
void terminateSDK();

// Check if SDK is initialized
bool isSDKInitialized();

} // namespace edsdk
