//================================================================================================
// SimpleTest.cpp
//
// App test toi gian dieu khien Nikon Z6 II qua SDK "Control Service Layer".
// Luong: nap DLL -> InitializeSDK -> ket noi may -> doc pin & che do phoi sang
//        -> chup 1 tam -> ngat ket noi.
//
// Build: x64. Exe duoc dat trong thu muc BinaryFile (canh ControlServiceLayer.dll + *.config).
// Tham khao: SampleApp\main.cpp, SampleApp\Function.cpp (cach nap/resolve export).
//================================================================================================

#include <windows.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>

#include "Maid3.h"
#include "Maid3d1.h"

#define LIBRARY "ControlServiceLayer.dll"

//------------------------------------------------------------------------------------------------
// Con tro toi cac ham export cua SDK (chi nhung gi can cho luong test toi gian)
//------------------------------------------------------------------------------------------------
static HINSTANCE                    g_hModule = NULL;
static LPMAIDSetLoggingLevel        g_SetLoggingLevel = NULL;
static LPMAIDInitializeSDKProc      g_InitializeSDK = NULL;
static LPMAIDFreeSDKProc            g_FreeSDK = NULL;
static LPMAIDConnectDeviceProc      g_ConnectDevice = NULL;
static LPMAIDDisconnectDeviceProc   g_DisconnectDevice = NULL;
static LPMAIDSetImageVideoSavePath  g_SetImageVideoSavePath = NULL;
static LPMAIDGetCapability          g_GetCapability = NULL;
static LPMAIDSetCapability          g_SetCapability = NULL;
static LPMAIDStartShooting          g_StartShooting = NULL;

static LPNkMAIDEnumDevices  g_pDeviceList = NULL;   // SDK se cap phat & dien danh sach thiet bi
static LPNkMAIDEnumCapInfo  g_pEnumCapInfo = NULL;  // Capabilities cua thiet bi sau khi ket noi

//------------------------------------------------------------------------------------------------
// Callbacks bat buoc cho CS Layer
//------------------------------------------------------------------------------------------------
static void* CALLPASCAL CALLBACK AllocateMemory(size_t len) { return malloc(len); }
static void  CALLPASCAL CALLBACK FreeMemory(void* pMem)     { free(pMem); }

static void CALLPASCAL CALLBACK SrcEventProc(NKREF /*refProc*/, ULONG ulEvent, NKPARAM /*data*/)
{
	printf("[Event] 0x%08X\n", (unsigned)ulEvent);
}

static ULONG CALLPASCAL CALLBACK UIRequestProc(NKREF /*ref*/, LPNkMAIDUIRequestInfo /*pUIRequest*/)
{
	return 0; // tra ve lua chon mac dinh
}

static void CALLPASCAL CALLBACK ProgressProc(ULONG, ULONG, NKREF, ULONG, ULONG) {}

static NKERROR CALLPASCAL CALLBACK DataProc(NKREF /*ref*/, LPVOID /*pInfo*/, LPVOID /*pData*/)
{
	return kNkMAIDResult_NoError;
}

static void CALLPASCAL CALLBACK LVDataProc(NKREF, LPNkMAIDLiveViewData) {}

//------------------------------------------------------------------------------------------------
// Giai phong buffer do SDK cap phat (qua AllocateMemory = malloc) tra ve tu GetCapability
//------------------------------------------------------------------------------------------------
static void FreeCapValue(void* data, eNkMAIDDataType type)
{
	if (!data) return;
	if (type == kNkMAIDDataType_EnumPtr)        free(((LPNkMAIDEnum)data)->pData);
	else if (type == kNkMAIDDataType_ArrayPtr)  free(((LPNkMAIDArray)data)->pData);
	free(data);
}

