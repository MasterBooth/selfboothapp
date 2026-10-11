; BOOTHME Admin setup script
; Inno Setup 6.x
;
; Build app first:
;   cmake --build build_admin --config Release --target BOOTHME_ADMIN
;
; Build installer:
;   iscc admin_installer.iss
;
; Security note:
;   admin-config.json may contain ADMIN_API_TOKEN and is not packaged.
;   The installer can write it from user input during install.

#define AppName      "BOOTHME Admin"
#define AppVersion   "1.1.0"
#define AppPublisher "Tivasolutions"
#define AppExe       "BOOTHME_ADMIN.exe"
#define BuildDir     "build_admin\bin\Release"
#define BuildPath    AddBackslash(SourcePath) + BuildDir
#define AssetsDir    "installer_assets"

; ---------------------------------------------------------------------------
; Build-time dependency guard
; ---------------------------------------------------------------------------
; The installer packages the complete CMake/windeployqt Release deploy folder.
; These checks fail early when a clean-machine dependency is missing.

#if !FileExists(BuildPath + "\" + AppExe)
  #error Build output is missing BOOTHME_ADMIN.exe. Build Release before running iscc.
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
#if !FileExists(BuildPath + "\Qt6QmlCore.dll")
  #error Qt6QmlCore.dll is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\Qt6Quick.dll")
  #error Qt6Quick.dll is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\Qt6QuickControls2.dll")
  #error Qt6QuickControls2.dll is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\Qt6VirtualKeyboard.dll")
  #error Qt6VirtualKeyboard.dll is missing from the deploy folder.
#endif

; Qt plugins and QML modules
#if !FileExists(BuildPath + "\platforms\qwindows.dll")
  #error Qt platform plugin platforms\qwindows.dll is missing.
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
#if !DirExists(BuildPath + "\qml\QtCore")
  #error QtCore QML module is missing. Run windeployqt with --qmldir.
#endif
#if !DirExists(BuildPath + "\qml\QtQuick")
  #error QtQuick QML runtime is missing. Run windeployqt with --qmldir.
#endif
#if !DirExists(BuildPath + "\qml\QtQuick\Controls")
  #error Qt Quick Controls QML runtime is missing. Run windeployqt with --qmldir.
#endif
#if !DirExists(BuildPath + "\qml\QtQuick\Dialogs")
  #error Qt Quick Dialogs QML runtime is missing. Run windeployqt with --qmldir.
#endif
#if !DirExists(BuildPath + "\qml\QtQuick\Layouts")
  #error Qt Quick Layouts QML runtime is missing. Run windeployqt with --qmldir.
#endif
#if !DirExists(BuildPath + "\qml\QtQuick\VirtualKeyboard")
  #error Qt VirtualKeyboard QML runtime is missing. Run windeployqt with --qmldir.
#endif

; Graphics helpers
#if !FileExists(BuildPath + "\opengl32sw.dll")
  #error Qt software OpenGL runtime opengl32sw.dll is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\D3Dcompiler_47.dll")
  #error Direct3D compiler runtime D3Dcompiler_47.dll is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\dxcompiler.dll")
  #error DirectX shader compiler dxcompiler.dll is missing from the deploy folder.
#endif
#if !FileExists(BuildPath + "\dxil.dll")
  #error DirectX shader compiler dxil.dll is missing from the deploy folder.
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
AppId={{4E1C7B52-9A3D-4F08-B6E2-71D5C0A83F94}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}

; Per-user install: the app writes admin-config.json beside the executable.
PrivilegesRequired=lowest
DefaultDirName={localappdata}\Programs\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes

