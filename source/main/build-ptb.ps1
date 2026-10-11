# =============================================================================
# build-ptb.ps1  -  Build Photobooth-only app (no Self Booth mode)
#
# Builds with DUAL SDK (Canon + Sony + Nikon + Fuji) by default and PHOTOBOOTH_ONLY=ON,
# so the app skips the ModePicker and goes straight into LandingPage.
#
# Output: build-ptb\bin\Release\BOOTHME.exe
#
# Usage:
#   .\build-ptb.ps1              # Canon + Sony + Nikon + Fuji (default - dual SDK)
#   .\build-ptb.ps1 -Mode mode2  # Build fixed to operation mode 2
#   .\build-ptb.ps1 -Mode mode3  # Build fixed to operation mode 3
#   .\build-ptb.ps1 -Canon       # Canon only
#   .\build-ptb.ps1 -Sony        # Sony only
#   .\build-ptb.ps1 -Clean       # Delete build dir first
#   .\build-ptb.ps1 -Webcam      # Enable HDMI/webcam live view (OpenCV)
#   .\build-ptb.ps1 -Webcam -OpenCVDir D:/opencv/build
# =============================================================================
param(
    [switch]$Canon,
    [switch]$Sony,
    [ValidateSet("", "mode2", "mode3")]
    [string]$Mode = "",
    [switch]$Clean,
    [switch]$Webcam,
    [string]$OpenCVDir = "$PSScriptRoot/../../opencv/build"
)

$ErrorActionPreference = "Stop"

$BUILD_DIR  = "build_studio"
$EXE_NAME   = "BOOTHME"
$QT_PATH    = "C:/Qt/6.10.3/msvc2022_64"
$GENERATOR  = "Visual Studio 18 2026"
$PLATFORM   = "x64"
$CONFIG     = "Release"

Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "  Photobooth-only Build (no SelfBooth)" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# Clean
if ($Clean -and (Test-Path $BUILD_DIR)) {
    Write-Host "Cleaning $BUILD_DIR ..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $BUILD_DIR
}

# Create build dir
if (-not (Test-Path $BUILD_DIR)) {
    New-Item -ItemType Directory -Path $BUILD_DIR | Out-Null
}

Push-Location $BUILD_DIR

try {
    # SDK flags - default is Dual SDK (Canon + Sony + Nikon + Fuji)
    $sdkFlags = @()
    if ($Canon) {
        Write-Host "SDK: Canon only" -ForegroundColor Cyan
    }
    elseif ($Sony) {
        $sdkFlags += "-DUSE_SONY_SDK=ON"
        Write-Host "SDK: Sony only" -ForegroundColor Cyan
    }
    else {
        $sdkFlags += "-DUSE_DUAL_SDK=ON"
        Write-Host "SDK: Canon + Sony + Nikon + Fuji (Dual - default)" -ForegroundColor Cyan
    }

    # Webcam live view (OpenCV). Không truyền -Webcam thì giữ giá trị đã lưu trong cache.
    $webcamFlags = @()
    if ($Webcam) {
        $ocv = (Resolve-Path $OpenCVDir -ErrorAction SilentlyContinue)
        if (-not $ocv -or -not (Test-Path (Join-Path $ocv "OpenCVConfig.cmake"))) {
            throw "OpenCVConfig.cmake not found in '$OpenCVDir' (use -OpenCVDir <path>\build)"
        }
        $ocvPath = $ocv.Path -replace '\\', '/'
        $webcamFlags += "-DUSE_WEBCAM_LIVEVIEW=ON", "-DOpenCV_DIR=$ocvPath"
        Write-Host "Webcam live view: ON (OpenCV: $ocvPath)" -ForegroundColor Cyan
    }

    $modeFlags = @("-DAPP_FIXED_OPERATION_MODE=$Mode")
    if ($Mode -ne "") {
        Write-Host "Operation mode: fixed $Mode" -ForegroundColor Cyan
    } else {
        Write-Host "Operation mode: runtime setting" -ForegroundColor Cyan
    }

    # CMake configure
    Write-Host ""
    Write-Host "[ 1/2 ] CMake configure..." -ForegroundColor Green
    $cmakeArgs = @(
        "-G", $GENERATOR,
        "-A", $PLATFORM,
        "-DCMAKE_PREFIX_PATH=$QT_PATH",
        "-DCMAKE_BUILD_TYPE=$CONFIG",
        "-DPHOTOBOOTH_ONLY=ON",
        "-DCMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE=bin/Release"
    ) + $sdkFlags + $webcamFlags + $modeFlags + @("..")

    & cmake @cmakeArgs
    if ($LASTEXITCODE -ne 0) { throw "CMake configure failed (exit $LASTEXITCODE)" }

    # Build
    Write-Host ""
    Write-Host "[ 2/2 ] Building $CONFIG ..." -ForegroundColor Green
    & cmake --build . --config $CONFIG --parallel
    if ($LASTEXITCODE -ne 0) { throw "Build failed (exit $LASTEXITCODE)" }

    # Done
    $outDir   = "bin\$CONFIG"
    $exePath  = "$outDir\$EXE_NAME.exe"
    $fullPath = (Resolve-Path $exePath).Path
    Write-Host ""
    Write-Host "[OK] Build succeeded!" -ForegroundColor Green
    Write-Host "   Output: $fullPath" -ForegroundColor White
    Write-Host ""
    Write-Host "Run: cd $BUILD_DIR\$outDir; .\$EXE_NAME.exe" -ForegroundColor Yellow
    Write-Host ""

} catch {
    Write-Host ""
    Write-Host "[FAIL] $_" -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}