//------------------------------------------------------------------------------------------------
// Nap DLL va resolve cac ham export
//------------------------------------------------------------------------------------------------
static bool LoadSdk()
{
	g_hModule = LoadLibraryA(LIBRARY);
	if (!g_hModule)
	{
		printf("Khong nap duoc %s (loi %lu). Hay chac chan exe nam trong thu muc BinaryFile.\n",
			LIBRARY, GetLastError());
		return false;
	}

	g_SetLoggingLevel       = (LPMAIDSetLoggingLevel)      GetProcAddress(g_hModule, "SetLoggingLevel");
	g_InitializeSDK         = (LPMAIDInitializeSDKProc)    GetProcAddress(g_hModule, "InitializeSDK");
	g_FreeSDK               = (LPMAIDFreeSDKProc)          GetProcAddress(g_hModule, "FreeSDK");
	g_ConnectDevice         = (LPMAIDConnectDeviceProc)    GetProcAddress(g_hModule, "ConnectDevice");
	g_DisconnectDevice      = (LPMAIDDisconnectDeviceProc) GetProcAddress(g_hModule, "DisconnectDevice");
	g_SetImageVideoSavePath = (LPMAIDSetImageVideoSavePath)GetProcAddress(g_hModule, "SetImageVideoSavePath");
	g_GetCapability         = (LPMAIDGetCapability)        GetProcAddress(g_hModule, "GetCapability");
	g_SetCapability         = (LPMAIDSetCapability)        GetProcAddress(g_hModule, "SetCapability");
	g_StartShooting         = (LPMAIDStartShooting)        GetProcAddress(g_hModule, "StartShooting");

	if (!g_InitializeSDK || !g_FreeSDK || !g_ConnectDevice || !g_DisconnectDevice ||
		!g_SetImageVideoSavePath || !g_GetCapability || !g_SetCapability || !g_StartShooting)
	{
		printf("Khong resolve duoc mot/nhieu ham export cua SDK.\n");
		return false;
	}
	return true;
}

//------------------------------------------------------------------------------------------------
// Doc & in mot capability kieu Integer (vd: BatteryLevel)
//------------------------------------------------------------------------------------------------
static void PrintIntegerCap(const char* name, ULONG ulCapID)
{
	LPVOID pVal = NULL;
	eNkMAIDDataType type = kNkMAIDDataType_Null;
	NKERROR err = g_GetCapability(ulCapID, kNkSDKGetSettingValue, pVal, type);
	if (err == kNkMAIDResult_NoError && pVal && type == kNkMAIDDataType_IntegerPtr)
		printf("%s = %d\n", name, *((SLONG*)pVal));
	else
		printf("%s : khong doc duoc (err=%d, type=%d)\n", name, (int)err, (int)type);
	FreeCapValue(pVal, type);
}

//------------------------------------------------------------------------------------------------
// Doc & in mot capability kieu Enum (vd: ExposureMode) - in chi so hien tai
//------------------------------------------------------------------------------------------------
static void PrintEnumCap(const char* name, ULONG ulCapID)
{
	LPVOID pVal = NULL;
	eNkMAIDDataType type = kNkMAIDDataType_Null;
	NKERROR err = g_GetCapability(ulCapID, kNkSDKGetSettingValue, pVal, type);
	if (err == kNkMAIDResult_NoError && pVal && type == kNkMAIDDataType_EnumPtr)
	{
		LPNkMAIDEnum e = (LPNkMAIDEnum)pVal;
		printf("%s = index %u / %u phan tu\n", name, e->ulValue, e->ulElements);
	}
	else
		printf("%s : khong doc duoc (err=%d, type=%d)\n", name, (int)err, (int)type);
	FreeCapValue(pVal, type);
}

//------------------------------------------------------------------------------------------------
// Doc & in mot capability kieu Unsigned (vd: SaveMedia). Tra ve gia tri qua *pOut (neu thanh cong)
//------------------------------------------------------------------------------------------------
static bool ReadUnsignedCap(const char* name, ULONG ulCapID, ULONG* pOut)
{
	LPVOID pVal = NULL;
	eNkMAIDDataType type = kNkMAIDDataType_Null;
	NKERROR err = g_GetCapability(ulCapID, kNkSDKGetSettingValue, pVal, type);
	bool ok = (err == kNkMAIDResult_NoError && pVal && type == kNkMAIDDataType_UnsignedPtr);
	if (ok)
	{
		if (pOut) *pOut = *((ULONG*)pVal);
		printf("%s = %u\n", name, *((ULONG*)pVal));
	}
	else
		printf("%s : khong doc duoc (err=%d, type=%d)\n", name, (int)err, (int)type);
	FreeCapValue(pVal, type);
	return ok;
}

//------------------------------------------------------------------------------------------------
// Dien giai mot so ma loi thuong gap cua StartShooting
//------------------------------------------------------------------------------------------------
static const char* ShootErrName(NKERROR err)
{
	switch ((int)err)
	{
	case kNkMAIDResult_NoError:            return "NoError";
	case kNkMAIDResult_NotSupported:       return "NotSupported (-127): thao tac chup khong duoc phep o trang thai hien tai";
	case kNkMAIDResult_Waiting_2ndRelease: return "Waiting_2ndRelease (168)";
	case kNkMAIDResult_CaptureFailure:     return "CaptureFailure (148)";
	case kNkMAIDResult_CaptureDisable:     return "CaptureDisable (151)";
	case kNkMAIDAPIResult_InvalidShootingMode: return "InvalidShootingMode (-100): che do chup (release/drive) cua may khong hop le voi lenh";
	default:                               return "loi khac";
	}
}

