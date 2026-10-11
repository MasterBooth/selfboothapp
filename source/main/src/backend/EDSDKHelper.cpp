#include "EDSDKHelper.h"
#include <atomic>

namespace edsdk {

static std::atomic<bool> g_sdkInitialized{false};

std::string errorToString(EdsError err) {
    switch (err) {
        case EDS_ERR_OK: return "OK";
        case EDS_ERR_UNIMPLEMENTED: return "Not implemented";
        case EDS_ERR_INTERNAL_ERROR: return "Internal error";
        case EDS_ERR_MEM_ALLOC_FAILED: return "Memory allocation failed";
        case EDS_ERR_MEM_FREE_FAILED: return "Memory free failed";
        case EDS_ERR_OPERATION_CANCELLED: return "Operation cancelled";
        case EDS_ERR_INCOMPATIBLE_VERSION: return "Incompatible version";
        case EDS_ERR_NOT_SUPPORTED: return "Not supported";
        case EDS_ERR_UNEXPECTED_EXCEPTION: return "Unexpected exception";
        case EDS_ERR_PROTECTION_VIOLATION: return "Protection violation";
        case EDS_ERR_MISSING_SUBCOMPONENT: return "Missing subcomponent";
        case EDS_ERR_SELECTION_UNAVAILABLE: return "Selection unavailable";
        case EDS_ERR_FILE_IO_ERROR: return "File I/O error";
        case EDS_ERR_FILE_TOO_MANY_OPEN: return "Too many files open";
        case EDS_ERR_FILE_NOT_FOUND: return "File not found";
        case EDS_ERR_FILE_OPEN_ERROR: return "File open error";
        case EDS_ERR_FILE_CLOSE_ERROR: return "File close error";
        case EDS_ERR_FILE_SEEK_ERROR: return "File seek error";
        case EDS_ERR_FILE_TELL_ERROR: return "File tell error";
        case EDS_ERR_FILE_READ_ERROR: return "File read error";
        case EDS_ERR_FILE_WRITE_ERROR: return "File write error";
        case EDS_ERR_FILE_PERMISSION_ERROR: return "File permission error";
        case EDS_ERR_FILE_DISK_FULL_ERROR: return "Disk full";
        case EDS_ERR_FILE_ALREADY_EXISTS: return "File already exists";
        case EDS_ERR_FILE_FORMAT_UNRECOGNIZED: return "File format unrecognized";
        case EDS_ERR_FILE_DATA_CORRUPT: return "File data corrupt";
        case EDS_ERR_FILE_NAMING_NA: return "File naming N/A";
        case EDS_ERR_DIR_NOT_FOUND: return "Directory not found";
        case EDS_ERR_DIR_IO_ERROR: return "Directory I/O error";
        case EDS_ERR_DIR_ENTRY_NOT_FOUND: return "Directory entry not found";
        case EDS_ERR_DIR_ENTRY_EXISTS: return "Directory entry exists";
        case EDS_ERR_DIR_NOT_EMPTY: return "Directory not empty";
        case EDS_ERR_PROPERTIES_UNAVAILABLE: return "Properties unavailable";
        case EDS_ERR_PROPERTIES_MISMATCH: return "Properties mismatch";
        case EDS_ERR_PROPERTIES_NOT_LOADED: return "Properties not loaded";
        case EDS_ERR_INVALID_PARAMETER: return "Invalid parameter";
        case EDS_ERR_INVALID_HANDLE: return "Invalid handle";
        case EDS_ERR_INVALID_POINTER: return "Invalid pointer";
        case EDS_ERR_INVALID_INDEX: return "Invalid index";
        case EDS_ERR_INVALID_LENGTH: return "Invalid length";
        case EDS_ERR_INVALID_FN_POINTER: return "Invalid function pointer";
        case EDS_ERR_INVALID_SORT_FN: return "Invalid sort function";
        case EDS_ERR_DEVICE_NOT_FOUND: return "Device not found";
        case EDS_ERR_DEVICE_BUSY: return "Device busy";
        case EDS_ERR_DEVICE_INVALID: return "Device invalid";
        case EDS_ERR_DEVICE_EMERGENCY: return "Device emergency";
        case EDS_ERR_DEVICE_MEMORY_FULL: return "Device memory full";
        case EDS_ERR_DEVICE_INTERNAL_ERROR: return "Device internal error";
        case EDS_ERR_DEVICE_INVALID_PARAMETER: return "Device invalid parameter";
        case EDS_ERR_DEVICE_NO_DISK: return "No disk in device";
        case EDS_ERR_DEVICE_DISK_ERROR: return "Device disk error";
        case EDS_ERR_DEVICE_CF_GATE_CHANGED: return "CF gate changed";
        case EDS_ERR_DEVICE_DIAL_CHANGED: return "Dial changed";
        case EDS_ERR_DEVICE_NOT_INSTALLED: return "Device not installed";
        case EDS_ERR_DEVICE_STAY_AWAKE: return "Device stay awake";
        case EDS_ERR_DEVICE_NOT_RELEASED: return "Device not released";
        case EDS_ERR_SESSION_NOT_OPEN: return "Session not open";
        case EDS_ERR_INVALID_TRANSACTIONID: return "Invalid transaction ID";
        case EDS_ERR_INCOMPLETE_TRANSFER: return "Incomplete transfer";
        case EDS_ERR_INVALID_STRAGEID: return "Invalid storage ID";
        case EDS_ERR_DEVICEPROP_NOT_SUPPORTED: return "Device property not supported";
        case EDS_ERR_INVALID_OBJECTFORMATCODE: return "Invalid object format code";
        case EDS_ERR_SELF_TEST_FAILED: return "Self test failed";
        case EDS_ERR_PARTIAL_DELETION: return "Partial deletion";
        case EDS_ERR_SPECIFICATION_BY_FORMAT_UNSUPPORTED: return "Specification by format unsupported";
        case EDS_ERR_NO_VALID_OBJECTINFO: return "No valid object info";
        case EDS_ERR_INVALID_CODE_FORMAT: return "Invalid code format";
        case EDS_ERR_UNKNOWN_COMMAND: return "Unknown command";
        case EDS_ERR_OPERATION_REFUSED: return "Operation refused";
        case EDS_ERR_LENS_COVER_CLOSE: return "Lens cover closed";
        case EDS_ERR_LOW_BATTERY: return "Low battery";
        case EDS_ERR_OBJECT_NOTREADY: return "Object not ready";
        case EDS_ERR_CANNOT_MAKE_OBJECT: return "Cannot make object";
        case EDS_ERR_MEMORYSTATUS_NOTREADY: return "Memory status not ready";
        case EDS_ERR_TAKE_PICTURE_AF_NG: return "Take picture AF failed";
        case EDS_ERR_TAKE_PICTURE_RESERVED: return "Take picture reserved";
        case EDS_ERR_TAKE_PICTURE_MIRROR_UP_NG: return "Take picture mirror up failed";
        case EDS_ERR_TAKE_PICTURE_SENSOR_CLEANING_NG: return "Take picture sensor cleaning failed";
        case EDS_ERR_TAKE_PICTURE_SILENCE_NG: return "Take picture silence failed";
        case EDS_ERR_TAKE_PICTURE_NO_CARD_NG: return "Take picture no card";
        case EDS_ERR_TAKE_PICTURE_CARD_NG: return "Take picture card error";
        case EDS_ERR_TAKE_PICTURE_CARD_PROTECT_NG: return "Take picture card protected";
        case EDS_ERR_TAKE_PICTURE_MOVIE_CROP_NG: return "Take picture movie crop failed";
        case EDS_ERR_TAKE_PICTURE_STROBO_CHARGE_NG: return "Take picture strobe charge failed";
        case EDS_ERR_TAKE_PICTURE_NO_LENS_NG: return "Take picture no lens";
        case EDS_ERR_TAKE_PICTURE_SPECIAL_MOVIE_MODE_NG: return "Take picture special movie mode failed";
        case EDS_ERR_TAKE_PICTURE_LV_REL_PROHIBIT_MODE_NG: return "Take picture LV release prohibit mode";
        default: return "Unknown error (" + std::to_string(err) + ")";
    }
}

bool initializeSDK() {
    if (g_sdkInitialized) {
        return true;
    }

    EdsError err = EdsInitializeSDK();
    if (err == EDS_ERR_OK) {
        g_sdkInitialized = true;
        return true;
    }
    return false;
}

void terminateSDK() {
    if (g_sdkInitialized) {
        EdsTerminateSDK();
        g_sdkInitialized = false;
    }
}

bool isSDKInitialized() {
    return g_sdkInitialized;
}

} // namespace edsdk
