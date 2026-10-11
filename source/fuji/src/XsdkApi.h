// XsdkApi.h
// Runtime loader for FUJIFILM X SDK (XAPI.dll).
//
// We load XAPI.dll dynamically with LoadLibrary/GetProcAddress instead of
// link-time binding to XAPI.lib. Reasons:
//   * The photobooth must start even if no camera / SDK is installed.
//   * We can hot-swap the DLL folder per deployment.
//   * We control exactly which entry points are required.
//
// Every function-pointer typedef below mirrors, byte-for-byte, the prototype
// declared in the official HEADERS/XAPI.H and HEADERS/XAPIOpt.H. Do not change
// the calling convention: XSDK_APIENTRY resolves to `long` with the default
// (cdecl) convention on Windows for these exports.
#pragma once

#include <windows.h>
#include "XAPI.H"      // official header: structs, enums, #defines
#include "XAPIOpt.H"   // official header: extended API codes + value #defines

// ---- Function pointer typedefs (match XAPI.H exactly) ----------------------
typedef long (*PFN_XSDK_Init)(LIB_HANDLE hLib);
typedef long (*PFN_XSDK_Exit)(void);
typedef long (*PFN_XSDK_Detect)(long lInterface, LPSTR pInterface, LPSTR pDeviceName, long* plCount);
typedef long (*PFN_XSDK_Append)(long lInterface, LPSTR pInterface, LPSTR pDeviceName, long* plCount, XSDK_CameraList* pCameraList);
typedef long (*PFN_XSDK_OpenEx)(LPSTR pDevice, XSDK_HANDLE* phCamera, long* plCameraMode, void* pOption);
typedef long (*PFN_XSDK_Close)(XSDK_HANDLE hCamera);
typedef long (*PFN_XSDK_PowerOFF)(XSDK_HANDLE hCamera);

typedef long (*PFN_XSDK_GetErrorNumber)(XSDK_HANDLE hCamera, long* plAPICode, long* plERRCode);
typedef long (*PFN_XSDK_GetVersionString)(LPSTR pVersionString);
typedef long (*PFN_XSDK_GetErrorDetails)(XSDK_HANDLE hCamera, long* plERRCode);

typedef long (*PFN_XSDK_GetDeviceInfo)(XSDK_HANDLE hCamera, XSDK_DeviceInformation* pDevInfo);
typedef long (*PFN_XSDK_GetFirmwareVersion)(XSDK_HANDLE hCamera, LPSTR pFirmwareVersion);
typedef long (*PFN_XSDK_GetLensInfo)(XSDK_HANDLE hCamera, XSDK_LensInformation* pLensInfo);

typedef long (*PFN_XSDK_CapPriorityMode)(XSDK_HANDLE hCamera, long* plNum, long* plMode);
typedef long (*PFN_XSDK_SetPriorityMode)(XSDK_HANDLE hCamera, long lPriorityMode);
typedef long (*PFN_XSDK_GetPriorityMode)(XSDK_HANDLE hCamera, long* plPriorityMode);

typedef long (*PFN_XSDK_CapRelease)(XSDK_HANDLE hCamera, long* plNum, long* plMode);
typedef long (*PFN_XSDK_Release)(XSDK_HANDLE hCamera, long lReleaseMode, long* plShotOpt, long* plAfStatus);
typedef long (*PFN_XSDK_CapReleaseEx)(XSDK_HANDLE hCamera, long* plNum, long* plMode);
typedef long (*PFN_XSDK_ReleaseEx)(XSDK_HANDLE hCamera, long lReleaseMode, long* plShotOpt, long* plAfStatus);
typedef long (*PFN_XSDK_GetReleaseStatus)(XSDK_HANDLE hCamera, long* plReleaseStatus);

typedef long (*PFN_XSDK_GetBufferCapacity)(XSDK_HANDLE hCamera, long* plShootFrameNum, long* plTotalFrameNum);
typedef long (*PFN_XSDK_ReadImageInfo)(XSDK_HANDLE hCamera, XSDK_ImageInformation* pImgInfo);
typedef long (*PFN_XSDK_ReadPreview)(XSDK_HANDLE hCamera, unsigned char* pData, unsigned long lDataSize);
typedef long (*PFN_XSDK_ReadImage)(XSDK_HANDLE hCamera, unsigned char* pData, unsigned long lDataSize);
typedef long (*PFN_XSDK_DeleteImage)(XSDK_HANDLE hCamera);

typedef long (*PFN_XSDK_SetMediaRecord)(XSDK_HANDLE hCamera, long lMediaRecord);
typedef long (*PFN_XSDK_GetMediaRecord)(XSDK_HANDLE hCamera, long* plMediaRecord);

typedef long (*PFN_XSDK_CapSensitivity)(XSDK_HANDLE hCamera, long* plNumSensitivity, long* plSensitivity);
typedef long (*PFN_XSDK_SetSensitivity)(XSDK_HANDLE hCamera, long lSensitivity);
typedef long (*PFN_XSDK_GetSensitivity)(XSDK_HANDLE hCamera, long* plSensitivity);

typedef long (*PFN_XSDK_CapShutterSpeed)(XSDK_HANDLE hCamera, long* plNumShutterSpeed, long* plShutterSpeed, long* plBulbCapable);
typedef long (*PFN_XSDK_SetShutterSpeed)(XSDK_HANDLE hCamera, long lShutterSpeed, long lBulb);
typedef long (*PFN_XSDK_GetShutterSpeed)(XSDK_HANDLE hCamera, long* plShutterSpeed, long* plBulb);

typedef long (*PFN_XSDK_CapAperture)(XSDK_HANDLE hCamera, long lZoomPos, long* plNumAperture, long* plFNumber);
typedef long (*PFN_XSDK_SetAperture)(XSDK_HANDLE hCamera, long lFNumber);
typedef long (*PFN_XSDK_GetAperture)(XSDK_HANDLE hCamera, long* plFNumber);

typedef long (*PFN_XSDK_CapExposureBias)(XSDK_HANDLE hCamera, long* plNumExposureBias, long* plExposureBias);
typedef long (*PFN_XSDK_SetExposureBias)(XSDK_HANDLE hCamera, long lExposureBias);
typedef long (*PFN_XSDK_GetExposureBias)(XSDK_HANDLE hCamera, long* plExposureBias);

// Model-dependent variadic interface (Live View, film simulation, focus, etc.)
typedef long (*PFN_XSDK_CapProp)(XSDK_HANDLE hCamera, long lAPICode, long lAPIParam, ...);
typedef long (*PFN_XSDK_SetProp)(XSDK_HANDLE hCamera, long lAPICode, long lAPIParam, ...);
typedef long (*PFN_XSDK_GetProp)(XSDK_HANDLE hCamera, long lAPICode, long lAPIParam, ...);
