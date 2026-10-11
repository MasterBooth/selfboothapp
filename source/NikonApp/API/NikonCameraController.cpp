/*=============================================================================
 * NikonCameraController.cpp — Nikon "Control Service Layer" (MAID 3.0) wrapper.
 *
 * Loads ControlServiceLayer.dll dynamically (no import .lib). The capture /
 * shooting-mode / save-media sequence is the one validated in
 * nikon/Module/Win/SampleApp/SimpleTest.cpp.
 *
 * MVP: detect / connect / capture-to-folder / live-view streaming.
 *=============================================================================*/

#include "API/NikonCameraController.h"

#include <windows.h>
#include <mutex>
#include <vector>
#include <string>
#include <set>
#include <algorithm>
#include <filesystem>
#include <chrono>
#include <cstring>
#include <cstdlib>
#include <cmath>
#include <cctype>
#include <limits>

#include "Maid3.h"
#include "Maid3d1.h"

namespace fs = std::filesystem;

namespace NikonApp {

// ===========================================================================
// Helpers
// ===========================================================================
static constexpr uint32_t CANON_PROP_WB        = 0x00000106;
static constexpr uint32_t CANON_PROP_COLORTEMP = 0x00000107;
static constexpr uint32_t CANON_PROP_ISO       = 0x00000402;
static constexpr uint32_t CANON_PROP_AV        = 0x00000405;
static constexpr uint32_t CANON_PROP_TV        = 0x00000406;
static constexpr uint32_t CANON_PROP_EV        = 0x00000407;

static std::wstring toWide(const std::string& s)
{
    if (s.empty()) return std::wstring();
    int n = MultiByteToWideChar(CP_UTF8, 0, s.c_str(), (int)s.size(), nullptr, 0);
    std::wstring w(n, L'\0');
    MultiByteToWideChar(CP_UTF8, 0, s.c_str(), (int)s.size(), &w[0], n);
    return w;
}

static std::string lowerAscii(std::string s)
{
    std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c) {
        return static_cast<char>(std::tolower(c));
    });
    return s;
}

static bool containsText(const std::string& haystack, const char* needle)
{
    return lowerAscii(haystack).find(needle) != std::string::npos;
}

static int firstIntegerIn(const std::string& s)
{
    for (size_t i = 0; i < s.size(); ++i) {
        if (!std::isdigit(static_cast<unsigned char>(s[i]))) continue;
        size_t j = i;
        while (j < s.size() && std::isdigit(static_cast<unsigned char>(s[j]))) ++j;
        try { return std::stoi(s.substr(i, j - i)); } catch (...) { return -1; }
    }
    return -1;
}

static std::string canonWbLabelFromNikon(const std::string& label)
{
    std::string l = lowerAscii(label);
    if (l.find("color") != std::string::npos || l.find("temp") != std::string::npos ||
        l.find(" kelvin") != std::string::npos || l == "k")
        return "Color Temp";
    if (l.find("direct") != std::string::npos || l.find("sunny") != std::string::npos ||
        l.find("sunlight") != std::string::npos || l.find("daylight") != std::string::npos)
        return "Daylight";
    if (l.find("shade") != std::string::npos)
        return "Shade";
    if (l.find("cloud") != std::string::npos)
        return "Cloudy";
    if (l.find("incandescent") != std::string::npos || l.find("tungsten") != std::string::npos)
        return "Tungsten";
    if (l.find("fluorescent") != std::string::npos)
        return "Fluorescent";
    if (l.find("flash") != std::string::npos)
        return "Flash";
    if (l.find("preset") != std::string::npos || l.find("custom") != std::string::npos ||
        l.find("manual") != std::string::npos)
        return "Custom";
    if (l.find("natural") != std::string::npos)
        return "Natural Light Auto";
    if (l.find("auto") != std::string::npos || l.find("awb") != std::string::npos)
        return "Auto";
    return label;
}

static int canonWbCodeFromLabel(const std::string& label)
{
    std::string c = canonWbLabelFromNikon(label);
    if (c == "Auto") return 0;
    if (c == "Daylight") return 1;
    if (c == "Shade") return 2;
    if (c == "Cloudy") return 3;
    if (c == "Tungsten") return 4;
    if (c == "Fluorescent") return 5;
    if (c == "Flash") return 6;
    if (c == "Custom") return 8;
    if (c == "Color Temp") return 9;
    if (c == "Natural Light Auto") return 10;
    return -1;
}

uint32_t NikonCameraState::getProperty(uint32_t canonPropId) const
{
    switch (canonPropId) {
    case CANON_PROP_ISO:       return static_cast<uint32_t>(m_iso);
    case CANON_PROP_AV:        return static_cast<uint32_t>(m_av);
    case CANON_PROP_TV:        return static_cast<uint32_t>(m_tv);
    case CANON_PROP_WB:        return static_cast<uint32_t>(m_wb);
    case CANON_PROP_EV:        return static_cast<uint32_t>(m_ev);
    case CANON_PROP_COLORTEMP: return static_cast<uint32_t>(m_colorTemp);
    default:                   return 0;
    }
}

// ===========================================================================
// Impl
// ===========================================================================
class NikonCameraController::Impl {
public:
    // Exported SDK function pointers
    HINSTANCE                   hModule = nullptr;
    LPMAIDSetLoggingLevel       pSetLoggingLevel = nullptr;
    LPMAIDInitializeSDKProc     pInitializeSDK = nullptr;
    LPMAIDFreeSDKProc           pFreeSDK = nullptr;
    LPMAIDConnectDeviceProc     pConnectDevice = nullptr;
    LPMAIDDisconnectDeviceProc  pDisconnectDevice = nullptr;
    LPMAIDSetImageVideoSavePath pSetImageVideoSavePath = nullptr;
    LPMAIDGetCapability         pGetCapability = nullptr;
    LPMAIDSetCapability         pSetCapability = nullptr;
    LPMAIDStartShooting         pStartShooting = nullptr;
    LPMAIDStartLiveView         pStartLiveView = nullptr;
    LPMAIDStopLiveView          pStopLiveView = nullptr;
    LPMAIDGetLiveViewStatus     pGetLiveViewStatus = nullptr;

    LPNkMAIDEnumDevices pDeviceList = nullptr;
    LPNkMAIDEnumCapInfo pEnumCapInfo = nullptr;
    NkMAIDCSCallback    callback{};   // kept alive for the SDK's lifetime

