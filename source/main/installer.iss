; BOOTHME setup script
; Inno Setup 6.x
;
; Build app first:
;   cmake --build build_studio --config Release --target BOOTHME
;
; Build installer:
;   iscc installer.iss

#define AppName      "BOOTHME"
#define AppVersion   "2.0.0"
#define AppPublisher "Tivasolutions"
#define AppExe       "BOOTHME.exe"
#define BuildDir     "build_studio\bin\Release"
#define BuildPath    AddBackslash(SourcePath) + BuildDir
#define AssetsDir    "installer_assets"

; ---------------------------------------------------------------------------
; Build-time dependency guard
; ---------------------------------------------------------------------------
; The installer packages the complete CMake/windeployqt Release deploy folder.
; These checks fail early when a clean-machine dependency is missing.

#if !FileExists(BuildPath + "\" + AppExe)
  #error Build output is missing BOOTHME.exe. Build Release before running iscc.
#endif

; Core Qt runtime
#if !FileExists(BuildPath + "\Qt6Core.dll")
  #error Qt6Core.dll is missing. Run the CMake Release build so windeployqt deploys dependencies.
#endif
#if !FileExists(BuildPath + "\Qt6Gui.dll")
  #error Qt6Gui.dll is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\Qt6Network.dll")
  #error Qt6Network.dll is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\Qt6Qml.dll")
  #error Qt6Qml.dll is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\Qt6Quick.dll")
  #error Qt6Quick.dll is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\Qt6QuickControls2.dll")
  #error Qt6QuickControls2.dll is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\Qt6Sql.dll")
  #error Qt6Sql.dll is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\Qt6Widgets.dll")
  #error Qt6Widgets.dll is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\Qt6Multimedia.dll")
  #error Qt6Multimedia.dll is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\Qt6VirtualKeyboard.dll")
  #error Qt6VirtualKeyboard.dll is missing from the deploy folder.
#endif

; Qt plugins and QML modules
#if !FileExists(BuildPath + "\platforms\qwindows.dll")
  #error Qt platform plugin platforms\qwindows.dll is missing.
#endif
#if !FileExists(BuildPath + "\sqldrivers\qsqlite.dll")
  #error Qt SQLite driver sqldrivers\qsqlite.dll is missing.
#endif
#if !FileExists(BuildPath + "\imageformats\qjpeg.dll")
  #error Qt image plugin imageformats\qjpeg.dll is missing.
#endif
#if !FileExists(BuildPath + "\tls\qschannelbackend.dll")
  #error Qt TLS backend tls\qschannelbackend.dll is missing. HTTPS will fail on clean machines.
#endif
#if !FileExists(BuildPath + "\platforminputcontexts\qtvirtualkeyboardplugin.dll")
  #error Qt virtual keyboard input context plugin is missing.
#endif
#if !DirExists(BuildPath + "\qml\QtQuick")
  #error QtQuick QML runtime is missing. Run windeployqt with --qmldir.
#endif
#if !DirExists(BuildPath + "\qml\QtQuick\Controls")
  #error Qt Quick Controls QML runtime is missing. Run windeployqt with --qmldir.
#endif
#if !DirExists(BuildPath + "\qml\QtQuick\VirtualKeyboard")
  #error Qt VirtualKeyboard QML runtime is missing. Run windeployqt with --qmldir.
#endif
#if !DirExists(BuildPath + "\multimedia")
  #error Qt multimedia plugins folder is missing.
#endif

; Camera SDK/runtime dependencies
#if !FileExists(BuildPath + "\EDSDK.dll")
  #error Canon EDSDK.dll is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\EdsImage.dll")
  #error Canon EdsImage.dll is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\Cr_Core.dll")
  #error Sony Cr_Core.dll is missing from the deploy folder.
#endif
#if !DirExists(BuildPath + "\CrAdapter")
  #error Sony CrAdapter folder is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\ControlServiceLayer.dll")
  #error Nikon ControlServiceLayer.dll is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\MaidLayer.config")
  #error Nikon MaidLayer.config is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\DC_PTP_Config.config")
  #error Nikon DC_PTP_Config.config is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\XAPI.dll")
  #error Fuji XAPI.dll is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\FTLPTP.dll")
  #error Fuji FTLPTP.dll is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\FTLPTPIP.dll")
  #error Fuji FTLPTPIP.dll is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\XSDK.DAT")
  #error Fuji XSDK.DAT is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\FF0000API.dll")
  #error Fuji FF0000API.dll is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\FF0020API.dll")
  #error Fuji FF0020API.dll is missing from the deploy folder. The Fuji FF API set is incomplete.
