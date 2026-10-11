#pragma once
/*=============================================================================
 * DualSDKController.h — Dual-SDK orchestrator (Canon + Sony)
 *
 * Threading model
 * ───────────────
 *  Phase 1 — initialize()         MAIN THREAD (required by Canon EDSDK on Windows)
 *    Initializes Canon EDSDK, then Sony CRSDK, sequentially.
 *    Returns true if at least one SDK initialised successfully.
 *
 *  Phase 2 — findCameras()        ANY THREAD (typically main)
 *    Launches ONE worker thread per SDK in parallel.
 *    Each thread calls its Service::detectCameras() — the SDK is already
 *    initialised so these calls are thread-safe enumeration only.
 *    Each thread has its own deadline (Canon: kCanonDetectionTimeoutMs,
 *    Sony: kSonyDetectionTimeoutMs) anchored to the same start time so
 *    Canon's wait never reduces the window available to Sony's 3-second
 *    USB scan.  Results are communicated via std::promise so timed-out
 *    threads can be safely detached without data races.
 *    Returns unified list:  Canon cameras first, then Sony cameras.
 *
 *  Phase 3 — connectCamera(index) ANY THREAD
 *    Selects the ICameraSDK adapter matching the detected camera's brand.
 *    Connects to the specific device within that brand.
 *    Replays any buffered listeners / save-folder onto the active adapter.
 *
 *  Runtime (live-view, capture)
 *    Handled by CanonSDKAdapter / SonySDKAdapter which delegate to their
 *    respective singletons.  The JPEG decode thread is owned by
 *    CameraController (Qt layer) — one per active camera.
 *
 * Stability guarantees
 * ────────────────────
 *  • No shared lock between Canon and Sony modules.
 *  • Canon EDSDK never called from a thread other than the one that
 *    called EdsInitializeSDK (the main thread).  Detection threads only
 *    call EdsGetCameraList which is safe after initialization.
 *  • std::promise / std::future used for inter-thread result transfer to
 *    avoid data races on timeout.
 *  • Timed-out detection threads are detached; they hold only their own
 *    stack locals, so detaching is safe.
 *=============================================================================*/

#include "ICameraSDK.h"
#include "CanonSDKAdapter.h"
#include "SonySDKAdapter.h"
#include "NikonSDKAdapter.h"
#include "FujiSDKAdapter.h"
#include "CanonService.h"
#include "SonyService.h"
#include "NikonService.h"
#include "FujiService.h"
#include "CameraDescriptor.h"

#include <thread>
#include <future>
#include <chrono>
#include <algorithm>
#include <QDebug>

// Per-SDK detection timeouts (ms).
// Detection runs sequentially: Canon first (fast ~instant), then Sony.
// Canon enumeration is nearly instant (USB list); give it 5 s to be safe.
// Sony EnumCameraObjects(timeInSec=5) blocks for up to 5 s; add 3 s overhead.
// Running Sony after Canon ensures the USB bus is free, so 8 s is sufficient.
static constexpr int kCanonDetectionTimeoutMs = 5000;
static constexpr int kSonyDetectionTimeoutMs  = 8000;  // Sony scan=5s + 3s overhead
static constexpr int kNikonDetectionTimeoutMs = 5000;  // Nikon device list poll (~3s) + overhead
static constexpr int kFujiDetectionTimeoutMs  = 5000;  // XSDK_Detect/OpenEx scan

class DualSDKController final : public ICameraSDK {
public:
    static DualSDKController& instance() {
        static DualSDKController s;
        return s;
    }

    std::string sdkType() const override {
        return m_active ? m_active->sdkType() : "None";
    }

    // =========================================================================
    // Preferred brand — chosen by the user in Camera Settings ("Camera Source")
    // =========================================================================
    // Detection still scans both SDKs (so an unplugged preferred camera can
    // gracefully fall back), but findCameras() lists the preferred brand FIRST
    // so connectCamera(0) opens the camera the user actually selected.
    // Default: Canon.
    void setPreferredBrand(const std::string& brand) override {
        if (brand == "Sony")
            m_preferredBrand = CameraDescriptor::Brand::Sony;
        else if (brand == "Nikon")
            m_preferredBrand = CameraDescriptor::Brand::Nikon;
        else if (brand == "Fuji" || brand == "Fujifilm")
            m_preferredBrand = CameraDescriptor::Brand::Fuji;
        else
            m_preferredBrand = CameraDescriptor::Brand::Canon;
        qWarning() << "[DualSDK] Preferred camera brand set to"
                   << QString::fromStdString(brand);
    }