    std::recursive_mutex mtx;
    bool initialized  = false;
    bool connected    = false;
    bool liveStreaming = false;
    // Shooting-mode + save setup only needs to run once per connection; caching
    // it keeps the per-capture dead window (live view paused) as short as
    // possible. Reset on connect/disconnect.
    bool shootSetupDone = false;

    // Last capture timing breakdown (ms) for diagnostics — how long the shutter
    // (StartShooting: AF+exposure) blocked vs the file transfer wait.
    long lastShootMs = 0;
    long lastTransferMs = 0;

    std::string saveFolder;
    std::string lastPhotoPath;
    std::string cameraModel;
    std::string lastError;
    NikonCameraState state;

    std::vector<unsigned long> availableIds;    // findCameras() order → device ID
    std::vector<std::string>   availableNames;

    std::vector<ICameraEventListener*> listeners;
    std::function<void(const uint8_t*, size_t)> liveCb;
    std::function<void(const std::string&)>     logCb;

    struct EnumSnapshot {
        ULONG cap = 0;
        ULONG type = 0;
        ULONG currentIndex = 0;
        std::vector<ULONG> codes;
        std::vector<std::string> labels;
    };

    void log(const std::string& s) { if (logCb) logCb("[Nikon] " + s); }

    void fireEvent(CameraEventType t, const std::string& msg = "",
                   const std::string& file = "")
    {
        CameraEvent e;
        e.type = t;
        e.message = msg;
        e.fileName = file;
        for (auto* l : listeners) if (l) l->onCameraEvent(e);
    }

    bool loadDll();
    void freeCapValue(void* data, eNkMAIDDataType type);
    bool readEnumSnapshot(ULONG cap, EnumSnapshot& snap);
    bool setEnumIndex(ULONG cap, ULONG index);
    bool setEnumByLabel(ULONG cap, const std::string& value);
    // Pick the first enum option whose label CONTAINS one of the preference
    // substrings (tried in priority order). Robust to model-specific label
    // wording (e.g. "Medium", "M", "JPEG normal"). Returns true if one was set.
    bool setEnumBySubstring(ULONG cap, const std::vector<std::string>& prefs);
    bool setEnumByNumber(ULONG cap, int value, bool nearest);
    bool setEnumByWbCode(ULONG cap, int canonCode);
    bool setRangeValue(ULONG cap, int value);
    bool getPropertyStringsForCap(ULONG cap, uint32_t canonPropId,
                                  std::vector<std::string>& outList,
                                  std::string& outCurrent);
    void ensureSingleShootingMode();
    void applySaveSetup();
    // Run shooting-mode + save setup once per connection (cached via shootSetupDone).
    void ensureShootSetupOnce();
    // Is the camera's live view actually streaming right now? Queries the camera
    // (GetLiveViewStatus) rather than trusting our cached flag, so we can detect
    // when StartShooting turned live view off underneath us.
    bool cameraLiveViewIsOn();
    // Restart the CSL live-view stream if the camera turned it off after a
    // capture. No-op if it is already streaming. Returns true if streaming.
    bool resumeLiveViewIfNeeded();
    std::set<std::string> snapshotFolder() const;
    std::string waitForNewFile(const std::set<std::string>& before, int timeoutMs) const;
};

// Single live instance so the C-style SDK callbacks can reach it.
static NikonCameraController::Impl* g_nk = nullptr;

// ===========================================================================
// SDK callbacks (C linkage / CALLPASCAL)
// ===========================================================================
static void*  CALLPASCAL CALLBACK NkAllocate(size_t len) { return malloc(len); }
static void   CALLPASCAL CALLBACK NkFree(void* p)        { free(p); }
static void   CALLPASCAL CALLBACK NkSrcEvent(NKREF, ULONG, NKPARAM) {}
static ULONG  CALLPASCAL CALLBACK NkUIRequest(NKREF, LPNkMAIDUIRequestInfo) { return 0; }
static void   CALLPASCAL CALLBACK NkProgress(ULONG, ULONG, NKREF, ULONG, ULONG) {}
static NKERROR CALLPASCAL CALLBACK NkDataProc(NKREF, LPVOID, LPVOID) { return kNkMAIDResult_NoError; }
static void   CALLPASCAL CALLBACK NkLVData(NKREF, LPNkMAIDLiveViewData d)
{
    if (!d) return;

    // liveCb copies the JPEG synchronously (memcpy) before returning, so the
    // buffer is safe to free immediately afterwards.
    if (g_nk && g_nk->liveCb && d->pImageData && d->ulLvImageSize > 0)
        g_nk->liveCb(reinterpret_cast<const uint8_t*>(d->pImageData),
                     static_cast<size_t>(d->ulLvImageSize));

    // CRITICAL: the CSL allocates a fresh struct + image buffer per frame (via
    // our NkAllocate=malloc) and hands ownership to this callback. We MUST free
    // them, exactly like SampleApp's LVDataProc. Omitting this leaks one
    // live-view buffer every frame, which steadily starves the frame rate
    // (observed 10 → 3 FPS over ~40 s) and bloats memory during a session.
    if (d->pImageData) free(d->pImageData);
    free(d);
}

// ===========================================================================
// Impl helpers
// ===========================================================================
bool NikonCameraController::Impl::loadDll()
{
    if (hModule) return true;
    hModule = LoadLibraryA("ControlServiceLayer.dll");
    if (!hModule) {
        lastError = "Cannot load ControlServiceLayer.dll";
        return false;
    }
    pSetLoggingLevel       = (LPMAIDSetLoggingLevel)      GetProcAddress(hModule, "SetLoggingLevel");
    pInitializeSDK         = (LPMAIDInitializeSDKProc)    GetProcAddress(hModule, "InitializeSDK");
    pFreeSDK               = (LPMAIDFreeSDKProc)          GetProcAddress(hModule, "FreeSDK");
    pConnectDevice         = (LPMAIDConnectDeviceProc)    GetProcAddress(hModule, "ConnectDevice");
    pDisconnectDevice      = (LPMAIDDisconnectDeviceProc) GetProcAddress(hModule, "DisconnectDevice");
    pSetImageVideoSavePath = (LPMAIDSetImageVideoSavePath)GetProcAddress(hModule, "SetImageVideoSavePath");
    pGetCapability         = (LPMAIDGetCapability)        GetProcAddress(hModule, "GetCapability");
    pSetCapability         = (LPMAIDSetCapability)        GetProcAddress(hModule, "SetCapability");
    pStartShooting         = (LPMAIDStartShooting)        GetProcAddress(hModule, "StartShooting");
    pStartLiveView         = (LPMAIDStartLiveView)        GetProcAddress(hModule, "StartLiveView");
    pStopLiveView          = (LPMAIDStopLiveView)         GetProcAddress(hModule, "StopLiveView");
    pGetLiveViewStatus     = (LPMAIDGetLiveViewStatus)    GetProcAddress(hModule, "GetLiveViewStatus");

    if (!pInitializeSDK || !pFreeSDK || !pConnectDevice || !pDisconnectDevice ||
        !pSetImageVideoSavePath || !pGetCapability || !pSetCapability || !pStartShooting) {
        lastError = "Cannot resolve required SDK exports";
        return false;
    }
    return true;
}