//------------------------------------------------------------------------------------------------
// Dam bao che do chup (drive/release mode) cua may = Single (S) de StartShooting(Single) hop le.
// ShootingMode la enum: ulValue = chi so hien tai trong mang pData[], pData[i] = ma che do.
//------------------------------------------------------------------------------------------------
static void EnsureSingleShootingMode()
{
	// 1) Lay MANG cac che do duoc ho tro. pData chi co o che do GetSettingSupportedValueArray;
	//    voi GetSettingValue thi pData = NULL va chi co ulValue (chi so hien tai).
	LPVOID pArr = NULL;
	eNkMAIDDataType at = kNkMAIDDataType_Null;
	NKERROR ea = g_GetCapability(kNkMAIDCapability_ShootingMode, kNkSDKGetSettingSupportedValueArray, pArr, at);
	if (ea != kNkMAIDResult_NoError || !pArr || at != kNkMAIDDataType_EnumPtr)
	{
		printf("ShootingMode (mang) khong doc duoc (err=%d, type=%d)\n", (int)ea, (int)at);
		FreeCapValue(pArr, at);
		return;
	}
	LPNkMAIDEnum arr = (LPNkMAIDEnum)pArr;
	ULONG* codes = (ULONG*)arr->pData;
	ULONG n = arr->ulElements;

	ULONG singleIdx = 0xFFFFFFFF;
	printf("ShootingMode ho tro (%u): ", n);
	for (ULONG i = 0; codes && i < n; ++i)
	{
		printf("[%u]=%u ", i, codes[i]);
		if (codes[i] == (ULONG)eNkMAIDShootingMode_S) singleIdx = i;
	}
	printf("\n");

	// 2) Lay gia tri hien tai (ulValue = chi so trong mang tren)
	LPVOID pCur = NULL;
	eNkMAIDDataType ct = kNkMAIDDataType_Null;
	ULONG curIdx = 0xFFFFFFFF, curCode = 0xFFFFFFFF;
	NKERROR ec = g_GetCapability(kNkMAIDCapability_ShootingMode, kNkSDKGetSettingValue, pCur, ct);
	if (ec == kNkMAIDResult_NoError && pCur && ct == kNkMAIDDataType_EnumPtr)
	{
		curIdx = ((LPNkMAIDEnum)pCur)->ulValue;
		if (codes && curIdx < n) curCode = codes[curIdx];
	}
	printf("ShootingMode hien tai: index %u -> code %u\n", curIdx, curCode);

	if (curCode == (ULONG)eNkMAIDShootingMode_S)
		printf("ShootingMode da la Single.\n");
	else if (singleIdx == 0xFFFFFFFF)
		printf("Khong tim thay che do Single trong danh sach ho tro.\n");
	else
	{
		// Set: dung mang lam template, chi doi ulValue = index Single, pData = NULL
		NkMAIDEnum set = *arr;
		set.ulValue = singleIdx;
		set.pData = NULL;
		NKERROR se = g_SetCapability(kNkMAIDCapability_ShootingMode, &set, kNkMAIDDataType_EnumPtr);
		printf("Dat ShootingMode=Single (index %u): %s (err=%d)\n",
			singleIdx, se == kNkMAIDResult_NoError ? "OK" : "that bai", (int)se);
	}

	FreeCapValue(pCur, ct);
	FreeCapValue(pArr, at);
}