    // =========================================================================
    // Phase 1 — SDK Initialization  [MAIN THREAD ONLY]
    // =========================================================================
    // Initializes Canon EDSDK first, then Sony CRSDK, sequentially.
    // Must be called from the main thread to satisfy Canon's COM requirements
    // on Windows and to avoid undefined behaviour with EDSDK message pumping.
    //
    // Returns true if at least one SDK was successfully initialised.
    // Guard prevents duplicate work when called a second time from
    // CameraController::connectToServer() on the background thread.
    // =========================================================================
    bool initialize() override {
        if (m_initialized.exchange(true)) return true;  // already done on main thread

        qWarning() << "[DualSDK] Phase 1: initializing SDKs (sequential, main thread)";

        bool canonOk = CanonService::instance().initSDK();
        bool sonyOk  = SonyService::instance().initSDK();
        bool nikonOk = NikonService::instance().initSDK();
        bool fujiOk  = FujiService::instance().initSDK();

        qWarning() << "[DualSDK] Phase 1 done: Canon=" << canonOk
                   << "Sony=" << sonyOk << "Nikon=" << nikonOk
                   << "Fuji=" << fujiOk;

        if (!canonOk && !sonyOk && !nikonOk && !fujiOk) {
            m_initialized = false;  // allow retry
            qCritical() << "[DualSDK] All SDKs failed to initialize";
            return false;
        }
        return true;
    }

