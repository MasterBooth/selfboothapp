/*=============================================================================
 * canon_edsdk_bind.cpp
 * pybind11 Python bindings for CameraApp::CameraController (Canon EDSDK)
 *
 * Build output: canon_edsdk.pyd  (Python extension for Windows)
 * Python usage:
 *   import canon_edsdk
 *   canon_edsdk.initialize()
 *   canon_edsdk.connect(0)
 *   canon_edsdk.start_live_view()
 *   canon_edsdk.set_live_view_callback(lambda jpeg: ...)
 *   canon_edsdk.take_photo()
 *   canon_edsdk.shutdown()
 *=============================================================================*/

#include <pybind11/pybind11.h>
#include <pybind11/functional.h>
#include <pybind11/stl.h>

#include "../API/CameraController.h"

#include <thread>
#include <atomic>
#include <chrono>
#include <mutex>
#include <condition_variable>

// Windows COM (required by EDSDK)
#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <objbase.h>
#endif

namespace py = pybind11;
using namespace CameraApp;

// ─────────────────────────────────────────────────────────────────────────────
// Internal event-pump thread
//
// Canon EDSDK REQUIRES that EdsGetEvent() is called from the SAME thread that
// called EdsInitializeSDK().  If they differ, object-event callbacks such as
// kEdsObjectEvent_DirItemRequestTransfer (fired after a shutter press) are
// silently dropped — live-view keeps working because its frames arrive via the
// CommandQueue streaming thread, not via EdsGetEvent().
//
// Fix: the pump thread owns the full SDK lifecycle:
//   1. Calls CoInitializeEx + ctrl.initialize() (EdsInitializeSDK)
//   2. Signals the caller via g_initResult once ready
//   3. Loops calling EdsGetEvent() on the same thread
//   4. On stopPump(): exits loop, calls ctrl.shutdown() + CoUninitialize()
// ─────────────────────────────────────────────────────────────────────────────
namespace {
    std::thread              g_pumpThread;
    std::atomic<bool>        g_pumpRunning{false};

    // One-shot init result communicated back to the Python initialize() call
    std::mutex               g_initMutex;
    std::condition_variable  g_initCv;
    bool                     g_initDone{false};
    bool                     g_initOk{false};

    void pumpThreadFn(CameraController* ctrl) {
#ifdef _WIN32
        CoInitializeEx(nullptr, COINIT_MULTITHREADED);
#endif
        // ── Initialize SDK on this thread ─────────────────────────────────
        bool ok = ctrl->initialize();

        {
            std::lock_guard<std::mutex> lk(g_initMutex);
            g_initOk   = ok;
            g_initDone = true;
        }
        g_initCv.notify_one();

        // ── Event loop (same thread as EdsInitializeSDK) ──────────────────
        if (ok) {
            while (g_pumpRunning.load()) {
                EdsGetEvent();   // delivers DirItemRequestTransfer, state events …
                std::this_thread::sleep_for(std::chrono::milliseconds(8));
            }
        }

        // ── Cleanup on this thread ─────────────────────────────────────────
        ctrl->shutdown();
#ifdef _WIN32
        CoUninitialize();
#endif
    }

    // Returns true if SDK initialised successfully.
    // Blocks the calling thread until the pump thread has finished init.
    bool startPump(CameraController* ctrl) {
        if (g_pumpRunning.exchange(true)) return true;  // already running

        g_initDone = false;
        g_initOk   = false;
        g_pumpThread = std::thread(pumpThreadFn, ctrl);

        std::unique_lock<std::mutex> lk(g_initMutex);
        g_initCv.wait(lk, [] { return g_initDone; });
        return g_initOk;
    }

    void stopPump() {
        g_pumpRunning.store(false);
        if (g_pumpThread.joinable())
            g_pumpThread.join();
    }
} // namespace

// ─────────────────────────────────────────────────────────────────────────────
// Persistent Python event callback holder
// ─────────────────────────────────────────────────────────────────────────────
namespace {
    // We keep a single listener alive for the lifetime of the module.
    struct PyEventListener : public ICameraEventListener {
        py::function fn;
        explicit PyEventListener(py::function f) : fn(std::move(f)) {}

        void onCameraEvent(const CameraEvent& ev) override {
            // Called from C++ thread — must acquire GIL
            py::gil_scoped_acquire acq;
            try {
                fn(static_cast<int>(ev.type), ev.message, ev.fileName);
            } catch (py::error_already_set& e) {
                e.discard_as_unraisable("canon_edsdk.event_callback");
            }
        }
    };

    std::unique_ptr<PyEventListener> g_listener;
} // namespace

