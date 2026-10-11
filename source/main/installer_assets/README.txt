Photobooth Installer Assets
===========================

This folder contains assets needed for creating the installer.

Required Files:
---------------

1. vcredist_x64.exe
   - Download from: https://aka.ms/vs/17/release/vc_redist.x64.exe
   - This is the Microsoft Visual C++ Redistributable for Visual Studio 2015-2022
   - Place the downloaded file directly in this folder as "vcredist_x64.exe"

2. app_icon.ico (already present)
   - Application icon used for the installer and shortcuts
   - If you want to change the icon, replace this file with your own .ico file

Building the Installer:
-----------------------

1. First, build and deploy the application:
   - Run deploy.bat from the project root
   - This will build the release version and run windeployqt
   - It will also copy aws.json to the bin directory

2. Download vcredist_x64.exe:
   - Download from the link above
   - Save it in this folder (installer_assets)

3. Build the installer:
   - Open installer.iss with Inno Setup Compiler
   - Press F9 or click Build > Compile
   - The installer will be created in: installer-output\PhotoboothDashboard-Setup-1.0.0.exe

4. Test the installer:
   - Run the generated installer on a clean machine
   - Verify all features work correctly

Notes:
------
- The installer will automatically install vcredist_x64.exe if needed
- User settings and aws.json will be preserved during updates
- The installer requires administrator privileges to install properly