void NikonCameraController::Impl::freeCapValue(void* data, eNkMAIDDataType type)
{
    if (!data) return;
    if (type == kNkMAIDDataType_EnumPtr)       free(((LPNkMAIDEnum)data)->pData);
    else if (type == kNkMAIDDataType_ArrayPtr) free(((LPNkMAIDArray)data)->pData);
    free(data);
}

bool NikonCameraController::Impl::readEnumSnapshot(ULONG cap, EnumSnapshot& snap)
{
    snap = {};
    snap.cap = cap;
    if (!connected || !pGetCapability) return false;

    LPVOID pArr = nullptr;
    eNkMAIDDataType at = kNkMAIDDataType_Null;
    NKERROR ea = pGetCapability(cap, kNkSDKGetSettingSupportedValueArray, pArr, at);
    if (ea != kNkMAIDResult_NoError || !pArr || at != kNkMAIDDataType_EnumPtr) {
        freeCapValue(pArr, at);
        lastError = "Nikon capability array unavailable (" + std::to_string((int)cap) +
                    ", err=" + std::to_string((int)ea) + ")";
        return false;
    }

    LPNkMAIDEnum arr = (LPNkMAIDEnum)pArr;
    snap.type = arr->ulType;
    snap.currentIndex = arr->ulValue;

    if (arr->ulType == kNkMAIDArrayType_PackedString) {
        const char* base = static_cast<const char*>(arr->pData);
        ULONG offset = 0;
        while (base && offset < arr->ulElements) {
            const char* s = base + offset;
            size_t len = strnlen(s, arr->ulElements - offset);
            if (len == 0) break;
            snap.labels.emplace_back(s, len);
            offset += static_cast<ULONG>(len + 1);
        }
    } else if (arr->ulType == kNkMAIDArrayType_Unsigned && arr->pData) {
        ULONG* vals = static_cast<ULONG*>(arr->pData);
        for (ULONG i = 0; i < arr->ulElements; ++i) {
            snap.codes.push_back(vals[i]);
            snap.labels.push_back(std::to_string(vals[i]));
        }
    } else if (arr->ulType == kNkMAIDArrayType_Integer && arr->pData) {
        SLONG* vals = static_cast<SLONG*>(arr->pData);
        for (ULONG i = 0; i < arr->ulElements; ++i)
            snap.labels.push_back(std::to_string(vals[i]));
    } else {
        freeCapValue(pArr, at);
        lastError = "Unsupported Nikon enum array type: " + std::to_string(arr->ulType);
        return false;
    }

    LPVOID pCur = nullptr;
    eNkMAIDDataType ct = kNkMAIDDataType_Null;
    NKERROR ec = pGetCapability(cap, kNkSDKGetSettingValue, pCur, ct);
    if (ec == kNkMAIDResult_NoError && pCur && ct == kNkMAIDDataType_EnumPtr)
        snap.currentIndex = ((LPNkMAIDEnum)pCur)->ulValue;

    freeCapValue(pCur, ct);
    freeCapValue(pArr, at);
    return !snap.labels.empty();
}

bool NikonCameraController::Impl::setEnumIndex(ULONG cap, ULONG index)
{
    EnumSnapshot snap;
    if (!readEnumSnapshot(cap, snap)) return false;
    if (index >= snap.labels.size()) {
        lastError = "Nikon enum index out of range";
        return false;
    }

    NkMAIDEnum set{};
    set.ulType = snap.type;
    set.ulElements = static_cast<ULONG>(snap.labels.size());
    set.ulValue = index;
    set.ulDefault = 0;
    set.wPhysicalBytes = sizeof(ULONG);
    set.pData = nullptr;

    NKERROR se = pSetCapability(cap, &set, kNkMAIDDataType_EnumPtr);
    if (se != kNkMAIDResult_NoError) {
        lastError = "SetCapability failed (" + std::to_string((int)cap) +
                    ", err=" + std::to_string((int)se) + ")";
        return false;
    }
    return true;
}

bool NikonCameraController::Impl::setEnumByLabel(ULONG cap, const std::string& value)
{
    EnumSnapshot snap;
    if (!readEnumSnapshot(cap, snap)) return false;

    std::string wanted = lowerAscii(value);
    for (ULONG i = 0; i < snap.labels.size(); ++i)
        if (lowerAscii(snap.labels[i]) == wanted)
            return setEnumIndex(cap, i);

    std::string compactWanted = wanted;
    compactWanted.erase(std::remove_if(compactWanted.begin(), compactWanted.end(),
        [](unsigned char c) { return std::isspace(c) || c == '"' || c == '\''; }),
        compactWanted.end());

    for (ULONG i = 0; i < snap.labels.size(); ++i) {
        std::string cur = lowerAscii(snap.labels[i]);
        cur.erase(std::remove_if(cur.begin(), cur.end(),
            [](unsigned char c) { return std::isspace(c) || c == '"' || c == '\''; }),
            cur.end());
        if (cur == compactWanted)
            return setEnumIndex(cap, i);
    }

    lastError = "Nikon enum label not supported: " + value;
    return false;
}

bool NikonCameraController::Impl::setEnumBySubstring(ULONG cap,
                                                     const std::vector<std::string>& prefs)
{
    EnumSnapshot snap;
    if (!readEnumSnapshot(cap, snap)) return false;
    for (const auto& pref : prefs) {
        std::string want = lowerAscii(pref);
        for (ULONG i = 0; i < snap.labels.size(); ++i) {
            if (lowerAscii(snap.labels[i]).find(want) != std::string::npos) {
                if (i == snap.currentIndex) return true;   // already selected
                return setEnumIndex(cap, i);
            }
        }
    }
    return false;
}