    // =========================================================================
    // Phase 2 — Sequential Camera Detection  [safe to call from any thread]
    // =========================================================================
    // Canon detection runs first (fast, ~instant).  Sony detection starts only
    // AFTER Canon finishes, so the USB bus is free and Sony's
    // EnumCameraObjects(5 s) is not starved by Canon's USB notification hooks.
    // Results are transferred through std::promise to guarantee no data race
    // even if a thread outlives the wait (detached on timeout).
    // =========================================================================
    bool findCameras(std::vector<CameraInfo>& out) override {
        m_detected.clear();
        out.clear();

        qDebug() << "[DualSDK] Phase 2: detecting cameras (sequential: Canon then Sony,"
                 << "Canon timeout" << kCanonDetectionTimeoutMs << "ms,"
                 << "Sony timeout" << kSonyDetectionTimeoutMs << "ms)";

        using DescList = std::vector<CameraDescriptor>;

        // Nikon Control Service Layer is sensitive to cross-SDK/cross-thread
        // probing. When the user explicitly selects Nikon, scan only Nikon and
        // leave Canon/Sony untouched until those brands are selected.
        if (m_preferredBrand == CameraDescriptor::Brand::Nikon) {
            qWarning() << "[DualSDK] Nikon preferred: scanning Nikon only";
            if (NikonService::instance().isSDKInitialized()) {
                DescList cams;
                try {
                    NikonService::instance().detectCameras(cams);
                } catch (const std::exception& e) {
                    qWarning() << "[DualSDK][Nikon] Exception in detection:" << e.what();
                } catch (...) {
                    qWarning() << "[DualSDK][Nikon] Unknown exception in detection";
                }
                for (auto& d : cams) m_detected.push_back(std::move(d));
            }

            for (auto& d : m_detected)
                out.push_back({ d.name, d.portName });

            qWarning() << "[DualSDK] Nikon-only detection complete:"
                       << (int)m_detected.size() << "camera(s)";
            return !m_detected.empty();
        }

        // FUJIFILM X SDK owns a single camera-side image queue for live view
        // and still transfer. When Fuji is explicitly selected, scan only Fuji
        // so other vendor SDKs do not touch the same USB session path.
        if (m_preferredBrand == CameraDescriptor::Brand::Fuji) {
            qWarning() << "[DualSDK] Fuji preferred: scanning Fuji only";
            if (FujiService::instance().isSDKInitialized()) {
                DescList cams;
                try {
                    FujiService::instance().detectCameras(cams);
                } catch (const std::exception& e) {
                    qWarning() << "[DualSDK][Fuji] Exception in detection:" << e.what();
                } catch (...) {
                    qWarning() << "[DualSDK][Fuji] Unknown exception in detection";
                }
                for (auto& d : cams) m_detected.push_back(std::move(d));
            }

            for (auto& d : m_detected)
                out.push_back({ d.name, d.portName });

            qWarning() << "[DualSDK] Fuji-only detection complete:"
                       << (int)m_detected.size() << "camera(s)";
            return !m_detected.empty();
        }

        // ── Canon detection first (fast ~instant; frees USB before Sony scans) ──
        if (CanonService::instance().isSDKInitialized()) {
            std::promise<DescList> p;
            auto f = p.get_future();
            std::thread([p = std::move(p)]() mutable {
                DescList cams;
                try {
                    CanonService::instance().detectCameras(cams);
                } catch (const std::exception& e) {
                    qWarning() << "[DualSDK][Canon] Exception in detection thread:" << e.what();
                } catch (...) {
                    qWarning() << "[DualSDK][Canon] Unknown exception in detection thread";
                }
                p.set_value(std::move(cams));
            }).detach();

            auto deadline = std::chrono::steady_clock::now()
                          + std::chrono::milliseconds(kCanonDetectionTimeoutMs);
            if (f.wait_until(deadline) == std::future_status::ready) {
                for (auto& d : f.get()) m_detected.push_back(std::move(d));
            } else {
                qWarning() << "[DualSDK] Canon detection timed out";
            }
        }

        // ── Sony detection second (5 s USB scan, USB bus now clear of Canon) ──
        if (SonyService::instance().isSDKInitialized()) {
            std::promise<DescList> p;
            auto f = p.get_future();
            std::thread([p = std::move(p)]() mutable {
                DescList cams;
                try {
                    SonyService::instance().detectCameras(cams);
                } catch (const std::exception& e) {
                    qWarning() << "[DualSDK][Sony] Exception in detection thread:" << e.what();
                } catch (...) {
                    qWarning() << "[DualSDK][Sony] Unknown exception in detection thread";
                }
                p.set_value(std::move(cams));
            }).detach();

            auto deadline = std::chrono::steady_clock::now()
                          + std::chrono::milliseconds(kSonyDetectionTimeoutMs);
            if (f.wait_until(deadline) == std::future_status::ready) {
                for (auto& d : f.get()) m_detected.push_back(std::move(d));
            } else {
                qWarning() << "[DualSDK] Sony detection timed out";
            }
        }

        // ── Nikon detection third (device list poll; USB bus now clear) ──
        if (NikonService::instance().isSDKInitialized()) {
            std::promise<DescList> p;
            auto f = p.get_future();
            std::thread([p = std::move(p)]() mutable {
                DescList cams;
                try {
                    NikonService::instance().detectCameras(cams);
                } catch (const std::exception& e) {
                    qWarning() << "[DualSDK][Nikon] Exception in detection thread:" << e.what();
                } catch (...) {
                    qWarning() << "[DualSDK][Nikon] Unknown exception in detection thread";
                }
                p.set_value(std::move(cams));
            }).detach();

            auto deadline = std::chrono::steady_clock::now()
                          + std::chrono::milliseconds(kNikonDetectionTimeoutMs);
            if (f.wait_until(deadline) == std::future_status::ready) {
                for (auto& d : f.get()) m_detected.push_back(std::move(d));
            } else {
                qWarning() << "[DualSDK] Nikon detection timed out";
            }
        }

        // â”€â”€ Fuji detection fourth (after other SDK probes unless preferred) â”€â”€
        if (FujiService::instance().isSDKInitialized()) {
            std::promise<DescList> p;
            auto f = p.get_future();
            std::thread([p = std::move(p)]() mutable {
                DescList cams;
                try {
                    FujiService::instance().detectCameras(cams);
                } catch (const std::exception& e) {
                    qWarning() << "[DualSDK][Fuji] Exception in detection thread:" << e.what();
                } catch (...) {
                    qWarning() << "[DualSDK][Fuji] Unknown exception in detection thread";
                }
                p.set_value(std::move(cams));
            }).detach();

            auto deadline = std::chrono::steady_clock::now()
                          + std::chrono::milliseconds(kFujiDetectionTimeoutMs);
            if (f.wait_until(deadline) == std::future_status::ready) {
                for (auto& d : f.get()) m_detected.push_back(std::move(d));
            } else {
                qWarning() << "[DualSDK] Fuji detection timed out";
            }
        }

        // Order the unified list so the user-selected brand comes first.
        // connectCamera(0) then opens the preferred camera; if the preferred
        // brand has no camera connected, the other brand is used as fallback.
        std::stable_sort(m_detected.begin(), m_detected.end(),
            [this](const CameraDescriptor& a, const CameraDescriptor& b) {
                bool ap = (a.brand == m_preferredBrand);
                bool bp = (b.brand == m_preferredBrand);
                return ap && !bp;
            });

        qDebug() << "[DualSDK] Preferred brand:"
                 << (m_preferredBrand == CameraDescriptor::Brand::Sony  ? "Sony"
                   : m_preferredBrand == CameraDescriptor::Brand::Nikon ? "Nikon"
                   : m_preferredBrand == CameraDescriptor::Brand::Fuji  ? "Fuji" : "Canon");
        qDebug() << "[DualSDK] Detection complete:"
                 << (int)m_detected.size() << "total camera(s) found";
        for (int i = 0; i < (int)m_detected.size(); ++i) {
            qDebug() << "  [" << i << "]"
                     << QString::fromStdString(m_detected[i].brandName())
                     << QString::fromStdString(m_detected[i].name);
        }

        // Convert to ICameraSDK::CameraInfo for the caller
        for (auto& d : m_detected)
            out.push_back({ d.name, d.portName });

        return !m_detected.empty();
    }

