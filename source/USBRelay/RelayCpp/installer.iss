; installer.iss
; Script Inno Setup 6 dong goi app USB Relay thanh bo cai (setup .exe).
; Build truoc bang build.bat (tao ra thu muc build\), roi bien dich file nay bang ISCC.exe.
;   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer.iss

#define MyAppName "USB Relay Control"
#define MyAppVersion "1.0"
#define MyAppPublisher "Tiva Solutions"
#define MyAppExe "RelayGui.exe"

[Setup]
AppId={{B7E4C2A1-3F5D-4E8B-9C12-7A6F0D5E1234}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\USB Relay Control
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=dist
OutputBaseFilename=USBRelayControl_Setup_{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
; App 32-bit: KHONG bat che do 64-bit (de tuong thich DLL hang 32-bit)

[Languages]
Name: "vietnamese"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Tao shortcut ngoai man hinh Desktop"; GroupDescription: "Tuy chon:"

[Files]
Source: "build\RelayGui.exe";          DestDir: "{app}"; Flags: ignoreversion
Source: "build\RelayControl.exe";      DestDir: "{app}"; Flags: ignoreversion
Source: "build\RelayPlugin.dll";       DestDir: "{app}"; Flags: ignoreversion
Source: "build\usb_relay_device.dll";  DestDir: "{app}"; Flags: ignoreversion
; Header + lib cho ben tich hop plugin (tuy chon, de tham khao)
Source: "build\RelayPlugin.lib";       DestDir: "{app}\sdk"; Flags: ignoreversion skipifsourcedoesntexist
Source: "RelayPlugin.h";               DestDir: "{app}\sdk"; Flags: ignoreversion skipifsourcedoesntexist

[Icons]
Name: "{group}\{#MyAppName}";            Filename: "{app}\{#MyAppExe}"
Name: "{group}\Go cai dat {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}";      Filename: "{app}\{#MyAppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExe}"; Description: "Chay {#MyAppName} ngay"; Flags: nowait postinstall skipifsilent