bool NikonCameraController::Impl::setEnumByNumber(ULONG cap, int value, bool nearest)
{
    EnumSnapshot snap;
    if (!readEnumSnapshot(cap, snap)) return false;

    ULONG bestIndex = (std::numeric_limits<ULONG>::max)();
    int bestDelta = (std::numeric_limits<int>::max)();
    for (ULONG i = 0; i < snap.labels.size(); ++i) {
        int v = -1;
        if (i < snap.codes.size()) v = static_cast<int>(snap.codes[i]);
        if (v < 0) v = firstIntegerIn(snap.labels[i]);
        if (v < 0) continue;

        int delta = std::abs(v - value);
        if (delta == 0) return setEnumIndex(cap, i);
        if (nearest && delta < bestDelta) {
            bestDelta = delta;
            bestIndex = i;
        }
    }

    if (nearest && bestIndex != (std::numeric_limits<ULONG>::max)())
        return setEnumIndex(cap, bestIndex);

    lastError = "Nikon numeric enum value not supported: " + std::to_string(value);
    return false;
}

bool NikonCameraController::Impl::setEnumByWbCode(ULONG cap, int canonCode)
{
    EnumSnapshot snap;
    if (!readEnumSnapshot(cap, snap)) return false;

    for (ULONG i = 0; i < snap.labels.size(); ++i)
        if (canonWbCodeFromLabel(snap.labels[i]) == canonCode)
            return setEnumIndex(cap, i);

    lastError = "Nikon WB mode not supported for Canon code: " + std::to_string(canonCode);
    return false;
}

bool NikonCameraController::Impl::setRangeValue(ULONG cap, int value)
{
    if (!connected || !pGetCapability || !pSetCapability) return false;

    LPVOID pCap = nullptr;
    eNkMAIDDataType dt = kNkMAIDDataType_Null;
    NKERROR e = pGetCapability(cap, kNkSDKGetSettingSupportedValueArray, pCap, dt);
    if (e != kNkMAIDResult_NoError || !pCap) {
        freeCapValue(pCap, dt);
        lastError = "Nikon capability range unavailable (" + std::to_string((int)cap) +
                    ", err=" + std::to_string((int)e) + ")";
        return false;
    }

    if (dt != kNkMAIDDataType_RangePtr) {
        freeCapValue(pCap, dt);
        lastError = "Nikon capability is not a range type";
        return false;
    }

    NkMAIDRange range = *((LPNkMAIDRange)pCap);
    double lower = range.lfLower;
    double upper = range.lfUpper;
    if (upper < lower)
        std::swap(lower, upper);

    double requested = static_cast<double>(value);
    double clamped = (std::max)(lower, (std::min)(upper, requested));

    if (range.ulSteps > 1 && upper > lower) {
        double rawIndex = (clamped - lower) * (range.ulSteps - 1) / (upper - lower);
        ULONG index = static_cast<ULONG>(std::round(rawIndex));
        if (index >= range.ulSteps)
            index = range.ulSteps - 1;
        range.ulValueIndex = index;
        range.lfValue = lower + index * (upper - lower) / (range.ulSteps - 1);
    } else {
        range.lfValue = clamped;
    }

    NKERROR se = pSetCapability(cap, &range, kNkMAIDDataType_RangePtr);
    freeCapValue(pCap, dt);
    if (se != kNkMAIDResult_NoError) {
        lastError = "SetCapability failed for range (" + std::to_string((int)cap) +
                    ", err=" + std::to_string((int)se) + ")";
        return false;
    }
    return true;
}

bool NikonCameraController::Impl::getPropertyStringsForCap(
    ULONG cap,
    uint32_t canonPropId,
    std::vector<std::string>& outList,
    std::string& outCurrent)
{
    EnumSnapshot snap;
    if (!readEnumSnapshot(cap, snap)) return false;

    outList.clear();
    auto currentAt = [&]() -> std::string {
        if (snap.currentIndex < snap.labels.size()) return snap.labels[snap.currentIndex];
        return snap.labels.empty() ? std::string() : snap.labels.front();
    };

    if (canonPropId == CANON_PROP_WB) {
        std::vector<std::string> unique;
        for (const auto& raw : snap.labels) {
            std::string label = canonWbLabelFromNikon(raw);
            if (canonWbCodeFromLabel(label) < 0) continue;
            if (std::find(unique.begin(), unique.end(), label) == unique.end())
                unique.push_back(label);
        }
        outList = std::move(unique);
        outCurrent = canonWbLabelFromNikon(currentAt());
        state.setWb(canonWbCodeFromLabel(outCurrent));
        return !outList.empty();
    }

    outList = snap.labels;
    outCurrent = currentAt();

    if (canonPropId == CANON_PROP_ISO) {
        state.setIso(firstIntegerIn(outCurrent));
    } else if (canonPropId == CANON_PROP_AV) {
        state.setAv(static_cast<int>(snap.currentIndex));
    } else if (canonPropId == CANON_PROP_TV) {
        state.setTv(static_cast<int>(snap.currentIndex));
    } else if (canonPropId == CANON_PROP_EV) {
        state.setEv(static_cast<int>(snap.currentIndex));
    } else if (canonPropId == CANON_PROP_COLORTEMP) {
        int k = firstIntegerIn(outCurrent);
        if (k > 0) state.setColorTemp(k);
    }

    return !outList.empty();
}

