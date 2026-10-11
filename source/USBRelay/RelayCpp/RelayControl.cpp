// RelayControl.cpp
// App EXE menu tuong tac dieu khien USB Relay (C++ thuan).
// Build: xem build.bat (bat buoc x86 vi DLL hang la 32-bit).
#include "RelayCore.h"

#include <iostream>
#include <string>
#include <vector>
#include <limits>

using namespace RelayCore;

// Doc 1 so nguyen tu ban phim, cho phep nhap lai khi sai.
static int ReadInt(const std::string& prompt)
{
    while (true)
    {
        std::cout << prompt;
        int value;
        if (std::cin >> value)
        {
            std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
            return value;
        }
        std::cin.clear();
        std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
        std::cout << "  -> Gia tri khong hop le, nhap lai.\n";
    }
}

static void PrintStatus(int handle)
{
    unsigned int status = 0;
    if (!Core_GetStatus(handle, status))
    {
        std::cout << "  -> Khong doc duoc trang thai.\n";
        return;
    }

    std::cout << "  Trang thai cac kenh (1 = BAT, 0 = TAT):\n  ";
    for (int ch = 1; ch <= 8; ++ch)
    {
        int bit = (status >> (ch - 1)) & 0x1;
        std::cout << "[K" << ch << "=" << bit << "] ";
    }
    std::cout << "\n";
}

int main()
{
    std::cout << "==== USB Relay Control (C++) ====\n";

    if (!Core_Init())
    {
        std::cout << "Loi: khong khoi tao duoc thu vien USB Relay.\n";
        return 1;
    }

    int handle = 0;                 // 0 = chua ket noi
    std::string connectedSerial;

    bool running = true;
    while (running)
    {
        std::cout << "\n-----------------------------------------\n";
        std::cout << "Thiet bi dang ket noi: "
                  << (handle != 0 ? connectedSerial : std::string("(chua ket noi)")) << "\n";
        std::cout << "1. Liet ke & ket noi thiet bi\n";
        std::cout << "2. Bat 1 kenh\n";
        std::cout << "3. Tat 1 kenh\n";
        std::cout << "4. Bat tat ca\n";
        std::cout << "5. Tat tat ca\n";
        std::cout << "6. Xem trang thai\n";
        std::cout << "7. Ngat ket noi\n";
        std::cout << "0. Thoat\n";

        int choice = ReadInt("Chon: ");

        switch (choice)
        {
        case 1:
        {
            std::vector<std::string> serials = Core_ListSerials();
            if (serials.empty())
            {
                std::cout << "  Khong tim thay thiet bi nao. Kiem tra cap USB.\n";
                break;
            }
            std::cout << "  Danh sach thiet bi:\n";
            for (size_t i = 0; i < serials.size(); ++i)
                std::cout << "    " << (i + 1) << ". " << serials[i] << "\n";

            int sel = ReadInt("  Chon thiet bi de ket noi (so): ");
            if (sel < 1 || sel > static_cast<int>(serials.size()))
            {
                std::cout << "  -> Lua chon khong hop le.\n";
                break;
            }

            if (handle != 0)        // dong ket noi cu truoc
                Core_Close(handle);

            handle = Core_Open(serials[sel - 1]);
            if (handle == 0)
            {
                std::cout << "  -> Khong mo duoc thiet bi.\n";
                connectedSerial.clear();
            }
            else
            {
                connectedSerial = serials[sel - 1];
                std::cout << "  -> Da ket noi: " << connectedSerial << "\n";
            }
            break;
        }
        case 2:
        case 3:
        {
            if (handle == 0) { std::cout << "  -> Hay ket noi thiet bi truoc.\n"; break; }
            int ch = ReadInt("  Nhap so kenh (1..8): ");
            bool on = (choice == 2);
            if (Core_SetOne(handle, ch, on))
                std::cout << "  -> Da " << (on ? "BAT" : "TAT") << " kenh " << ch << ".\n";
            else
                std::cout << "  -> Thao tac that bai (kiem tra so kenh).\n";
            break;
        }
        case 4:
        case 5:
        {
            if (handle == 0) { std::cout << "  -> Hay ket noi thiet bi truoc.\n"; break; }
            bool on = (choice == 4);
            if (Core_SetAll(handle, on))
                std::cout << "  -> Da " << (on ? "BAT" : "TAT") << " tat ca cac kenh.\n";
            else
                std::cout << "  -> Thao tac that bai.\n";
            break;
        }
        case 6:
            if (handle == 0) { std::cout << "  -> Hay ket noi thiet bi truoc.\n"; break; }
            PrintStatus(handle);
            break;
        case 7:
            if (handle == 0) { std::cout << "  -> Chua ket noi thiet bi nao.\n"; break; }
            Core_Close(handle);
            handle = 0;
            connectedSerial.clear();
            std::cout << "  -> Da ngat ket noi.\n";
            break;
        case 0:
            running = false;
            break;
        default:
            std::cout << "  -> Lua chon khong hop le.\n";
            break;
        }
    }

    if (handle != 0)
        Core_Close(handle);
    Core_Exit();

    std::cout << "Tam biet.\n";
    return 0;
}
