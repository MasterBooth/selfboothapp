#include "RelayMgr.h"
//#include "stdafx.h"
#include "str_tools.h"
#include <msclr\marshal_cppstd.h>

using namespace RelayNS;

////////////////////////////////////////////////////////////////////////////////////////////////////

void RelayMgr::initial()
{
	//RelayWrapper::Create();
	usb_relay_init();
}

//////////////////////////////////////////////////////////////////////////////////////////////////////

Device^ RelayMgr::Gets()
{
	Device^ device = gcnew Device();
	std::vector<std::string> _devices = RelayWrapper::GetDeviceList();
	device->devices = gcnew cli::array<System::String^>(_devices.size());
	for (int i = 0; i < _devices.size(); i++)
	{
		device->devices[i] = gcnew System::String(_devices[i].c_str());
	}
	return device;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////

int RelayMgr::Connect(System::String^ serial)
{
	msclr::interop::marshal_context context;
	std::string str = context.marshal_as<std::string>(serial);
	std::wstring wserial = std::wstring(str.begin(), str.end());
	int connectedDevice = RelayWrapper::ConnectDevice(wserial);
	
	return connectedDevice;

	//usb_relay_device_info* device = new usb_relay_device_info();
	//device->serial_number = (unsigned char*)Ansi2WChar((char*)("HURTM")).c_str();
	//int curDevice = usb_relay_device_open_with_serial_number((const char*)device->serial_number, strlen((const char*)device->serial_number));
	//if (curDevice != NULL)
	//{
	//	return true;
	//}
	//return false;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////

void RelayMgr::Disconnect(int device)
{
	RelayWrapper::DisconnectDevice(device);
}

//////////////////////////////////////////////////////////////////////////////////////////////////////

bool RelayMgr::OpenAll(int device)
{
	return RelayWrapper::OpenAllRelay(device);
}

//////////////////////////////////////////////////////////////////////////////////////////////////////

bool RelayMgr::CloseAll(int device)
{
	return RelayWrapper::CloseAllRelay(device);
}

//////////////////////////////////////////////////////////////////////////////////////////////////////

bool RelayMgr::OpenOne(int device, int index)
{
	return RelayWrapper::OpenRelay(device, index);
}

//////////////////////////////////////////////////////////////////////////////////////////////////////

bool RelayMgr::CloseOne(int device, int index)
{
	return RelayWrapper::CloseRelay(device, index);
}