// Set drive/release mode to Single (S) so StartShooting(Single) is valid.
// Validated in SimpleTest.cpp: the value array is only populated when
// requesting GetSettingSupportedValueArray (plain GetSettingValue → pData NULL).
void NikonCameraController::Impl::ensureSingleShootingMode()
{
    LPVOID pArr = nullptr;
    eNkMAIDDataType at = kNkMAIDDataType_Null;
    NKERROR ea = pGetCapability(kNkMAIDCapability_ShootingMode,
                                kNkSDKGetSettingSupportedValueArray, pArr, at);
    if (ea != kNkMAIDResult_NoError || !pArr || at != kNkMAIDDataType_EnumPtr) {
        freeCapValue(pArr, at);
        return;
    }
    LPNkMAIDEnum arr = (LPNkMAIDEnum)pArr;
    ULONG* codes = (ULONG*)arr->pData;
    ULONG  n = arr->ulElements;

    ULONG singleIdx = 0xFFFFFFFF;
    for (ULONG i = 0; codes && i < n; ++i)
        if (codes[i] == (ULONG)eNkMAIDShootingMode_S) { singleIdx = i; break; }

    // Current index
    LPVOID pCur = nullptr; eNkMAIDDataType ct = kNkMAIDDataType_Null;
    ULONG curCode = 0xFFFFFFFF;
    if (pGetCapability(kNkMAIDCapability_ShootingMode, kNkSDKGetSettingValue, pCur, ct)
            == kNkMAIDResult_NoError && pCur && ct == kNkMAIDDataType_EnumPtr) {
        ULONG idx = ((LPNkMAIDEnum)pCur)->ulValue;
        if (codes && idx < n) curCode = codes[idx];
    }

    if (curCode != (ULONG)eNkMAIDShootingMode_S && singleIdx != 0xFFFFFFFF) {
        NkMAIDEnum set = *arr;
        set.ulValue = singleIdx;
        set.pData = nullptr;
        NKERROR se = pSetCapability(kNkMAIDCapability_ShootingMode, &set, kNkMAIDDataType_EnumPtr);
        log(std::string("Set ShootingMode=Single: ") +
            (se == kNkMAIDResult_NoError ? "OK" : "failed"));
    }
    freeCapValue(pCur, ct);
    freeCapValue(pArr, at);
}

// Save to PC folder: SaveMedia = Card+SDRAM (transfer to host) + save path.
void NikonCameraController::Impl::applySaveSetup()
{
    if (saveFolder.empty()) return;
    std::error_code ec;
    fs::create_directories(fs::u8path(saveFolder), ec);
    if (pSetImageVideoSavePath)
        pSetImageVideoSavePath(toWide(saveFolder).c_str(), L"");
    ULONG media = (ULONG)kNkMAIDSaveMedia_Card_SDRAM;
    pSetCapability(kNkMAIDCapability_SaveMedia, &media, kNkMAIDDataType_UnsignedPtr);
}

// Per-session setup (drive mode + save media/path). The SDK round-trips here add
// ~100-300 ms; running them on EVERY shot would lengthen the live-view dead
// window. Cache after the first successful run; the save path rarely changes and
// setSaveFolder() resets the flag when it does.
void NikonCameraController::Impl::ensureShootSetupOnce()
{
    if (shootSetupDone) return;
    applySaveSetup();
    ensureSingleShootingMode();

    // Shrink the captured JPEG so the per-shot USB transfer (which freezes live
    // view) is far shorter. Medium on a Z6 II is ~13 MP — still well beyond any
    // photobooth print/strip need — at roughly half the bytes of Large Fine.
    // Best-effort: if the camera doesn't expose these caps we just keep current.
    if (setEnumBySubstring(kNkMAIDCapability_ImageSize, {"medium", "small"}))
        log("ImageSize -> Medium (faster transfer, less live-view freeze)");
    if (setEnumBySubstring(kNkMAIDCapability_CompressionLevel, {"normal", "basic"}))
        log("CompressionLevel -> Normal (faster transfer)");

    shootSetupDone = true;
}

bool NikonCameraController::Impl::cameraLiveViewIsOn()
{
    if (!pGetLiveViewStatus) {
        // No status API available — fall back to our own bookkeeping.
        return liveStreaming;
    }
    eNkMAIDLVStatus st = eNkMAIDLVStatus_OFF;
    NKERROR e = pGetLiveViewStatus(st);
    if (e != kNkMAIDResult_NoError) return liveStreaming;
    return st != eNkMAIDLVStatus_OFF;
}

bool NikonCameraController::Impl::resumeLiveViewIfNeeded()
{
    if (!pStartLiveView) return false;

    // If the camera is still streaming (CSL kept/auto-resumed live view), do
    // nothing — issuing StartLiveView again would add needless latency.
    if (cameraLiveViewIsOn()) {
        liveStreaming = true;
        return true;
    }

    NKERROR e = pStartLiveView(nullptr, nullptr);
    if (e == kNkMAIDResult_NoError) {
        liveStreaming = true;   // frames resume; no event (controller stays "active")
        return true;
    }
    log("Live view resume failed (" + std::to_string((int)e) + ")");
    return false;
}

static bool isImageFile(const fs::path& p)
{
    std::string e = p.extension().string();
    std::transform(e.begin(), e.end(), e.begin(), ::tolower);
    return e == ".jpg" || e == ".jpeg" || e == ".nef" || e == ".png";
}

std::set<std::string> NikonCameraController::Impl::snapshotFolder() const
{
    std::set<std::string> files;
    if (saveFolder.empty()) return files;
    std::error_code ec;
    for (auto& it : fs::directory_iterator(fs::u8path(saveFolder), ec)) {
        if (it.is_regular_file(ec) && isImageFile(it.path()))
            files.insert(it.path().string());
    }
    return files;
}

std::string NikonCameraController::Impl::waitForNewFile(const std::set<std::string>& before,
                                                        int timeoutMs) const
{
    using clock = std::chrono::steady_clock;
    auto deadline = clock::now() + std::chrono::milliseconds(timeoutMs);
    while (clock::now() < deadline) {
        std::error_code ec;
        std::string newest;
        fs::file_time_type newestT{};
        for (auto& it : fs::directory_iterator(fs::u8path(saveFolder), ec)) {
            if (!it.is_regular_file(ec) || !isImageFile(it.path())) continue;
            std::string p = it.path().string();
            if (before.count(p)) continue;
            auto t = it.last_write_time(ec);
            if (newest.empty() || t > newestT) { newest = p; newestT = t; }
        }
        if (!newest.empty()) return newest;
        Sleep(150);
    }
    return std::string();
}

// ===========================================================================
// NikonCameraController
// ===========================================================================
NikonCameraController& NikonCameraController::instance()
{
    static NikonCameraController s;
    return s;
}

NikonCameraController::NikonCameraController() : m_impl(std::make_unique<Impl>()) {}
NikonCameraController::~NikonCameraController() { shutdown(); }

