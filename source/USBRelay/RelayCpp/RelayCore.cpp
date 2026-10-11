// RelayCore.cpp
#include "RelayCore.h"
#include "usb_relay_device.h"   // header DLL hang (them include path lib\usb_relay_dll)

#include <cstring>

namespace RelayCore
{
    bool Core_Init()
    {
        // usb_relay_init tra ve 0 = thanh cong, -1 = loi.
        return usb_relay_init() == 0;
    }

    void Core_Exit()
    {
        usb_relay_exit();
    }

    std::vector<std::string> Core_ListSerials()
    {
        std::vector<std::string> serials;

        usb_relay_device_info* head = usb_relay_device_enumerate();
        for (usb_relay_device_info* cur = head; cur != nullptr; cur = cur->next)
        {
            if (cur->serial_number)
                serials.push_back(reinterpret_cast<char*>(cur->serial_number));
        }

        // Quan trong: giai phong danh sach lien ket (ban RelayWrapper cu khong free -> ro ri).
        if (head)
            usb_relay_device_free_enumerate(head);

        return serials;
    }

    std::vector<DeviceInfo> Core_ListDevices()
    {
        std::vector<DeviceInfo> devices;

        usb_relay_device_info* head = usb_relay_device_enumerate();
        for (usb_relay_device_info* cur = head; cur != nullptr; cur = cur->next)
        {
            if (cur->serial_number)
            {
                DeviceInfo d;
                d.serial   = reinterpret_cast<char*>(cur->serial_number);
                d.channels = static_cast<int>(cur->type);   // enum value = so kenh (1/2/4/8)
                devices.push_back(d);
            }
        }

        if (head)
            usb_relay_device_free_enumerate(head);

        return devices;
    }

    int Core_Open(const std::string& serial)
    {
        // Tra ve handle hop le (> 0) hoac 0 neu that bai.
        return usb_relay_device_open_with_serial_number(
            serial.c_str(), static_cast<unsigned>(serial.size()));
    }

    void Core_Close(int handle)
    {
        if (handle != 0)
            usb_relay_device_close(handle);
    }

    bool Core_SetOne(int handle, int channel, bool on)
    {
        if (handle == 0 || channel < 1)
            return false;

        int ret = on
            ? usb_relay_device_open_one_relay_channel(handle, channel)
            : usb_relay_device_close_one_relay_channel(handle, channel);
        return ret == 0;
    }

    bool Core_SetAll(int handle, bool on)
    {
        if (handle == 0)
            return false;

        int ret = on
            ? usb_relay_device_open_all_relay_channel(handle)
            : usb_relay_device_close_all_relay_channel(handle);
        return ret == 0;
    }

    bool Core_GetStatus(int handle, unsigned int& status)
    {
        if (handle == 0)
            return false;

        return usb_relay_device_get_status(handle, &status) == 0;
    }
}
