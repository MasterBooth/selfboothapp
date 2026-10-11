; RX1 Print Tool setup script
; Inno Setup 6.x
;
; Build app first:
;   cmake -S . -B build_rx1tool -DBUILD_RX1_TOOL=ON -DCMAKE_BUILD_TYPE=Release
;   cmake --build build_rx1tool --config Release --target RX1PrintTool
;
; Build installer:
;   iscc rx1_tool_installer.iss

#define AppName      "RX1 Print Tool"
#define AppVersion   "1.0"
#define AppPublisher "Tivasolutions"
#define AppExe       "RX1PrintTool.exe"
#define BuildDir     "build_rx1tool\bin\Release"
#define AssetsDir    "installer_assets"

[Setup]
AppId={{9B5FB14B-8608-47A8-99D9-3E56E4B1F8C1}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir=installer-output
OutputBaseFilename=RX1-Print-Tool-Setup-{#AppVersion}
SetupIconFile={#AssetsDir}\app_icon.ico
WizardSmallImageFile={#AssetsDir}\installer_small.bmp
WizardImageFile={#AssetsDir}\installer_logo.bmp
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\app_icon.ico
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[InstallDelete]
Type: filesandordirs; Name: "{app}\generic"
Type: filesandordirs; Name: "{app}\iconengines"
Type: filesandordirs; Name: "{app}\imageformats"
Type: filesandordirs; Name: "{app}\networkinformation"
Type: filesandordirs; Name: "{app}\platforms"
Type: filesandordirs; Name: "{app}\qml"
Type: filesandordirs; Name: "{app}\qmltooling"
Type: filesandordirs; Name: "{app}\styles"
Type: filesandordirs; Name: "{app}\tls"

[Files]
Source: "{#BuildDir}\{#AppExe}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\CyStat64.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#AssetsDir}\app_icon.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#AssetsDir}\vcredist_x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall skipifsourcedoesntexist
Source: "{#BuildDir}\*"; DestDir: "{app}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; \
  Excludes: "{#AppExe},CyStat64.dll,*.log,*.pdb,*.ilk,*.exp,*.lib"

[Dirs]
Name: "{app}"; Permissions: users-modify
Name: "{app}\logs"; Permissions: users-full

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"; IconFilename: "{app}\app_icon.ico"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"; IconFilename: "{app}\app_icon.ico"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; IconFilename: "{app}\app_icon.ico"; Tasks: desktopicon

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

procedure VerifyRequiredRuntime;
var
  Missing: String;
begin
  Missing := '';
  if not FileExists(ExpandConstant('{app}\RX1PrintTool.exe')) then Missing := Missing + 'RX1PrintTool.exe' + #13#10;
  if not FileExists(ExpandConstant('{app}\CyStat64.dll')) then Missing := Missing + 'CyStat64.dll' + #13#10;
  if not FileExists(ExpandConstant('{app}\Qt6Core.dll')) then Missing := Missing + 'Qt6Core.dll' + #13#10;
  if not FileExists(ExpandConstant('{app}\platforms\qwindows.dll')) then Missing := Missing + 'platforms\qwindows.dll' + #13#10;

  if Missing <> '' then
    MsgBox('Installation completed, but required runtime files are missing:' + #13#10 + #13#10 + Missing,
           mbError, MB_OK);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
    VerifyRequiredRuntime;
end;