bool NikonCameraController::initialize()
{
    std::lock_guard<std::recursive_mutex> lock(m_impl->mtx);
    if (m_impl->initialized) return true;
    if (!m_impl->loadDll()) { m_lastError = m_impl->lastError; return false; }

    g_nk = m_impl.get();

    if (m_impl->pSetLoggingLevel)
        m_impl->pSetLoggingLevel(kkNkSDKLogLevel_Error);

    NkMAIDCSCallback& cb = m_impl->callback;
    memset(&cb, 0, sizeof(cb));
    cb.pUIReqProc        = (LPNKFUNC)NkUIRequest;
    cb.pfnEventProc      = (LPNKFUNC)NkSrcEvent;
    cb.pProgressProc     = (LPNKFUNC)NkProgress;
    cb.pDataProc         = (LPNKFUNC)NkDataProc;
    cb.pLiveViewDataProc = (LPNKFUNC)NkLVData;
    cb.refProc           = nullptr;

    NKERROR e = m_impl->pInitializeSDK((LPMAIDAllocateMemory)NkAllocate,
                                       (LPMAIDFreeMemory)NkFree,
                                       &cb, &m_impl->pDeviceList, nullptr);
    if (e != kNkMAIDResult_NoError) {
        m_impl->lastError = "InitializeSDK failed (" + std::to_string((int)e) + ")";
        m_lastError = m_impl->lastError;
        return false;
    }
    m_impl->initialized = true;
    m_impl->log("SDK initialized");
    return true;
}

void NikonCameraController::shutdown()
{
    if (!m_impl) return;
    std::lock_guard<std::recursive_mutex> lock(m_impl->mtx);
    if (m_impl->liveStreaming && m_impl->pStopLiveView) {
        m_impl->pStopLiveView(nullptr, nullptr);
        m_impl->liveStreaming = false;
    }
    if (m_impl->connected && m_impl->pDisconnectDevice) {
        m_impl->pDisconnectDevice();
        m_impl->connected = false;
    }
    if (m_impl->initialized && m_impl->pFreeSDK) {
        m_impl->pFreeSDK();
        m_impl->initialized = false;
    }
    if (m_impl->hModule) {
        FreeLibrary(m_impl->hModule);
        m_impl->hModule = nullptr;
    }
    if (g_nk == m_impl.get()) g_nk = nullptr;
}

bool NikonCameraController::findCameras(std::vector<NikonCameraInfo>& out)
{
    std::lock_guard<std::recursive_mutex> lock(m_impl->mtx);
    out.clear();
    m_impl->availableIds.clear();
    m_impl->availableNames.clear();
    if (!m_impl->initialized) return false;

    // The SDK populates the device list asynchronously after InitializeSDK.
    for (int i = 0; i < 15; ++i) {
        bool any = false;
        auto* dl = m_impl->pDeviceList;
        if (dl && dl->ulElements > 0 && dl->pDeviceData) {
            for (ULONG k = 0; k < dl->ulElements; ++k)
                if (dl->pDeviceData[k].Availability) { any = true; break; }
        }
        if (any) break;
        Sleep(200);
    }

    auto* dl = m_impl->pDeviceList;
    if (!dl || !dl->pDeviceData) return false;
    for (ULONG k = 0; k < dl->ulElements; ++k) {
        auto& d = dl->pDeviceData[k];
        if (!d.Availability) continue;
        out.push_back({ d.Name, "", (int)m_impl->availableIds.size() });
        m_impl->availableIds.push_back(d.ID);
        m_impl->availableNames.push_back(d.Name);
    }
    return !out.empty();
}

int NikonCameraController::getCameraCount()
{
    std::vector<NikonCameraInfo> tmp;
    findCameras(tmp);
    return (int)tmp.size();
}

bool NikonCameraController::connectCamera(int index)
{
    std::lock_guard<std::recursive_mutex> lock(m_impl->mtx);
    if (!m_impl->initialized) return false;
    if (index < 0 || index >= (int)m_impl->availableIds.size()) {
        m_impl->lastError = "connectCamera index out of range";
        return false;
    }
    NKERROR e = m_impl->pConnectDevice(m_impl->availableIds[index], &m_impl->pEnumCapInfo);
    if (e != kNkMAIDResult_NoError) {
        m_impl->lastError = "ConnectDevice failed (" + std::to_string((int)e) + ")";
        return false;
    }
    m_impl->connected = true;
    m_impl->shootSetupDone = false;   // re-run shooting-mode setup for this session
    m_impl->cameraModel = m_impl->availableNames[index];
    if (!m_impl->saveFolder.empty()) m_impl->applySaveSetup();
    m_impl->fireEvent(CameraEventType::Connected, m_impl->cameraModel);
    m_impl->log("Connected: " + m_impl->cameraModel);
    return true;
}

bool NikonCameraController::disconnectCamera()
{
    std::lock_guard<std::recursive_mutex> lock(m_impl->mtx);
    if (m_impl->liveStreaming) stopLiveViewStreaming();
    if (m_impl->connected && m_impl->pDisconnectDevice) {
        m_impl->pDisconnectDevice();
        m_impl->connected = false;
        m_impl->fireEvent(CameraEventType::Disconnected);
    }
    return true;
}

bool NikonCameraController::isConnected() const { return m_impl->connected; }

