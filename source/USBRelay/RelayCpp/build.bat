@echo off
REM ============================================================
REM  Build RelayControl.exe + RelayPlugin.dll  (BAT BUOC x86 / 32-bit)
REM  DLL hang usb_relay_device.dll la 32-bit -> phai build x86.
REM ============================================================
setlocal

REM --- Thiet lap moi truong MSVC x86 (Visual Studio 18 Community) ---
set "VCVARS=C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars32.bat"
if not exist "%VCVARS%" (
    echo [LOI] Khong tim thay vcvars32.bat tai:
    echo       %VCVARS%
    echo       Hay sua duong dan trong build.bat cho dung phien ban VS.
    exit /b 1
)
call "%VCVARS%"

REM --- Duong dan ---
set "ROOT=%~dp0"
set "LIBDIR=%ROOT%..\lib\usb_relay_dll"
set "OUT=%ROOT%build"
if not exist "%OUT%" mkdir "%OUT%"

cd /d "%ROOT%"

echo.
echo === Build RelayControl.exe ===
cl /nologo /EHsc /O2 /I "%LIBDIR%" ^
   RelayControl.cpp RelayCore.cpp ^
   "%LIBDIR%\usb_relay_device.lib" ^
   /Fe:"%OUT%\RelayControl.exe" /Fo:"%OUT%\\"
if errorlevel 1 ( echo [LOI] Build EXE that bai. & exit /b 1 )

echo.
echo === Build RelayGui.exe (UI Win32) ===
cl /nologo /EHsc /O2 /I "%LIBDIR%" ^
   RelayGui.cpp RelayCore.cpp ^
   "%LIBDIR%\usb_relay_device.lib" user32.lib gdi32.lib ^
   /Fe:"%OUT%\RelayGui.exe" /Fo:"%OUT%\\" ^
   /link /SUBSYSTEM:WINDOWS
if errorlevel 1 ( echo [LOI] Build GUI that bai. & exit /b 1 )

echo.
echo === Build RelayCli.exe (helper cho app Qt 64-bit goi qua QProcess) ===
cl /nologo /EHsc /O2 /I "%LIBDIR%" ^
   RelayCli.cpp RelayCore.cpp ^
   "%LIBDIR%\usb_relay_device.lib" ^
   /Fe:"%OUT%\RelayCli.exe" /Fo:"%OUT%\\"
if errorlevel 1 ( echo [LOI] Build RelayCli that bai. & exit /b 1 )

echo.
echo === Build RelayPlugin.dll ===
cl /nologo /EHsc /O2 /LD /I "%LIBDIR%" ^
   RelayPlugin.cpp RelayCore.cpp ^
   "%LIBDIR%\usb_relay_device.lib" ^
   /Fe:"%OUT%\RelayPlugin.dll" /Fo:"%OUT%\\" ^
   /link /DEF:RelayPlugin.def
if errorlevel 1 ( echo [LOI] Build DLL that bai. & exit /b 1 )

REM --- Copy DLL hang ben canh output de chay duoc ---
copy /Y "%LIBDIR%\usb_relay_device.dll" "%OUT%\" >nul

echo.
echo === HOAN TAT ===
echo Output: %OUT%
echo   - RelayGui.exe      (UI do hoa)
echo   - RelayControl.exe  (console)
echo   - RelayCli.exe      (helper cho app Qt)
echo   - RelayPlugin.dll   (+ RelayPlugin.lib de link-time, RelayPlugin.exp)
echo   - usb_relay_device.dll
endlocal
