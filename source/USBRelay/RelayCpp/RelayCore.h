// RelayCore.h
// Lop loi C++ thuan bao quanh usb_relay_device.dll (DLL hang).
// Dung chung cho ca app EXE (RelayControl) va plugin DLL (RelayPlugin).
// Khong phu thuoc .NET / C++-CLI.
#pragma once

#include <string>
#include <vector>

namespace RelayCore
{
    // Khoi tao / giai phong thu vien USB Relay.
    // Core_Init tra ve true neu thanh cong.
    bool Core_Init();
    void Core_Exit();

    // Liet ke serial number cua cac thiet bi relay dang cam.
    // Tu giai phong danh sach enumerate (tranh ro ri bo nho).
    std::vector<std::string> Core_ListSerials();

    // Thiet bi relay: serial + so kenh (1/2/4/8 — lay tu usb_relay_device_type).
    struct DeviceInfo
    {
        std::string serial;
        int channels;
    };

    // Liet ke thiet bi kem so kenh. Tu giai phong danh sach enumerate.
    std::vector<DeviceInfo> Core_ListDevices();

    // Mo thiet bi theo serial number. Tra ve handle (> 0) hoac 0 neu loi.
    int Core_Open(const std::string& serial);

    // Dong thiet bi theo handle.
    void Core_Close(int handle);

    // Bat (on=true) / tat (on=false) mot kenh (channel: 1..N).
    // Tra ve true neu thanh cong.
    bool Core_SetOne(int handle, int channel, bool on);

    // Bat / tat tat ca cac kenh. Tra ve true neu thanh cong.
    bool Core_SetAll(int handle, bool on);

    // Doc trang thai: moi bit ung voi mot kenh (bit 0 = kenh 1...).
    // 1 = dang bat, 0 = dang tat. Tra ve true neu doc thanh cong.
    bool Core_GetStatus(int handle, unsigned int& status);
}