static bool doCapture(NikonCameraController::Impl* impl, bool autoFocus)
{
    if (!impl->connected) { impl->lastError = "Not connected"; return false; }

    std::set<std::string> before;
    MAIDShootingStructure shoot;
    NKERROR e = kNkMAIDResult_NoError;
    bool wasStreaming = false;

    {
        // Hold the SDK lock only for the capture itself, NOT the file wait.
        std::lock_guard<std::recursive_mutex> lock(impl->mtx);

        // Remember intent: should live view be running after this shot? The
        // camera physically prohibits live view during the exposure
        // (kNkMAIDLiveViewProhibit_Capture), so a brief dead window is
        // unavoidable on Nikon. We minimise it and resume ASAP.
        wasStreaming = impl->liveStreaming;

        // Cached per-session setup — avoids 2-3 SDK round-trips on every shot,
        // keeping the dead window short. We do NOT stop live view before
        // shooting: StartShooting handles the camera state internally and this
        // matches the validated capture path (no pre-stop).
        impl->ensureShootSetupOnce();

        before = impl->snapshotFolder();

        memset(&shoot, 0, sizeof(shoot));
        shoot.ShootingType = kNkSDKShootingTypeSingle;
        shoot.bAutoFocus = autoFocus;
        std::wstring w = toWide(impl->saveFolder);
        wcsncpy(shoot.ImageSavePath, w.c_str(), 1023);

        impl->fireEvent(CameraEventType::CaptureStarted);
        auto _tShoot0 = std::chrono::steady_clock::now();
        e = impl->pStartShooting(shoot, nullptr, nullptr);
        impl->lastShootMs = (long)std::chrono::duration_cast<std::chrono::milliseconds>(
                                std::chrono::steady_clock::now() - _tShoot0).count();

        // Resume live view the instant the (synchronous) shutter returns, so the
        // preview unfreezes without waiting for the ~1.5 s file download. Only
        // restarts the stream if the camera actually turned it off — if the CSL
        // kept it on, this is a cheap status check with no added latency.
        if (wasStreaming)
            impl->resumeLiveViewIfNeeded();
    }
    // *** Lock released — live view callback resumes feeding frames ***

    if (e != kNkMAIDResult_NoError && e != kNkMAIDResult_Waiting_2ndRelease) {
        impl->lastError = "StartShooting failed (" + std::to_string((int)e) + ")";
        impl->fireEvent(CameraEventType::CaptureError, impl->lastError);
        return false;
    }

    // Wait for the file WITHOUT holding the mutex — live view keeps streaming.
    auto _tWait0 = std::chrono::steady_clock::now();
    std::string file = impl->waitForNewFile(before, 8000);
    impl->lastTransferMs = (long)std::chrono::duration_cast<std::chrono::milliseconds>(
                               std::chrono::steady_clock::now() - _tWait0).count();
    impl->lastPhotoPath = file;

    // Safety net: if the immediate resume didn't take (camera was still busy
    // right after the shutter), retry now that the image is written and the
    // camera is idle. Uses wasStreaming (intent), so one transient failure can't
    // leave the preview frozen for the rest of the session.
    if (wasStreaming) {
        std::lock_guard<std::recursive_mutex> lock(impl->mtx);
        for (int attempt = 0; attempt < 3 && !impl->cameraLiveViewIsOn(); ++attempt) {
            if (impl->resumeLiveViewIfNeeded()) break;
            Sleep(120);
        }
    }

    // Breakdown goes in the event message so the Qt layer can log it: tells us
    // how much of the live-view freeze is the shutter/AF vs the file transfer.
    std::string timing = "shoot=" + std::to_string(impl->lastShootMs) +
                         "ms transfer=" + std::to_string(impl->lastTransferMs) + "ms";
    impl->fireEvent(CameraEventType::CaptureCompleted, timing, file);
    impl->log(file.empty() ? "Capture done (no file detected in folder)"
                           : "Capture done: " + file + " (" + timing + ")");
    return true;
}

bool NikonCameraController::takePhoto()
{
    // doCapture manages its own locking — don't block live view callback here
    return doCapture(m_impl.get(), /*autoFocus*/ true);
}

bool NikonCameraController::takePhotoNoAF()
{
    // doCapture manages its own locking — don't block live view callback here
    return doCapture(m_impl.get(), /*autoFocus*/ false);
}

std::string NikonCameraController::getLastPhotoPath() const { return m_impl->lastPhotoPath; }

// ---- Live view ----
bool NikonCameraController::startLiveViewStreaming()
{
    std::lock_guard<std::recursive_mutex> lock(m_impl->mtx);
    if (!m_impl->connected || !m_impl->pStartLiveView) return false;
    if (m_impl->liveStreaming) return true;
    NKERROR e = m_impl->pStartLiveView(nullptr, nullptr);
    if (e != kNkMAIDResult_NoError) {
        m_impl->lastError = "StartLiveView failed (" + std::to_string((int)e) + ")";
        return false;
    }
    m_impl->liveStreaming = true;
    m_impl->fireEvent(CameraEventType::LiveViewStarted);
    return true;
}

bool NikonCameraController::stopLiveViewStreaming()
{
    std::lock_guard<std::recursive_mutex> lock(m_impl->mtx);
    if (!m_impl->liveStreaming) return true;
    if (m_impl->pStopLiveView) m_impl->pStopLiveView(nullptr, nullptr);
    m_impl->liveStreaming = false;
    m_impl->fireEvent(CameraEventType::LiveViewStopped);
    return true;
}

bool NikonCameraController::startLiveView()       { return startLiveViewStreaming(); }
bool NikonCameraController::stopLiveView()        { return stopLiveViewStreaming(); }
bool NikonCameraController::isLiveViewActive() const { return m_impl->liveStreaming; }
bool NikonCameraController::getLiveViewFrame(LiveViewFrame&) { return false; }

// ---- Properties ----
bool NikonCameraController::setISO(int iso)
{
    std::lock_guard<std::recursive_mutex> lock(m_impl->mtx);
    if (!m_impl->connected) { m_impl->lastError = "Not connected"; return false; }

    bool ok = m_impl->setEnumByNumber(kNkMAIDCapability_Sensitivity, iso, true);
    if (!ok)
        ok = m_impl->setEnumByNumber(kNkMAIDCapability_ISOControlSensitivity, iso, true);
    if (ok) m_impl->state.setIso(iso);
    return ok;
}

bool NikonCameraController::setShutterSpeed(const std::string& value)
{
    std::lock_guard<std::recursive_mutex> lock(m_impl->mtx);
    if (!m_impl->connected) { m_impl->lastError = "Not connected"; return false; }
    return m_impl->setEnumByLabel(kNkMAIDCapability_ShutterSpeed, value);
}

bool NikonCameraController::setAperture(const std::string& value)
{
    std::lock_guard<std::recursive_mutex> lock(m_impl->mtx);
    if (!m_impl->connected) { m_impl->lastError = "Not connected"; return false; }

    if (m_impl->setEnumByLabel(kNkMAIDCapability_Aperture, value))
        return true;

    std::string norm = value;
    if (norm.rfind("f/", 0) == 0) norm = norm.substr(2);
    else if (!norm.empty() && (norm[0] == 'f' || norm[0] == 'F')) norm = norm.substr(1);
    return m_impl->setEnumByLabel(kNkMAIDCapability_Aperture, norm);
}

bool NikonCameraController::setWhiteBalance(int mode)
{
    std::lock_guard<std::recursive_mutex> lock(m_impl->mtx);
    if (!m_impl->connected) { m_impl->lastError = "Not connected"; return false; }

    bool ok = m_impl->setEnumByWbCode(kNkMAIDCapability_WBMode, mode);
    if (ok) m_impl->state.setWb(mode);
    return ok;
}

