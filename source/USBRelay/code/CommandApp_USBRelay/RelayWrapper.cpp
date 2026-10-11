#include "stdafx.h"
#include "RelayWrapper.h"
#include "str_tools.h"


////////////////////////////////////////////////////////////////////////////////////////////////////

bool RelayWrapper::Create()
{
	int ret = usb_relay_init();
	if (ret == 0)
	{
		return true;
	}
	return false;
}

////////////////////////////////////////////////////////////////////////////////////////////////////

std::vector<std::string> RelayWrapper::GetDeviceList()
{
	std::vector<std::string> devices;
	
	struct usb_relay_device_info* m_DeviceList = usb_relay_device_enumerate();

	if (m_DeviceList)
	{
		struct usb_relay_device_info *cur_device = m_DeviceList;
		
		while (cur_device)
		{
			devices.push_back((char*)cur_device->serial_number);
			//m_mapIndexToDevice[Ansi2WChar((char*)(cur_device->serial_number))] = cur_device;

			cur_device = cur_device->next;
		}
	}
	return devices; 
}

////////////////////////////////////////////////////////////////////////////////////////////////////

int RelayWrapper::ConnectDevice(std::wstring serial)
{
	struct usb_relay_device_info* m_DeviceList = usb_relay_device_enumerate();

	struct usb_relay_device_info* curDevice;
	while (m_DeviceList)
	{
		if (serial == Ansi2WChar((char*)(m_DeviceList->serial_number)))
		{
			curDevice = m_DeviceList;
			break;
		}
		m_DeviceList = m_DeviceList->next;
	}
	/*std::map<std::wstring, struct usb_relay_device_info*>::const_iterator fd = m_mapIndexToDevice.find(std::wstring(serial));
	if (fd != m_mapIndexToDevice.end())
	{*/
		//1. open usb relay device
		int m_hCurDevice = usb_relay_device_open(curDevice);
		if (m_hCurDevice)
		{
			return m_hCurDevice;
		}
		return -1;
	//}
	//return false;
}

////////////////////////////////////////////////////////////////////////////////////////////////////

void RelayWrapper::DisconnectDevice(int m_hCurDevice)
{
	usb_relay_device_close(m_hCurDevice);
	
}

////////////////////////////////////////////////////////////////////////////////////////////////////

int RelayWrapper::GetDeviceStatus(std::wstring serial)
{
	return 0;
}

////////////////////////////////////////////////////////////////////////////////////////////////////

bool RelayWrapper::OpenAllRelay(int m_hCurDevice)
{
	int ret = usb_relay_device_open_all_relay_channel(m_hCurDevice);
	if (ret == 0)
	{
		return true;
	}
	return false;
}

////////////////////////////////////////////////////////////////////////////////////////////////////

bool RelayWrapper::CloseAllRelay(int m_hCurDevice)
{
	int ret = usb_relay_device_close_all_relay_channel(m_hCurDevice);
	if (ret == 0)
	{
		return true;
	}
	return false;
}

////////////////////////////////////////////////////////////////////////////////////////////////////

bool RelayWrapper::OpenRelay(int device, int index)
{
	int ret = usb_relay_device_open_one_relay_channel(device, index);
	if (ret == 0)
	{
		return true;
	}
	return false;
}

////////////////////////////////////////////////////////////////////////////////////////////////////

bool RelayWrapper::CloseRelay(int device, int index)
{
	int ret = usb_relay_device_close_one_relay_channel(device, index);
	if (ret == 0)
	{
		return true;
	}
	return false;
}