OutputDir=installer-output
OutputBaseFilename=BOOTHME-Admin-Setup-{#AppVersion}
SetupIconFile={#AssetsDir}\app_icon.ico
WizardSmallImageFile={#AssetsDir}\installer_small.bmp
WizardImageFile={#AssetsDir}\installer_logo.bmp

Compression=lzma2/max
SolidCompression=no
LZMANumBlockThreads=2

WizardStyle=modern
DisableWelcomePage=no

ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

CloseApplications=yes
RestartApplications=no
UninstallDisplayIcon={app}\app_icon.ico
UninstallDisplayName={#AppName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[InstallDelete]
; Remove stale runtime from earlier installer layouts before copying the current
; deploy folder. admin-config.json is intentionally kept unless overwritten.
Type: files;          Name: "{app}\Qt6*.dll"
Type: filesandordirs; Name: "{app}\generic"
Type: filesandordirs; Name: "{app}\iconengines"
Type: filesandordirs; Name: "{app}\imageformats"
Type: filesandordirs; Name: "{app}\networkinformation"
Type: filesandordirs; Name: "{app}\platforminputcontexts"
Type: filesandordirs; Name: "{app}\platforms"
Type: filesandordirs; Name: "{app}\qml"
Type: filesandordirs; Name: "{app}\qmltooling"
Type: filesandordirs; Name: "{app}\styles"
Type: filesandordirs; Name: "{app}\tls"
Type: filesandordirs; Name: "{app}\translations"
Type: filesandordirs; Name: "{app}\vectorimageformats"

[Files]
; App icon is used by shortcuts and uninstall display.
Source: "{#AssetsDir}\app_icon.ico"; DestDir: "{app}"; Flags: ignoreversion

; Optional prerequisite for clean Windows installs.
Source: "{#AssetsDir}\vcredist_x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

; Copy the complete deployed runtime produced by CMake/windeployqt.
; admin-config.json is excluded because it can contain ADMIN_API_TOKEN.
Source: "{#BuildDir}\*"; DestDir: "{app}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; \
  Excludes: "admin-config.json,key.json,*.log,*.pdb,*.ilk,*.exp,*.lib,*.obj,qmltooling\*"

[Icons]
Name: "{group}\{#AppName}";                       Filename: "{app}\{#AppExe}"; IconFilename: "{app}\app_icon.ico"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}";  IconFilename: "{app}\app_icon.ico"
Name: "{autodesktop}\{#AppName}";                 Filename: "{app}\{#AppExe}"; IconFilename: "{app}\app_icon.ico"; Tasks: desktopicon

[Run]
Filename: "{tmp}\vcredist_x64.exe"; \
  Parameters: "/quiet /norestart"; \
  StatusMsg: "Installing Visual C++ Redistributable..."; \
  Flags: waituntilterminated skipifdoesntexist shellexec; \
  Check: VCRedistNeedsInstall

Filename: "{app}\{#AppExe}"; \
  Description: "{cm:LaunchProgram,{#AppName}}"; \
  Flags: nowait postinstall skipifsilent

[UninstallDelete]
; admin-config.json is created during install, not packaged in [Files].
Type: files; Name: "{app}\admin-config.json"

[Code]
var
  ServerPage: TInputQueryWizardPage;

function VCRedistNeedsInstall: Boolean;
var
  Version: String;
begin
  Result := not RegQueryStringValue(HKLM64,
    'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64',
    'Version', Version);
end;

procedure InitializeWizard;
begin
  ServerPage := CreateInputQueryPage(wpSelectDir,
    'Ket noi may chu',
    'Dia chi Worker va token quan tri (ADMIN_API_TOKEN).',
    'App dung token nay de xem danh sach may va nop giay phep da ky. ' +
    'De trong token neu dang cap nhat ban cu hoac muon nhap sau trong app.');
  ServerPage.Add('Dia chi may chu:', False);
  ServerPage.Add('ADMIN_API_TOKEN:', True);
  ServerPage.Values[0] := 'https://boothme.tech';
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  Url: String;
begin
  Result := True;
  if CurPageID = ServerPage.ID then
  begin
    Url := Trim(ServerPage.Values[0]);
    if (Pos('https://', Lowercase(Url)) <> 1) and (Pos('http://', Lowercase(Url)) <> 1) then
    begin
      MsgBox('Dia chi may chu phai bat dau bang https:// hoac http://', mbError, MB_OK);
      Result := False;
    end;
  end;
end;

function JsonEscape(const S: String): String;
begin
  Result := S;
  StringChangeEx(Result, '\', '\\', True);
  StringChangeEx(Result, '"', '\"', True);
end;

procedure WriteAdminConfig;
var
  Url, Token, Path: String;
begin
  Url := Trim(ServerPage.Values[0]);
  Token := Trim(ServerPage.Values[1]);
  Path := ExpandConstant('{app}\admin-config.json');

  while (Length(Url) > 0) and (Url[Length(Url)] = '/') do
    Delete(Url, Length(Url), 1);

  if Token = '' then
    Exit;

  if not SaveStringToFile(Path,
      '{' + #13#10 +
      '  "base_url": "' + JsonEscape(Url) + '",' + #13#10 +
      '  "admin_token": "' + JsonEscape(Token) + '"' + #13#10 +
      '}' + #13#10, False) then
    MsgBox('Khong ghi duoc ' + Path + '. Hay nhap lai trong app.', mbError, MB_OK);
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

  AddMissingFile(Missing, 'BOOTHME_ADMIN.exe');
  AddMissingFile(Missing, 'Qt6Core.dll');
  AddMissingFile(Missing, 'Qt6Gui.dll');
  AddMissingFile(Missing, 'Qt6Network.dll');
  AddMissingFile(Missing, 'Qt6Qml.dll');
  AddMissingFile(Missing, 'Qt6QmlCore.dll');
  AddMissingFile(Missing, 'Qt6Quick.dll');
  AddMissingFile(Missing, 'Qt6QuickControls2.dll');
  AddMissingFile(Missing, 'Qt6VirtualKeyboard.dll');
  AddMissingFile(Missing, 'platforms\qwindows.dll');
  AddMissingFile(Missing, 'imageformats\qjpeg.dll');
  AddMissingFile(Missing, 'tls\qschannelbackend.dll');
  AddMissingFile(Missing, 'platforminputcontexts\qtvirtualkeyboardplugin.dll');
  AddMissingDir(Missing, 'qml\QtCore');
  AddMissingDir(Missing, 'qml\QtQuick');
  AddMissingDir(Missing, 'qml\QtQuick\Controls');
  AddMissingDir(Missing, 'qml\QtQuick\Dialogs');
  AddMissingDir(Missing, 'qml\QtQuick\Layouts');
  AddMissingDir(Missing, 'qml\QtQuick\VirtualKeyboard');
  AddMissingFile(Missing, 'opengl32sw.dll');
  AddMissingFile(Missing, 'D3Dcompiler_47.dll');
  AddMissingFile(Missing, 'dxcompiler.dll');
  AddMissingFile(Missing, 'dxil.dll');

  if Missing <> '' then
    MsgBox('Cai dat xong nhung thieu runtime:' + #13#10 + #13#10 + Missing,
           mbError, MB_OK);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    WriteAdminConfig;
    VerifyRequiredRuntime;
  end;
end;
