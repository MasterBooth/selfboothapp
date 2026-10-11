#pragma once
#include <map>
#include <string>
#include <vector>
#include "stdafx.h"

class RelayWrapper
{
public:
	static struct usb_relay_device_info* m_pDeviceList;

	static std::map<std::wstring, struct usb_relay_device_info*> m_mapIndexToDevice;

	static bool Create();

	static std::vector<std::string> GetDeviceList();
	static int ConnectDevice(std::wstring serial);
	static void DisconnectDevice(int m_hCurDevice);
	static int GetDeviceStatus(std::wstring serial);
	static bool OpenAllRelay(int m_hCurDevice);
	static bool CloseAllRelay(int m_hCurDevice);
	static bool OpenRelay(int device, int index);
	static bool CloseRelay(int device, int index);
};

