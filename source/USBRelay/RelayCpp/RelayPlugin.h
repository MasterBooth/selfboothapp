// RelayPlugin.h
// API plugin cap cao (C ABI) de gan vao phan mem khac.
// Plugin tu lo init + cache serial->handle: ben tich hop chi can goi 1 ham.
// Quy uoc tra ve: 0 = OK, khac 0 = loi.
#ifndef RELAY_PLUGIN_H__
#define RELAY_PLUGIN_H__

#ifdef _WIN32
  #ifdef RELAY_PLUGIN_EXPORTS
    #define RELAY_API __declspec(dllexport)
  #else
    #define RELAY_API __declspec(dllimport)
  #endif
#else
  #define RELAY_API
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Khoi tao plugin. Goi 1 lan truoc khi dung (idempotent). 0 = OK.
RELAY_API int Relay_Init(void);

// Liet ke thiet bi: ghi cac serial (phan tach bang '\n') vao buf,
// tra ve so thiet bi tim thay, hoac -1 neu loi/ buf qua nho.
RELAY_API int Relay_ListDevices(char* buf, int bufLen);

// Bat / tat 1 kenh (channel: 1..N) cua thiet bi theo serial. Tu connect neu can.
RELAY_API int Relay_On(const char* serial, int channel);
RELAY_API int Relay_Off(const char* serial, int channel);

// Bat / tat tat ca cac kenh.
RELAY_API int Relay_OnAll(const char* serial);
RELAY_API int Relay_OffAll(const char* serial);

// Doc trang thai (bitmask theo kenh) vao *status. 0 = OK.
RELAY_API int Relay_GetStatus(const char* serial, unsigned int* status);

// Dong moi handle dang mo + giai phong thu vien.
RELAY_API void Relay_Shutdown(void);

#ifdef __cplusplus
}
#endif

#endif // RELAY_PLUGIN_H__