#endif

; Media, computer vision, and hardware helpers
#if !FileExists(BuildPath + "\ffmpeg.exe")
  #error ffmpeg.exe is missing from the deploy folder. Video creation will fail.
#endif
#if !FileExists(BuildPath + "\avcodec-61.dll")
  #error FFmpeg runtime avcodec-61.dll is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\avformat-61.dll")
  #error FFmpeg runtime avformat-61.dll is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\avutil-59.dll")
  #error FFmpeg runtime avutil-59.dll is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\swresample-5.dll")
  #error FFmpeg runtime swresample-5.dll is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\swscale-8.dll")
  #error FFmpeg runtime swscale-8.dll is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\opencv_world4140.dll")
  #error OpenCV runtime opencv_world4140.dll is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\opengl32sw.dll")
  #error Qt software OpenGL runtime opengl32sw.dll is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\d3dcompiler_47.dll")
  #error Direct3D compiler runtime d3dcompiler_47.dll is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\dxcompiler.dll")
  #error DirectX shader compiler dxcompiler.dll is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\dxil.dll")
  #error DirectX shader compiler dxil.dll is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\CyStat64.dll")
  #error CyStat64.dll is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\relay\RelayCli.exe")
  #error USB relay helper relay\RelayCli.exe is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\relay\usb_relay_device.dll")
  #error USB relay runtime relay\usb_relay_device.dll is missing from the deploy folder.
#endif
#if !DirExists(BuildPath + "\tools\fuji_hotfolder")
  #error Fuji HotFolder tools folder is missing from the deploy folder.
#endif

; Installer assets
#if !FileExists(AddBackslash(SourcePath) + AssetsDir + "\app_icon.ico")
  #error installer_assets\app_icon.ico is missing.
#endif
#if !FileExists(AddBackslash(SourcePath) + AssetsDir + "\installer_small.bmp")
  #error installer_assets\installer_small.bmp is missing.
#endif
#if !FileExists(AddBackslash(SourcePath) + AssetsDir + "\installer_logo.bmp")
  #error installer_assets\installer_logo.bmp is missing.
#endif
#if !FileExists(AddBackslash(SourcePath) + AssetsDir + "\vcredist_x64.exe")
  #error installer_assets\vcredist_x64.exe is missing. Clean Windows installs may fail without the VC++ runtime.
#endif

