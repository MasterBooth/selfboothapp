#pragma once
#include "RelayWrapper.h"

namespace RelayNS
{
	public enum class Usb_relay_device_type
	{
		USB_RELAY_DEVICE_ONE_CHANNEL = 1,
		USB_RELAY_DEVICE_TWO_CHANNEL = 2,
		USB_RELAY_DEVICE_FOUR_CHANNEL = 4,
		USB_RELAY_DEVICE_EIGHT_CHANNEL = 8
	};

	public ref class Usb_relay_device_info
	{
		System::String^ serial_number;
		System::String^ device_path;
		Usb_relay_device_type type;
	};

	public ref class Device
	{
	public:
		cli::array<System::String^>^ devices;
	};

	public ref class RelayMgr
	{
		public:
			static void initial();
			static Device^ Gets();
			static int Connect(System::String^ serial);
			static void Disconnect(int device);
			static bool OpenAll(int device);
			static bool CloseAll(int device);
			static bool OpenOne(int device, int index);
			static bool CloseOne(int device, int index);
	};

}

