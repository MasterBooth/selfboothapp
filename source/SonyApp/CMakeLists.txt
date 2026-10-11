cmake_minimum_required(VERSION 3.16)
project(SonyApp VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Windows requires Unicode for Sony SDK wide-char APIs
if(WIN32)
    add_compile_definitions(UNICODE _UNICODE)
endif()

# ---------------------------------------------------------------------------
# Paths (relative to this CMakeLists.txt, i.e. sdkcanon-main/SonyApp/)
# ---------------------------------------------------------------------------
get_filename_component(REPO_ROOT       "${CMAKE_CURRENT_SOURCE_DIR}/.."           ABSOLUTE)
get_filename_component(CAMERAAPP_ROOT  "${REPO_ROOT}/CameraApp"                   ABSOLUTE)
get_filename_component(EDSDK_ROOT      "${REPO_ROOT}/EDSDK"                       ABSOLUTE)
get_filename_component(CRSDK_HEADERS   "${REPO_ROOT}/RemoteCli/app/CRSDK"         ABSOLUTE)
get_filename_component(CRSDK_LIB_DIR   "${REPO_ROOT}/RemoteCli/external/crsdk"    ABSOLUTE)

# ---------------------------------------------------------------------------
# SonyApp static library
# ---------------------------------------------------------------------------
add_library(SonyApp STATIC
    API/SonyCameraController.cpp
)

target_include_directories(SonyApp PUBLIC
    "${CMAKE_CURRENT_SOURCE_DIR}"   # so consumers can #include "API/SonyCameraController.h"
    "${CAMERAAPP_ROOT}"             # for CameraApp event types
    "${EDSDK_ROOT}/Header"          # for EdsPropertyID type definitions (headers only)
    "${CRSDK_HEADERS}"              # Sony SDK headers (CrDeviceProperty.h, etc.)
)

target_link_libraries(SonyApp PUBLIC
    "${CRSDK_LIB_DIR}/Cr_Core.lib"
)
