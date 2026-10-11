// RelayPlugin.cpp
// Trien khai API plugin cap cao, tai su dung RelayCore.
#define RELAY_PLUGIN_EXPORTS
#include "RelayPlugin.h"
#include "RelayCore.h"

#include <map>
#include <string>
#include <cstring>

using namespace RelayCore;

namespace
{
    bool g_inited = false;
    // Cache serial -> handle de tranh enumerate/open lai moi lan goi.
    std::map<std::string, int> g_handles;

    // Lay handle cho serial, tu mo + cache neu chua co. Tra ve 0 neu loi.
    int GetOrOpen(const char* serial)
    {
        if (!g_inited || serial == nullptr)
            return 0;

        std::string key(serial);
        auto it = g_handles.find(key);
        if (it != g_handles.end() && it->second != 0)
            return it->second;

        int handle = Core_Open(key);
        if (handle != 0)
            g_handles[key] = handle;
        return handle;
    }
}

extern "C" {

int Relay_Init(void)
{
    if (g_inited)
        return 0;
    if (!Core_Init())
        return 1;
    g_inited = true;
    return 0;
}

int Relay_ListDevices(char* buf, int bufLen)
{
    if (!g_inited)
        return -1;

    std::vector<std::string> serials = Core_ListSerials();

    if (buf != nullptr && bufLen > 0)
    {
        std::string out;
        for (size_t i = 0; i < serials.size(); ++i)
        {
            if (i) out += '\n';
            out += serials[i];
        }
        if (static_cast<int>(out.size()) + 1 > bufLen)
            return -1;                          // buf qua nho
        std::memcpy(buf, out.c_str(), out.size() + 1);
    }

    return static_cast<int>(serials.size());
}

int Relay_On(const char* serial, int channel)
{
    int h = GetOrOpen(serial);
    if (h == 0) return 1;
    return Core_SetOne(h, channel, true) ? 0 : 1;
}

int Relay_Off(const char* serial, int channel)
{
    int h = GetOrOpen(serial);
    if (h == 0) return 1;
    return Core_SetOne(h, channel, false) ? 0 : 1;
}

int Relay_OnAll(const char* serial)
{
    int h = GetOrOpen(serial);
    if (h == 0) return 1;
    return Core_SetAll(h, true) ? 0 : 1;
}

int Relay_OffAll(const char* serial)
{
    int h = GetOrOpen(serial);
    if (h == 0) return 1;
    return Core_SetAll(h, false) ? 0 : 1;
}

int Relay_GetStatus(const char* serial, unsigned int* status)
{
    if (status == nullptr) return 1;
    int h = GetOrOpen(serial);
    if (h == 0) return 1;
    return Core_GetStatus(h, *status) ? 0 : 1;
}

void Relay_Shutdown(void)
{
    for (auto& kv : g_handles)
        Core_Close(kv.second);
    g_handles.clear();

    if (g_inited)
    {
        Core_Exit();
        g_inited = false;
    }
}

} // extern "C"
