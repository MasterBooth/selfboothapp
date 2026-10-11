// ICamera.h -- vendor-neutral camera interface.
//
// The photobooth engine talks ONLY to ICamera. FujiCamera implements it for the
// FUJIFILM X SDK; CanonCamera / SonyCamera / NikonCamera would implement the same
// contract over EDSDK / Cross-Camera SDK / Nikon SDK respectively. This is how a
// single BoothoStudio engine supports four vendors through one code path.
#pragma once

#include <cstdint>
#include <functional>
#include <string>
#include <vector>

// A decoded frame or a downloaded still. `data` is JPEG (Live View + JPEG stills)
// or raw container bytes (RAF/HEIF). Ownership transfers to the callback receiver.
struct ImageFrame {
    enum class Kind { Live, Jpeg, Raw, Heif };
    Kind                        kind = Kind::Live;
    std::vector<unsigned char>  data;
    int                         width  = 0;   // 0 if unknown (Live frames)
    int                         height = 0;
    uint64_t                    seq    = 0;   // monotonically increasing per session
};

struct CameraInfo {
    std::string model;
    std::string serial;
    std::string firmware;
    std::string framework;   // "USB" / "ETHER" / "IP"
    std::string lens;
};

enum class CameraError {
    None, NotConnected, Busy, Timeout, Communication,
    Unsupported, ShootError, FrameFull, CardFull, Hardware, Unknown
};

// Callbacks are invoked from the engine's internal poll thread. Implementations
// must marshal to the Qt GUI thread themselves (see EventDispatcher).
class ICamera {
public:
    virtual ~ICamera() = default;

    // --- lifecycle ---
    virtual bool open()  = 0;     // establish tethered session
    virtual void close() = 0;     // end session, safe to call twice
    virtual bool isOpen() const = 0;

    virtual CameraInfo info() const = 0;

    // --- live view ---
    // Fuji-only tuning hook. size <= 0 means native/auto, so the SDK is not
    // asked to force a particular live-view frame size.
    virtual void setLiveViewOptions(long /*quality*/, long /*size*/, long /*mode*/) {}
    virtual bool startLiveView() = 0;
    virtual void stopLiveView()  = 0;

    // --- capture ---
    // Fires the shutter. The resulting still is delivered asynchronously through
    // the onImage callback (NOT returned here) because the SDK download is queue
    // based. Returns false only if the release command itself failed.
    virtual bool capture() = 0;
    virtual bool captureNoAf() { return capture(); }

    // Fire `frames` releases back-to-back. Stills still arrive via onImage.
    virtual bool burst(int frames) = 0;

    // --- exposure properties ---
    // Values are the SDK's coded integers (e.g. XSDK_SENSITIVITY_ISO200 == 200,
    // aperture is F-number*100, shutter is the SDK's shutter code). Setters return
    // false if the control is unsupported by the connected body or the call failed.
    virtual bool setIso(int iso) = 0;
    virtual bool getIso(int& iso) = 0;
    virtual bool setShutterSpeed(int code, bool bulb = false) = 0;
    virtual bool getShutterSpeed(int& code, bool& bulb) = 0;
    virtual bool setAperture(int fnumberX100) = 0;
    virtual bool getAperture(int& fnumberX100) = 0;
    virtual bool setExposureBias(int code) = 0;   // 1/3 EV steps: +1/3 == 10
    virtual bool getExposureBias(int& code) = 0;
    virtual bool setFilmSimulation(int sim) = 0;  // SDK_FILMSIMULATION_*

    // --- capability enumeration (values the body currently accepts) ---
    virtual std::vector<int> capIso() = 0;
    virtual std::vector<int> capShutterSpeed() = 0;
    virtual std::vector<int> capAperture() = 0;
    virtual std::vector<int> capExposureBias() = 0;

    // --- callbacks ---
    std::function<void(const ImageFrame&)> onLiveFrame;   // Live View JPEG frames
    std::function<void(const ImageFrame&)> onImage;       // downloaded stills
    std::function<void(CameraError, const std::string&)> onError;
    std::function<void()> onDisconnected;
};
