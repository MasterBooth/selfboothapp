cmake_minimum_required(VERSION 3.16)

project(FujiApp LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT WIN32)
    message(FATAL_ERROR "FujiApp targets Windows because FUJIFILM X SDK uses XAPI.dll.")
endif()

if(NOT DEFINED CAMERAAPP_ROOT)
    get_filename_component(CAMERAAPP_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../CameraApp" ABSOLUTE)
endif()
if(NOT DEFINED EDSDK_ROOT)
    get_filename_component(EDSDK_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../EDSDK" ABSOLUTE)
endif()

set(FUJI_SDK_HEADERS
    "${CMAKE_CURRENT_SOURCE_DIR}/../../SDK13410/HEADERS"
    CACHE PATH "FUJIFILM X SDK headers folder")

add_library(FujiApp STATIC
    API/FujiCameraController.cpp
    API/FujiCameraController.h
    src/Logger.cpp
    src/FujiSdkLibrary.cpp
    src/CameraManager.cpp
    src/FujiCamera.cpp
    src/ImageDownloader.cpp
    src/MediaRecordPolicy.cpp
    src/LiveViewWorker.cpp
    src/CaptureWorker.cpp
    src/PropertyManager.cpp
    src/XsdkApi.h
    src/ICamera.h
    src/CameraContext.h
    src/SdkGuard.h
    src/FujiSdkLibrary.h
    src/Logger.h
    src/CameraManager.h
    src/FujiCamera.h
    src/ImageDownloader.h
    src/MediaRecordPolicy.h
    src/RuntimeConfig.h
    src/LiveViewWorker.h
    src/CaptureWorker.h
    src/PropertyManager.h
)

target_include_directories(FujiApp
    PUBLIC
        "${CMAKE_CURRENT_SOURCE_DIR}"
    PRIVATE
        "${CMAKE_CURRENT_SOURCE_DIR}/src"
        "${FUJI_SDK_HEADERS}"
        "${CAMERAAPP_ROOT}"
        "${EDSDK_ROOT}/Header"
)

target_compile_definitions(FujiApp PRIVATE
    UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX _CRT_SECURE_NO_WARNINGS
    Logger=FujiCoreLogger
    LogLevel=FujiCoreLogLevel
    CameraManager=FujiCoreCameraManager
    FujiCamera=FujiCoreCamera
    FujiSdkLibrary=FujiCoreSdkLibrary
    ImageDownloader=FujiCoreImageDownloader
    LiveViewWorker=FujiCoreLiveViewWorker
    CaptureWorker=FujiCoreCaptureWorker
    PropertyManager=FujiCorePropertyManager
    RuntimeConfig=FujiCoreRuntimeConfig
    MediaRecordMode=FujiCoreMediaRecordMode
    runtimeConfig=fujiCoreRuntimeConfig
    mediaRecordModeName=fujiCoreMediaRecordModeName
    mediaRecordSdkValue=fujiCoreMediaRecordSdkValue
    applyConfiguredMediaRecord=fujiCoreApplyConfiguredMediaRecord
)

if(MSVC)
    target_compile_options(FujiApp PRIVATE /W4 /permissive- /EHsc /MP /wd4828)
endif()