bool NikonCameraController::setColorTemperature(int kelvin)
{
    std::lock_guard<std::recursive_mutex> lock(m_impl->mtx);
    if (!m_impl->connected) { m_impl->lastError = "Not connected"; return false; }

    kelvin = (std::max)(2500, (std::min)(10000, kelvin));
    kelvin = ((kelvin + 5) / 10) * 10;

    // Switch WB mode to color temperature where supported, then set the Kelvin value.
    m_impl->setEnumByWbCode(kNkMAIDCapability_WBMode, 9);

    // Try WBTuneColorTempEx as Range first (Z6II uses Range type)
    bool ok = m_impl->setRangeValue(kNkMAIDCapability_WBTuneColorTempEx, kelvin);
    // Fallback to Enum type (older cameras)
    if (!ok)
        ok = m_impl->setEnumByNumber(kNkMAIDCapability_WBTuneColorTempEx, kelvin, true);
    if (!ok)
        ok = m_impl->setEnumByNumber(kNkMAIDCapability_WBTuneColorTemp, kelvin, true);
    if (!ok)
        ok = m_impl->setEnumByNumber(kNkMAIDCapability_LiveViewWBTuneColorTemp, kelvin, true);

    if (ok) m_impl->state.setColorTemp(kelvin);
    return ok;
}

bool NikonCameraController::setMeteringMode(int mode)
{
    std::lock_guard<std::recursive_mutex> lock(m_impl->mtx);
    if (!m_impl->connected) { m_impl->lastError = "Not connected"; return false; }
    return m_impl->setEnumIndex(kNkMAIDCapability_MeteringMode, static_cast<ULONG>((std::max)(0, mode)));
}

bool NikonCameraController::setImageQuality(int) { return true; }
bool NikonCameraController::setDriveMode(int mode)
{
    std::lock_guard<std::recursive_mutex> lock(m_impl->mtx);
    if (!m_impl->connected) { m_impl->lastError = "Not connected"; return false; }
    return m_impl->setEnumIndex(kNkMAIDCapability_ShootingMode, static_cast<ULONG>((std::max)(0, mode)));
}

bool NikonCameraController::setExposureComp(int stopValue)
{
    std::lock_guard<std::recursive_mutex> lock(m_impl->mtx);
    if (!m_impl->connected) { m_impl->lastError = "Not connected"; return false; }

    // The dashboard passes Canon-style signed EV codes. Nikon exposes this as
    // an enum/packed string, so choose the closest numeric label/index available.
    bool ok = m_impl->setEnumByNumber(kNkMAIDCapability_ExposureComp, stopValue, true);
    if (ok) m_impl->state.setEv(stopValue);
    return ok;
}

bool NikonCameraController::getPropertyStrings(uint32_t canonPropId,
                                               std::vector<std::string>& outList,
                                               std::string& outCurrent)
{
    std::lock_guard<std::recursive_mutex> lock(m_impl->mtx);
    outList.clear();
    outCurrent.clear();
    if (!m_impl->connected) { m_impl->lastError = "Not connected"; return false; }

    switch (canonPropId) {
    case CANON_PROP_ISO:
        if (m_impl->getPropertyStringsForCap(kNkMAIDCapability_Sensitivity,
                                             canonPropId, outList, outCurrent))
            return true;
        return m_impl->getPropertyStringsForCap(kNkMAIDCapability_ISOControlSensitivity,
                                                canonPropId, outList, outCurrent);

    case CANON_PROP_TV:
        return m_impl->getPropertyStringsForCap(kNkMAIDCapability_ShutterSpeed,
                                                canonPropId, outList, outCurrent);

    case CANON_PROP_AV:
        return m_impl->getPropertyStringsForCap(kNkMAIDCapability_Aperture,
                                                canonPropId, outList, outCurrent);

    case CANON_PROP_WB:
        return m_impl->getPropertyStringsForCap(kNkMAIDCapability_WBMode,
                                                canonPropId, outList, outCurrent);

    case CANON_PROP_EV:
        return m_impl->getPropertyStringsForCap(kNkMAIDCapability_ExposureComp,
                                                canonPropId, outList, outCurrent);

    case CANON_PROP_COLORTEMP:
        if (m_impl->getPropertyStringsForCap(kNkMAIDCapability_WBTuneColorTempEx,
                                             canonPropId, outList, outCurrent))
            return true;
        if (m_impl->getPropertyStringsForCap(kNkMAIDCapability_WBTuneColorTemp,
                                             canonPropId, outList, outCurrent))
            return true;
        return m_impl->getPropertyStringsForCap(kNkMAIDCapability_LiveViewWBTuneColorTemp,
                                                canonPropId, outList, outCurrent);

    default:
        m_impl->lastError = "Unsupported Nikon property ID: " + std::to_string(canonPropId);
        return false;
    }
}

// ---- Image management ----
void NikonCameraController::setSaveFolder(const std::string& folderPath)
{
    std::lock_guard<std::recursive_mutex> lock(m_impl->mtx);
    m_impl->saveFolder = folderPath;
    if (m_impl->connected) m_impl->applySaveSetup();
}
std::string NikonCameraController::getSaveFolder() const { return m_impl->saveFolder; }

// ---- State & diagnostics ----
const NikonCameraState* NikonCameraController::getState() const { return &m_impl->state; }
std::string NikonCameraController::getCameraModel() const { return m_impl->cameraModel; }
std::string NikonCameraController::getLastError() const { return m_impl->lastError; }

// ---- Events & callbacks ----
void NikonCameraController::addEventListener(ICameraEventListener* l)
{
    std::lock_guard<std::recursive_mutex> lock(m_impl->mtx);
    if (l && std::find(m_impl->listeners.begin(), m_impl->listeners.end(), l) == m_impl->listeners.end())
        m_impl->listeners.push_back(l);
}
void NikonCameraController::removeEventListener(ICameraEventListener* l)
{
    std::lock_guard<std::recursive_mutex> lock(m_impl->mtx);
    m_impl->listeners.erase(std::remove(m_impl->listeners.begin(), m_impl->listeners.end(), l),
                            m_impl->listeners.end());
}
void NikonCameraController::setLogCallback(std::function<void(const std::string&)> cb)
{
    m_impl->logCb = std::move(cb);
}
void NikonCameraController::setLiveViewFrameCallback(std::function<void(const uint8_t*, size_t)> cb)
{
    m_impl->liveCb = std::move(cb);
}

} // namespace NikonApp