    // =========================================================================
    // Phase 3 — Camera Connection
    // =========================================================================
    // Selects the adapter matching the detected camera at position `index`
    // in the list returned by findCameras().
    // If index == 0 and only one camera was found, this auto-connects.
    // For multiple cameras the Qt layer should display a selection UI.
    // =========================================================================
    bool connectCamera(int index) override {
        if (index < 0 || index >= static_cast<int>(m_detected.size())) {
            qWarning() << "[DualSDK] connectCamera: index" << index
                       << "out of range (detected" << (int)m_detected.size() << ")";
            return false;
        }

        const CameraDescriptor& desc = m_detected[index];
        qWarning() << "[DualSDK] Phase 3: connecting to"
                   << QString::fromStdString(desc.brandName())
                   << QString::fromStdString(desc.name);

        // Select the new adapter.
        ICameraSDK* newAdapter = nullptr;
        if (desc.brand == CameraDescriptor::Brand::Canon)
            newAdapter = &CanonSDKAdapter::instance();
        else if (desc.brand == CameraDescriptor::Brand::Sony)
            newAdapter = &SonySDKAdapter::instance();
        else if (desc.brand == CameraDescriptor::Brand::Nikon)
            newAdapter = &NikonSDKAdapter::instance();
        else if (desc.brand == CameraDescriptor::Brand::Fuji)
            newAdapter = &FujiSDKAdapter::instance();
        else {
            qWarning() << "[DualSDK] Unknown brand — cannot connect";
            return false;
        }

        // Disconnect the OLD adapter if we are switching brands.
        // Sony CRSDK keeps a session handle alive until explicitly closed;
        // leaving it open prevents EnumCameraObjects from finding the camera
        // on subsequent detection passes.
        if (m_active && m_active != newAdapter && m_active->isConnected()) {
            qDebug() << "[DualSDK] Disconnecting previous adapter before brand switch";
            m_active->disconnectCamera();
        }
        m_active = newAdapter;

        // Replay pre-connection state onto the now-active adapter
        applyPending();

        // Open session to the specific device within the brand
        qWarning() << "[DualSDK] Phase 3: adapter connect begin";
        const bool ok = m_active->connectCamera(desc.index);
        qWarning() << "[DualSDK] Phase 3: adapter connect end ok =" << ok;
        return ok;
    }

    // =========================================================================
    // Shutdown
    // =========================================================================
    void shutdown() override {
        if (m_active) {
            m_active->disconnectCamera();
            m_active = nullptr;
        }
        CanonService::instance().shutdownSDK();
        SonyService::instance().shutdownSDK();
        NikonService::instance().shutdownSDK();
        FujiService::instance().shutdownSDK();
        m_detected.clear();
        qDebug() << "[DualSDK] Shutdown complete";
    }

    // Returns the full detected camera list — useful for UI selection dialogs.
    const std::vector<CameraDescriptor>& detectedCameras() const { return m_detected; }

