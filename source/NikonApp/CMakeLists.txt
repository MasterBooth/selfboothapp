cmake_minimum_required(VERSION 3.16)
project(NikonApp VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# IMPORTANT: build MultiByte (NOT Unicode). The Nikon MAID headers (NkTypes.h)
# redefine UCHAR/CHAR via _TUCHAR/_TCHAR, which collide with <windows.h> under
# UNICODE. Compiling this wrapper MultiByte keeps those typedefs == the Windows
# base types (matching the validated SimpleTest project). The public header
# exposes only std:: / CameraApp types, so the UNICODE dashboard links cleanly.

# ---------------------------------------------------------------------------
# Paths (relative to this CMakeLists.txt, i.e. boothos/NikonApp/)
# ---------------------------------------------------------------------------
get_filename_component(REPO_ROOT      "${CMAKE_CURRENT_SOURCE_DIR}/.."        ABSOLUTE)
get_filename_component(CAMERAAPP_ROOT "${REPO_ROOT}/CameraApp"                ABSOLUTE)
get_filename_component(EDSDK_ROOT     "${REPO_ROOT}/EDSDK"                    ABSOLUTE)
get_filename_component(NIKON_SDK_ROOT "${REPO_ROOT}/nikon/Module/Win"         ABSOLUTE)

# ---------------------------------------------------------------------------
# NikonApp static library — wraps Nikon Control Service Layer (loaded at runtime)
# ---------------------------------------------------------------------------
add_library(NikonApp STATIC
    API/NikonCameraController.cpp
)

target_include_directories(NikonApp PUBLIC
    "${CMAKE_CURRENT_SOURCE_DIR}"       # #include "API/NikonCameraController.h"
    "${CAMERAAPP_ROOT}"                 # CameraApp event types
    "${EDSDK_ROOT}/Header"              # EdsPropertyID type (headers only)
    "${NIKON_SDK_ROOT}/HeaderFile"      # Maid3.h / Maid3d1.h
)

# No link library: ControlServiceLayer.dll is loaded dynamically (LoadLibrary).