[Setup]
AppId={{A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}

DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes

OutputDir=installer-output
OutputBaseFilename={#AppName}-Setup-{#AppVersion}
SetupIconFile={#AssetsDir}\app_icon.ico
WizardSmallImageFile={#AssetsDir}\installer_small.bmp
WizardImageFile={#AssetsDir}\installer_logo.bmp

Compression=lzma2/max
SolidCompression=no
LZMANumBlockThreads=2

WizardStyle=modern
DisableWelcomePage=no

PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

CloseApplications=yes
RestartApplications=no
UninstallDisplayIcon={app}\app_icon.ico

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[InstallDelete]
; Remove stale runtime from earlier installer layouts before copying the current
; deploy folder. User data directories are not removed.
Type: files;          Name: "{app}\avcodec-60.dll"
Type: files;          Name: "{app}\avcodec-61.dll"
Type: files;          Name: "{app}\avformat-60.dll"
Type: files;          Name: "{app}\avformat-61.dll"
Type: files;          Name: "{app}\avutil-58.dll"
Type: files;          Name: "{app}\avutil-59.dll"
Type: files;          Name: "{app}\swresample-4.dll"
Type: files;          Name: "{app}\swresample-5.dll"
Type: files;          Name: "{app}\swscale-7.dll"
Type: files;          Name: "{app}\swscale-8.dll"
Type: files;          Name: "{app}\Qt6*.dll"
Type: files;          Name: "{app}\FF00*API.dll"
Type: files;          Name: "{app}\XAPI.dll"
Type: files;          Name: "{app}\FTLPTP.dll"
Type: files;          Name: "{app}\FTLPTPIP.dll"
Type: files;          Name: "{app}\XSDK.DAT"
Type: filesandordirs; Name: "{app}\CrAdapter"
Type: filesandordirs; Name: "{app}\generic"
Type: filesandordirs; Name: "{app}\iconengines"
Type: filesandordirs; Name: "{app}\imageformats"
Type: filesandordirs; Name: "{app}\multimedia"
Type: filesandordirs; Name: "{app}\networkinformation"
Type: filesandordirs; Name: "{app}\platforminputcontexts"
Type: filesandordirs; Name: "{app}\platforms"
Type: filesandordirs; Name: "{app}\qml"
Type: filesandordirs; Name: "{app}\qmltooling"
Type: filesandordirs; Name: "{app}\relay"
Type: filesandordirs; Name: "{app}\sqldrivers"
Type: filesandordirs; Name: "{app}\styles"
Type: filesandordirs; Name: "{app}\tls"
Type: filesandordirs; Name: "{app}\tools"
Type: filesandordirs; Name: "{app}\vectorimageformats"

[Files]
; App icon is used by shortcuts and uninstall display.
Source: "{#AssetsDir}\app_icon.ico"; DestDir: "{app}"; Flags: ignoreversion

; Optional prerequisite for clean Windows installs.
Source: "{#AssetsDir}\vcredist_x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

; Copy the complete deployed runtime produced by CMake/windeployqt.
; This includes BOOTHME.exe, Qt DLLs/plugins/QML modules, camera SDK runtimes,
; FFmpeg/OpenCV/DirectX files, hardware helpers, filters, stickers, and tools.
; Only developer-local state, debug artifacts, and secrets are excluded.
Source: "{#BuildDir}\*"; DestDir: "{app}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; \
  Excludes: "key.json,*.log,*.pdb,*.ilk,*.exp,*.lib,*.obj,qmltooling\*,logs\*,captures\*,pending_uploads\*,data\*.db,data\*.db-shm,data\*.db-wal,data\*.lic"

[Dirs]
Name: "{app}";                 Permissions: users-modify
Name: "{app}\data";            Permissions: users-full
Name: "{app}\logs";            Permissions: users-full
Name: "{app}\captures";        Permissions: users-full
Name: "{app}\pending_uploads"; Permissions: users-full
Name: "{app}\filters";         Permissions: users-full
Name: "{app}\stickers";        Permissions: users-full

[Icons]
Name: "{group}\{#AppName}";                       Filename: "{app}\{#AppExe}"; IconFilename: "{app}\app_icon.ico"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}";  IconFilename: "{app}\app_icon.ico"
Name: "{autodesktop}\{#AppName}";                 Filename: "{app}\{#AppExe}"; IconFilename: "{app}\app_icon.ico"; Tasks: desktopicon

[Run]
Filename: "{tmp}\vcredist_x64.exe"; \
  Parameters: "/quiet /norestart"; \
  StatusMsg: "Installing Visual C++ Redistributable..."; \
  Flags: waituntilterminated skipifdoesntexist; \
  Check: VCRedistNeedsInstall

Filename: "{app}\{#AppExe}"; \
  Description: "{cm:LaunchProgram,{#AppName}}"; \
  Flags: nowait postinstall skipifsilent runascurrentuser

[Code]
function VCRedistNeedsInstall: Boolean;
var
  Version: String;
begin
  Result := not RegQueryStringValue(HKLM64,
    'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64',
    'Version', Version);
end;

procedure PatchLinkRunAsAdmin(LinkPath: String);
var
  Content: AnsiString;
  B: Byte;
begin
  if not FileExists(LinkPath) then Exit;
  if not LoadStringFromFile(LinkPath, Content) then Exit;
  if Length(Content) < 22 then Exit;

  B := Ord(Content[22]);
  if (B and $20) <> 0 then Exit;

  Content[22] := Chr(B or $20);
  SaveStringToFile(LinkPath, Content, False);
end;

procedure AddMissingFile(var Missing: String; RelativePath: String);
begin
  if not FileExists(ExpandConstant('{app}\' + RelativePath)) then
    Missing := Missing + RelativePath + #13#10;
end;

procedure AddMissingDir(var Missing: String; RelativePath: String);
begin
  if not DirExists(ExpandConstant('{app}\' + RelativePath)) then
    Missing := Missing + RelativePath + '\' + #13#10;
end;

procedure VerifyRequiredRuntime;
var
  Missing: String;
begin
  Missing := '';

  AddMissingFile(Missing, 'BOOTHME.exe');
  AddMissingFile(Missing, 'Qt6Core.dll');
  AddMissingFile(Missing, 'Qt6Gui.dll');
  AddMissingFile(Missing, 'Qt6Network.dll');
  AddMissingFile(Missing, 'Qt6Qml.dll');
  AddMissingFile(Missing, 'Qt6Quick.dll');
  AddMissingFile(Missing, 'Qt6QuickControls2.dll');
  AddMissingFile(Missing, 'Qt6Sql.dll');
  AddMissingFile(Missing, 'Qt6Widgets.dll');
  AddMissingFile(Missing, 'Qt6Multimedia.dll');
  AddMissingFile(Missing, 'Qt6VirtualKeyboard.dll');
  AddMissingFile(Missing, 'platforms\qwindows.dll');
  AddMissingFile(Missing, 'sqldrivers\qsqlite.dll');
  AddMissingFile(Missing, 'imageformats\qjpeg.dll');
  AddMissingFile(Missing, 'tls\qschannelbackend.dll');
  AddMissingFile(Missing, 'platforminputcontexts\qtvirtualkeyboardplugin.dll');
  AddMissingDir(Missing, 'qml\QtQuick');
  AddMissingDir(Missing, 'qml\QtQuick\Controls');
  AddMissingDir(Missing, 'qml\QtQuick\VirtualKeyboard');
  AddMissingDir(Missing, 'multimedia');

  AddMissingFile(Missing, 'EDSDK.dll');
  AddMissingFile(Missing, 'EdsImage.dll');
  AddMissingFile(Missing, 'Cr_Core.dll');
  AddMissingDir(Missing, 'CrAdapter');
  AddMissingFile(Missing, 'ControlServiceLayer.dll');
  AddMissingFile(Missing, 'MaidLayer.config');
  AddMissingFile(Missing, 'DC_PTP_Config.config');
  AddMissingFile(Missing, 'XAPI.dll');
  AddMissingFile(Missing, 'FTLPTP.dll');
  AddMissingFile(Missing, 'FTLPTPIP.dll');
  AddMissingFile(Missing, 'XSDK.DAT');
  AddMissingFile(Missing, 'FF0000API.dll');
  AddMissingFile(Missing, 'FF0020API.dll');

  AddMissingFile(Missing, 'ffmpeg.exe');
  AddMissingFile(Missing, 'avcodec-61.dll');
  AddMissingFile(Missing, 'avformat-61.dll');
  AddMissingFile(Missing, 'avutil-59.dll');
  AddMissingFile(Missing, 'swresample-5.dll');
  AddMissingFile(Missing, 'swscale-8.dll');
  AddMissingFile(Missing, 'opencv_world4140.dll');
  AddMissingFile(Missing, 'opengl32sw.dll');
  AddMissingFile(Missing, 'd3dcompiler_47.dll');
  AddMissingFile(Missing, 'dxcompiler.dll');
  AddMissingFile(Missing, 'dxil.dll');
  AddMissingFile(Missing, 'CyStat64.dll');
  AddMissingFile(Missing, 'relay\RelayCli.exe');
  AddMissingFile(Missing, 'relay\usb_relay_device.dll');
  AddMissingDir(Missing, 'tools\fuji_hotfolder');

  if Missing <> '' then
    MsgBox('Installation completed, but required runtime files are missing:' + #13#10 + #13#10 + Missing,
           mbError, MB_OK);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    PatchLinkRunAsAdmin(ExpandConstant('{group}\{#AppName}.lnk'));
    PatchLinkRunAsAdmin(ExpandConstant('{autodesktop}\{#AppName}.lnk'));
    VerifyRequiredRuntime;
  end;
end;