    // =========================================================================
    // Events — buffered before connectCamera(), forwarded after
    // =========================================================================
    void addEventListener(CameraApp::ICameraEventListener* l) override {
        m_listeners.push_back(l);
        if (m_active) m_active->addEventListener(l);
    }
    void removeEventListener(CameraApp::ICameraEventListener* l) override {
        m_listeners.erase(
            std::remove(m_listeners.begin(), m_listeners.end(), l),
            m_listeners.end());
        if (m_active) m_active->removeEventListener(l);
    }

    // =========================================================================
    // Runtime delegation — all forwarded to active adapter
    // =========================================================================
    bool disconnectCamera()   override { return m_active && m_active->disconnectCamera(); }
    bool isConnected() const  override { return m_active && m_active->isConnected(); }
    bool extendKeepAlive()    override { return m_active ? m_active->extendKeepAlive() : true; }

    bool takePhoto()     override { return m_active && m_active->takePhoto(); }
    bool takePhotoNoAF() override { return m_active && m_active->takePhotoNoAF(); }
    void setRemoteShutterMode(bool on) override {
        m_remoteShutterMode = on;
        if (m_active) m_active->setRemoteShutterMode(on);
    }

    bool startLiveView()          override { return m_active && m_active->startLiveView(); }
    bool stopLiveView()           override { return m_active && m_active->stopLiveView(); }
    bool startLiveViewStreaming() override { return m_active && m_active->startLiveViewStreaming(); }
    bool stopLiveViewStreaming()  override { return m_active && m_active->stopLiveViewStreaming(); }
    void setLiveViewFrameCallback(std::function<void(const uint8_t*, size_t)> cb) override {
        if (m_active) m_active->setLiveViewFrameCallback(std::move(cb));
    }
    void setFujiLiveViewOptions(const std::string& size,
                                const std::string& quality) override {
        m_fujiLiveViewSize = size;
        m_fujiLiveViewQuality = quality;
        if (m_active) m_active->setFujiLiveViewOptions(size, quality);
    }

    bool getPropertyStrings(uint32_t propId,
                            std::vector<std::string>& list,
                            std::string& cur) override {
        return m_active && m_active->getPropertyStrings(propId, list, cur);
    }
    bool setISO(int v)                        override { return m_active && m_active->setISO(v); }
    bool setShutterSpeed(const std::string& v) override { return m_active && m_active->setShutterSpeed(v); }
    bool setAperture(const std::string& v)     override { return m_active && m_active->setAperture(v); }
    bool setWhiteBalance(int v)               override { return m_active && m_active->setWhiteBalance(v); }
    bool setColorTemperature(int v)           override { return m_active && m_active->setColorTemperature(v); }
    bool setExposureComp(int v)               override { return m_active && m_active->setExposureComp(v); }
    bool setImageQuality(int v)               override { return m_active && m_active->setImageQuality(v); }

    State       getState()       const override { return m_active ? m_active->getState() : State{}; }
    std::string getCameraModel() const override { return m_active ? m_active->getCameraModel() : ""; }
    std::string getLastError()   const override {
        return m_active ? m_active->getLastError() : "No SDK active";
    }
    void setSaveFolder(const std::string& p) override {
        m_saveFolder = p;
        if (m_active) m_active->setSaveFolder(p);
    }

private:
    DualSDKController() = default;

    std::atomic<bool> m_initialized{false};
    ICameraSDK*  m_active   = nullptr;
    CameraDescriptor::Brand m_preferredBrand = CameraDescriptor::Brand::Canon;
    std::vector<CameraDescriptor>              m_detected;
    std::vector<CameraApp::ICameraEventListener*> m_listeners;
    std::string  m_saveFolder;
    std::string  m_fujiLiveViewSize = "auto";
    std::string  m_fujiLiveViewQuality = "fine";
    bool         m_remoteShutterMode = false;

    // Replay buffered state that arrived before connectCamera() was called.
    void applyPending() {
        for (auto* l : m_listeners) m_active->addEventListener(l);
        if (!m_saveFolder.empty()) m_active->setSaveFolder(m_saveFolder);
        m_active->setRemoteShutterMode(m_remoteShutterMode);
        m_active->setFujiLiveViewOptions(m_fujiLiveViewSize, m_fujiLiveViewQuality);
    }
};
