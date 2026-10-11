// RelayCli.cpp
// Helper 32-bit khong tuong tac, danh cho app 64-bit goi qua QProcess.
// (App Qt 64-bit khong nap duoc DLL relay 32-bit -> chay tien trinh phu nay.)
//
// Lenh:
//   RelayCli.exe list
//       -> in moi dong: "<serial>\t<soKenh>"  (vd: "ABCDE\t2")
//   RelayCli.exe set <serial> on|off <csvKenh>
//       -> bat/tat cac kenh (vd "1,2") tren thiet bi <serial>
//
// Ma thoat: 0 = thanh cong, khac 0 = loi.
#include "RelayCore.h"

#include <string>
#include <vector>
#include <sstream>
#include <cstdio>
#include <cstdlib>

using namespace RelayCore;

static std::vector<int> ParseChannels(const std::string& csv)
{
    std::vector<int> out;
    std::stringstream ss(csv);
    std::string tok;
    while (std::getline(ss, tok, ','))
    {
        if (!tok.empty())
        {
            int v = std::atoi(tok.c_str());
            if (v > 0)
                out.push_back(v);
        }
    }
    return out;
}

int main(int argc, char** argv)
{
    if (argc < 2)
        return 2;   // thieu lenh

    std::string cmd = argv[1];

    if (!Core_Init())
        return 1;   // khong khoi tao duoc thu vien

    int rc = 0;

    if (cmd == "list")
    {
        std::vector<DeviceInfo> devices = Core_ListDevices();
        for (const auto& d : devices)
            std::printf("%s\t%d\n", d.serial.c_str(), d.channels);
    }
    else if (cmd == "set" && argc >= 5)
    {
        std::string serial = argv[2];
        std::string state  = argv[3];
        bool on = (state == "on" || state == "1");
        std::vector<int> channels = ParseChannels(argv[4]);

        int handle = Core_Open(serial);
        if (handle == 0)
        {
            rc = 1;   // khong mo duoc thiet bi
        }
        else
        {
            for (int ch : channels)
            {
                if (!Core_SetOne(handle, ch, on))
                    rc = 1;   // co kenh that bai
            }
            Core_Close(handle);
        }
    }
    else
    {
        rc = 2;   // lenh khong hop le
    }

    Core_Exit();
    return rc;
}