// ─────────────────────────────────────────────────────────────────────────────
// Module definition
// ─────────────────────────────────────────────────────────────────────────────
PYBIND11_MODULE(canon_edsdk, m) {
    m.doc() = "Canon EDSDK Python bindings (pybind11) — wraps CameraApp::CameraController";

    auto& ctrl = CameraController::instance();

    // ── Event type constants ─────────────────────────────────────────────────
    py::enum_<CameraEventType>(m, "EventType")
        .value("Connected",              CameraEventType::Connected)
        .value("Disconnected",           CameraEventType::Disconnected)
        .value("CaptureStarted",         CameraEventType::CaptureStarted)
        .value("CaptureCompleted",       CameraEventType::CaptureCompleted)
        .value("CaptureError",           CameraEventType::CaptureError)
        .value("LiveViewStarted",        CameraEventType::LiveViewStarted)
        .value("LiveViewStopped",        CameraEventType::LiveViewStopped)
        .value("LiveViewFrameReceived",  CameraEventType::LiveViewFrameReceived)
        .value("PropertyChanged",        CameraEventType::PropertyChanged)
        .export_values();

    // ── SDK lifecycle ────────────────────────────────────────────────────────

    m.def("initialize", [&ctrl]() -> bool {
        // EdsInitializeSDK + EdsGetEvent() both run on the pump thread.
        // We block here (GIL released) until the pump thread reports success.
        py::gil_scoped_release rel;
        return startPump(&ctrl);
    }, "Initialize Canon EDSDK. Call once before any other function.");

    m.def("shutdown", [&ctrl]() {
        // Signal the pump loop to exit; the pump thread calls ctrl.shutdown().
        py::gil_scoped_release rel;
        stopPump();
        // ctrl.shutdown() and CoUninitialize() are called inside pumpThreadFn.
    }, "Shutdown Canon EDSDK and release all resources.");

    // ── Camera discovery ─────────────────────────────────────────────────────

    m.def("get_camera_count", [&ctrl]() -> int {
        return ctrl.getCameraCount();
    }, "Return number of connected Canon cameras.");

    m.def("list_cameras", [&ctrl]() -> py::list {
        std::vector<CameraInfo> cams;
        ctrl.findCameras(cams);
        py::list result;
        for (size_t i = 0; i < cams.size(); ++i) {
            py::dict d;
            d["index"]    = i;
            d["name"]     = cams[i].name;
            d["portName"] = cams[i].portName;
            d["bodyId"]   = cams[i].bodyId;
            result.append(d);
        }
        return result;
    }, "Return list of dicts describing connected cameras.");

    // ── Connection ───────────────────────────────────────────────────────────

    m.def("connect", [&ctrl](int index) -> bool {
        py::gil_scoped_release rel;
        return ctrl.connectCamera(index);
    }, py::arg("camera_index") = 0, "Connect to camera by index.");

    m.def("disconnect", [&ctrl]() -> bool {
        py::gil_scoped_release rel;
        return ctrl.disconnectCamera();
    }, "Disconnect from current camera.");

    m.def("is_connected", [&ctrl]() -> bool {
        return ctrl.isConnected();
    });

    m.def("get_model", [&ctrl]() -> std::string {
        return ctrl.getCameraModel();
    }, "Return connected camera model string.");

    m.def("set_save_folder", [&ctrl](const std::string& path) {
        ctrl.setSaveFolder(path);
    }, "Set folder where captured photos are saved.");

    m.def("get_save_folder", [&ctrl]() -> std::string {
        return ctrl.getSaveFolder();
    });

    // ── Photo capture ────────────────────────────────────────────────────────

    m.def("take_photo", [&ctrl]() -> bool {
        py::gil_scoped_release rel;
        return ctrl.takePhoto();
    }, "Take photo with autofocus. Blocks until image is downloaded.");

    m.def("take_photo_no_af", [&ctrl]() -> bool {
        py::gil_scoped_release rel;
        return ctrl.takePhotoNoAF();
    }, "Take photo without autofocus.");

    m.def("get_last_photo_path", [&ctrl]() -> std::string {
        return ctrl.getLastPhotoPath();
    }, "Return file path of last captured photo.");

    m.def("set_auto_download", [&ctrl](bool enabled) {
        ctrl.setAutoDownload(enabled);
    });

    // ── Live view ────────────────────────────────────────────────────────────

    m.def("start_live_view", [&ctrl]() -> bool {
        py::gil_scoped_release rel;
        return ctrl.startLiveView();
    }, "Enable live view (EVF) on camera.");

    m.def("stop_live_view", [&ctrl]() -> bool {
        py::gil_scoped_release rel;
        return ctrl.stopLiveView();
    }, "Disable live view.");

    m.def("is_live_view_active", [&ctrl]() -> bool {
        return ctrl.isLiveViewActive();
    });

    m.def("start_streaming", [&ctrl]() -> bool {
        py::gil_scoped_release rel;
        return ctrl.startLiveViewStreaming();
    }, "Start continuous live view frame streaming.");

    m.def("stop_streaming", [&ctrl]() -> bool {
        py::gil_scoped_release rel;
        return ctrl.stopLiveViewStreaming();
    });

    // GET a single frame on demand (blocking, no callback needed)
    m.def("get_frame", [&ctrl]() -> py::object {
        LiveViewFrame frame;
        {
            py::gil_scoped_release rel;
            if (!ctrl.getLiveViewFrame(frame)) return py::none();
        }
        if (frame.jpegData.empty()) return py::none();
        return py::bytes(
            reinterpret_cast<const char*>(frame.jpegData.data()),
            frame.jpegData.size());
    }, "Fetch a single live view JPEG frame. Returns bytes or None.");

    // Continuous streaming callback (called from C++ streaming thread)
    m.def("set_live_view_callback", [&ctrl](py::object cb) {
        if (cb.is_none()) {
            ctrl.setLiveViewFrameCallback(nullptr);
            return;
        }
        py::function fn = cb.cast<py::function>();
        ctrl.setLiveViewFrameCallback([fn](const uint8_t* data, size_t size) {
            // C++ streaming thread → must acquire GIL before touching Python
            py::gil_scoped_acquire acq;
            try {
                fn(py::bytes(reinterpret_cast<const char*>(data), size));
            } catch (py::error_already_set& e) {
                e.discard_as_unraisable("canon_edsdk.live_view_callback");
            }
        });
    }, py::arg("callback"),
    "Set callback(jpeg_bytes: bytes) called on every live view frame.");

    // ── Camera parameters ────────────────────────────────────────────────────

    m.def("set_iso", [&ctrl](int iso) -> bool {
        py::gil_scoped_release rel;
        return ctrl.setISO(iso);
    }, py::arg("iso"), "Set ISO (e.g. 100, 200, 400, 800, 1600, 3200).");

    m.def("set_shutter_speed", [&ctrl](const std::string& v) -> bool {
        py::gil_scoped_release rel;
        return ctrl.setShutterSpeed(v);
    }, py::arg("value"), "Set shutter speed string (e.g. '1/250', '1/60').");

    m.def("set_aperture", [&ctrl](const std::string& v) -> bool {
        py::gil_scoped_release rel;
        return ctrl.setAperture(v);
    }, py::arg("value"), "Set aperture string (e.g. 'f/5.6', 'f/2.8').");

    m.def("set_white_balance", [&ctrl](int mode) -> bool {
        py::gil_scoped_release rel;
        return ctrl.setWhiteBalance(mode);
    }, py::arg("mode"), "Set white balance mode (0=Auto, 1=Daylight, etc.).");

    m.def("set_color_temperature", [&ctrl](int kelvin) -> bool {
        py::gil_scoped_release rel;
        return ctrl.setColorTemperature(kelvin);
    }, py::arg("kelvin"));

    m.def("set_exposure_comp", [&ctrl](int ev) -> bool {
        py::gil_scoped_release rel;
        return ctrl.setExposureComp(ev);
    }, py::arg("ev"), "Set exposure compensation (-2 to +2 stops).");

    m.def("extend_keep_alive", [&ctrl]() -> bool {
        py::gil_scoped_release rel;
        return ctrl.extendKeepAlive();
    });

    // ── Property lists ───────────────────────────────────────────────────────
    // propId constants exposed for convenience
    m.attr("PROP_ISO")            = (int)kEdsPropID_ISOSpeed;
    m.attr("PROP_SHUTTER")        = (int)kEdsPropID_Tv;
    m.attr("PROP_APERTURE")       = (int)kEdsPropID_Av;
    m.attr("PROP_WHITE_BALANCE")  = (int)kEdsPropID_WhiteBalance;
    m.attr("PROP_EXPOSURE_COMP")  = (int)kEdsPropID_ExposureCompensation;

    m.def("get_property_strings", [&ctrl](int propId) -> py::dict {
        std::vector<std::string> list;
        std::string current;
        bool ok = ctrl.getPropertyStrings((EdsPropertyID)propId, list, current);
        py::dict d;
        d["ok"]      = ok;
        d["list"]    = list;
        d["current"] = current;
        return d;
    }, py::arg("prop_id"),
    "Return {'ok', 'list': [...], 'current': '...'} for a property.");

    // ── Event callbacks ──────────────────────────────────────────────────────

    m.def("set_event_callback", [&ctrl](py::object cb) {
        if (g_listener) ctrl.removeEventListener(g_listener.get());
        if (cb.is_none()) { g_listener.reset(); return; }
        g_listener = std::make_unique<PyEventListener>(cb.cast<py::function>());
        ctrl.addEventListener(g_listener.get());
    }, py::arg("callback"),
    "Set callback(event_type: int, message: str, file_name: str).");

    // ── Error info ───────────────────────────────────────────────────────────

    m.def("get_last_error", [&ctrl]() -> std::string {
        return ctrl.getLastError();
    });

    m.def("get_last_error_code", [&ctrl]() -> int {
        return (int)ctrl.getLastErrorCode();
    });

    // ── Lens focus (live view) ───────────────────────────────────────────────

    m.def("drive_lens_near", [&ctrl]() -> bool {
        py::gil_scoped_release rel; return ctrl.driveLensNear(); });
    m.def("drive_lens_far",  [&ctrl]() -> bool {
        py::gil_scoped_release rel; return ctrl.driveLensFar(); });
    m.def("start_autofocus", [&ctrl]() -> bool {
        py::gil_scoped_release rel; return ctrl.startAutofocus(); });
    m.def("stop_autofocus",  [&ctrl]() -> bool {
        py::gil_scoped_release rel; return ctrl.stopAutofocus(); });
}
