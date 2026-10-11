// stdafx.h : 标准系统包含文件的包含文件，
// 或是经常使用但不常更改的
// 特定于项目的包含文件
//

#pragma once

#include "targetver.h"

#define WIN32_LEAN_AND_MEAN             // 从 Windows 头中排除极少使用的资料
// Windows 头文件:
#include <windows.h>

#include <stdlib.h>
#include <malloc.h>
#include <memory.h>
#include <tchar.h>



#ifdef _DEBUG
#pragma comment(lib, "../../lib/xcgui/XCGUId.lib")
#pragma comment(lib, "../../lib/usb_relay_dll/usb_relay_device.lib")
#else
#pragma comment(lib, "../../lib/xcgui/XCGUI.lib")
#pragma comment(lib, "../../lib/usb_relay_dll/usb_relay_device.lib")
#endif

#include "../../lib/xcgui/xcgui.h"
#include "../../lib/usb_relay_dll/usb_relay_device.h"

#include "str_tools.h"

#include <map>
using namespace std;