//------------------------------------------------------------------------------------------------
int main()
{
	printf("=== Nikon Z6 II - Simple Control Test ===\n");

	if (!LoadSdk())
		return -1;

	if (g_SetLoggingLevel)
		g_SetLoggingLevel(kkNkSDKLogLevel_Error);

	// 1) Dang ky callback va khoi tao SDK
	NkMAIDCSCallback callback;
	memset(&callback, 0, sizeof(callback));
	callback.pUIReqProc        = (LPNKFUNC)UIRequestProc;
	callback.pfnEventProc      = (LPNKFUNC)SrcEventProc;
	callback.pProgressProc     = (LPNKFUNC)ProgressProc;
	callback.pDataProc         = (LPNKFUNC)DataProc;
	callback.pLiveViewDataProc = (LPNKFUNC)LVDataProc;
	callback.refProc           = NULL;

	NKERROR err = g_InitializeSDK((LPMAIDAllocateMemory)AllocateMemory,
		(LPMAIDFreeMemory)FreeMemory, &callback, &g_pDeviceList, NULL);
	if (err != kNkMAIDResult_NoError)
	{
		printf("InitializeSDK that bai (err=%d)\n", (int)err);
		FreeLibrary(g_hModule);
		return -1;
	}
	printf("SDK da khoi tao. Dang cho phat hien may anh...\n");

	// 2) Cho thiet bi xuat hien & san sang (toi da ~10s)
	int chosenIndex = -1;
	for (int tries = 0; tries < 50 && chosenIndex < 0; ++tries)
	{
		if (g_pDeviceList && g_pDeviceList->ulElements > 0 && g_pDeviceList->pDeviceData)
		{
			for (ULONG i = 0; i < g_pDeviceList->ulElements; ++i)
			{
				if (g_pDeviceList->pDeviceData[i].Availability)
				{
					chosenIndex = (int)i;
					break;
				}
			}
		}
		if (chosenIndex < 0)
			Sleep(200);
	}

	if (chosenIndex < 0)
	{
		printf("Khong tim thay may anh kha dung. Kiem tra USB / che do ket noi PC (MTP).\n");
		g_FreeSDK();
		FreeLibrary(g_hModule);
		return -1;
	}

	NkMAIDDeviceInfo dev = g_pDeviceList->pDeviceData[chosenIndex];
	printf("Tim thay thiet bi: \"%s\" (ID=%u)\n", dev.Name, dev.ID);

	// 3) Ket noi
	err = g_ConnectDevice(dev.ID, &g_pEnumCapInfo);
	if (err != kNkMAIDResult_NoError)
	{
		printf("ConnectDevice that bai (err=%d)\n", (int)err);
		g_FreeSDK();
		FreeLibrary(g_hModule);
		return -1;
	}
	printf("Da ket noi may anh.\n");

	// 4) Doc thong tin co ban (chung minh duong dieu khien hoat dong)
	PrintIntegerCap("BatteryLevel", kNkMAIDCapability_BatteryLevel);
	PrintEnumCap("ExposureMode", kNkMAIDCapability_ExposureMode);

	// 5) Dam bao luu anh vao THE NHO (don gian & on dinh nhat).
	//    SaveMedia: 0=Card, 1=SDRAM, 2=Card+SDRAM. Dat ve Card.
	ULONG saveMedia = 0;
	if (ReadUnsignedCap("SaveMedia", kNkMAIDCapability_SaveMedia, &saveMedia) &&
		saveMedia != (ULONG)kNkMAIDSaveMedia_Card)
	{
		ULONG card = (ULONG)kNkMAIDSaveMedia_Card;
		NKERROR se = g_SetCapability(kNkMAIDCapability_SaveMedia, &card, kNkMAIDDataType_UnsignedPtr);
		printf("Dat SaveMedia=Card: %s\n", se == kNkMAIDResult_NoError ? "OK" : "that bai");
	}
	// Khong dat duong dan PC -> SDK luu thang vao the (giong sample plain Capture).
	g_SetImageVideoSavePath(L"", L"");

	// 5b) Dam bao drive/release mode = Single de StartShooting(Single) hop le.
	EnsureSingleShootingMode();

	// 6) Chup 1 tam (dong bo), luu vao the. Tat AutoFocus de tranh phu thuoc lay net.
	MAIDShootingStructure shoot;
	memset(&shoot, 0, sizeof(shoot));
	shoot.ShootingType = kNkSDKShootingTypeSingle;
	shoot.bAutoFocus = false;
	shoot.ImageSavePath[0] = L'\0';

	printf("Dang chup 1 tam (luu vao the nho)...\n");
	err = g_StartShooting(shoot, NULL, NULL);
	if (err == kNkMAIDResult_NoError)
		printf("Capture OK.\n");
	else
	{
		printf("Capture that bai: %s (err=%d)\n", ShootErrName(err), (int)err);
		if (err == kNkMAIDResult_NotSupported)
			printf("  Goi y: gat cong tac Photo/Movie cua Z6 II sang PHOTO (anh tinh);\n"
			       "  kiem tra co the nho trong may; thu xoay che do M/A/S/P.\n");
	}

	// 7) Don dep
	g_DisconnectDevice();
	g_FreeSDK();
	FreeLibrary(g_hModule);
	g_hModule = NULL;

	printf("Hoan tat.\n");
	return 0;
}
