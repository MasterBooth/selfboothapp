#include <windows.h>
#include <iostream>
#include <thread>
#include <chrono>

int main() {
    std::cout << "Waiting for CameraAppGUI window..." << std::endl;
    HWND hwnd = NULL;
    for (int i = 0; i < 10; ++i) {
        hwnd = FindWindowA(NULL, "Canon Camera Control");
        if (hwnd) break;
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
    }

    if (!hwnd) {
        std::cerr << "Could not find window!" << std::endl;
        return 1;
    }

    std::cout << "Found window. Sending Connect (1001)..." << std::endl;
    SendMessage(hwnd, WM_COMMAND, MAKEWPARAM(1001, BN_CLICKED), 0);
    std::this_thread::sleep_for(std::chrono::seconds(2));

    std::cout << "Sending Start Live View (1005)..." << std::endl;
    SendMessage(hwnd, WM_COMMAND, MAKEWPARAM(1005, BN_CLICKED), 0);
    std::this_thread::sleep_for(std::chrono::seconds(4));

    std::cout << "Sending Take Picture (1003)..." << std::endl;
    SendMessage(hwnd, WM_COMMAND, MAKEWPARAM(1003, BN_CLICKED), 0);
    std::this_thread::sleep_for(std::chrono::seconds(4));

    std::cout << "Sending Disconnect (1002)..." << std::endl;
    SendMessage(hwnd, WM_COMMAND, MAKEWPARAM(1002, BN_CLICKED), 0);
    std::this_thread::sleep_for(std::chrono::seconds(1));

    std::cout << "Tests completed. Closing window..." << std::endl;
    SendMessage(hwnd, WM_CLOSE, 0, 0);

    return 0;
}
