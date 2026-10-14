cmake_minimum_required(VERSION 3.16)
# Ngôn ngữ C cần cho thư viện mã hoá nhúng ở src/backend/vendor (Monocypher,
# C99). Trước đây chỉ khai CXX nên mọi file .c sẽ không được biên dịch.
project(BOOTHME VERSION 1.0.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# MSVC-specific: Enable proper __cplusplus macro for Qt
if(MSVC)
    add_compile_options(/Zc:__cplusplus)
    # Nguồn .cpp là UTF-8 (không BOM) và chứa chuỗi tiếng Việt. Ép MSVC đọc nguồn và
    # phát chuỗi hẹp theo UTF-8, nếu không các literal QString sẽ bị lỗi font (mojibake).
    add_compile_options(/utf-8)
endif()

# Set default build type to Release if not specified
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

# Release build optimizations
if(CMAKE_BUILD_TYPE STREQUAL "Release")
    add_compile_definitions(QT_NO_DEBUG_OUTPUT)  # Disable qDebug in release
    if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
        set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -O3")
    elseif(CMAKE_CXX_COMPILER_ID MATCHES "MSVC")
        set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} /O2")
    endif()
    message(STATUS "Building in Release mode with optimizations")
else()
    message(STATUS "Building in ${CMAKE_BUILD_TYPE} mode")
endif()

# Find Qt6 - set default prefix path for Windows if not provided
if(WIN32 AND NOT DEFINED CMAKE_PREFIX_PATH AND NOT DEFINED Qt6_DIR)
    set(CMAKE_PREFIX_PATH "C:/Qt/6.10.3/msvc2022_64" CACHE PATH "Qt6 installation path")
endif()

find_package(Qt6 REQUIRED COMPONENTS Core Quick Sql QuickControls2 Gui Qml Network PrintSupport Concurrent VirtualKeyboard Multimedia)

# Source files
set(SOURCES
    src/main.cpp
    src/backend/DatabaseManager.cpp
    src/backend/EventManager.cpp
    src/backend/EventModel.cpp
    src/backend/PrinterManager.cpp
    src/backend/PrinterConfig.cpp
    # Camera Backend (CameraApp::CameraController)
    src/backend/CameraController.cpp
    src/backend/CameraEventBridge.cpp
    # Nguồn chụp Hot Folder (thư mục ảnh / FUJIFILM HotFolder.exe / FUJIFILM Tether App)
    src/backend/HotFolderWatcher.cpp
    src/backend/FujiHotFolderProcess.cpp
    src/backend/FujiTetherAppProcess.cpp
    # USB Relay control (qua helper 32-bit RelayCli.exe + QProcess)
    src/backend/RelayController.cpp
    src/backend/DisplayManager.cpp
    src/backend/LayoutAnalyzer.cpp
    src/backend/ImageCompositor.cpp
    src/backend/S3Uploader.cpp
    src/backend/VideoCreator.cpp
    # AWS Configuration and Authentication
    src/backend/ConfigManager.cpp
    src/backend/SecureStore.cpp
    src/backend/MachineAuthenticator.cpp
    src/backend/DynamoDBClient.cpp
    src/backend/FrameSyncManager.cpp
    src/backend/FilterSyncManager.cpp
    src/backend/BackgroundSyncManager.cpp
    src/backend/PaymentSyncManager.cpp
    # License/gói + thanh toán SePay (Worker D1)
    src/backend/LicenseStore.cpp
    # Đăng nhập/mở khóa bằng mã QR (quét từ portal)
    src/backend/QrLoginManager.cpp
    src/backend/StudioAccount.cpp
    src/backend/CloudSyncManager.cpp
    src/backend/SessionManager.cpp
    # Path Management and Logging
    src/backend/AppPaths.cpp
    src/backend/Logger.cpp
    # Python HTTP Bridge
    src/backend/HttpBridge.cpp
    # User Authentication
    src/backend/UserAuthManager.cpp
    # Color Filter (LUT)
    src/backend/FilterManager.cpp
    # Sticker library
    src/backend/StickerManager.cpp
    # Bill Acceptor (ICT106 RS232)
    src/backend/BillAcceptor.cpp
    # Webcam Live View (OpenCV)
    src/backend/WebcamLiveView.cpp
    # Local QR Code generation (nayuki library + Qt image provider)
    src/backend/qrcodegen.cpp
    src/backend/QrImageProvider.cpp
    # Mã hoá nhúng — Monocypher (xem src/backend/vendor/README.md).
    # App booth chỉ dùng crypto_ed25519_check để XÁC MINH license; không ký.
    src/backend/vendor/monocypher.c
    src/backend/vendor/monocypher-ed25519.c
    src/backend/LicenseManager.cpp
    src/backend/ActivationClient.cpp
)

set(HEADERS
    src/backend/DatabaseManager.h
    src/backend/EventManager.h
    src/backend/EventModel.h
    src/backend/PrinterManager.h
    src/backend/PrinterConfig.h
    # Camera Backend (CameraApp::CameraController)
    src/backend/CameraController.h
    src/backend/CameraEventBridge.h
    src/backend/HotFolderWatcher.h
    src/backend/FujiHotFolderProcess.h
    src/backend/FujiTetherAppProcess.h
    src/backend/RelayController.h
    src/backend/DisplayManager.h
    src/backend/LiveViewImageProvider.h
    src/backend/LayoutAnalyzer.h
    src/backend/ImageCompositor.h
    src/backend/S3Uploader.h
    src/backend/VideoCreator.h
    # AWS Configuration and Authentication
    src/backend/ConfigManager.h
    src/backend/SecureStore.h
    src/backend/MachineAuthenticator.h
    src/backend/DynamoDBClient.h
    src/backend/FrameSyncManager.h
    src/backend/FilterSyncManager.h
    src/backend/BackgroundSyncManager.h
    src/backend/PaymentSyncManager.h
    src/backend/LicenseStore.h
    src/backend/QrLoginManager.h
    src/backend/StudioAccount.h
    src/backend/CloudSyncManager.h
    src/backend/SessionManager.h
    # Path Management and Logging
    src/backend/AppPaths.h
    src/backend/Logger.h
    # User Authentication
    src/backend/UserAuthManager.h
    # Color Filter (LUT)
    src/backend/FilterManager.h
    # Sticker library
    src/backend/StickerManager.h
    # Bill Acceptor (ICT106 RS232)
    src/backend/BillAcceptor.h
    # Webcam Live View (OpenCV)
    src/backend/WebcamLiveView.h
    # Local QR Code generation
    src/backend/qrcodegen.hpp
    src/backend/QrImageProvider.h
    # Mã hoá nhúng — Monocypher
    src/backend/vendor/monocypher.h
    src/backend/vendor/monocypher-ed25519.h
    src/backend/LicenseManager.h
    src/backend/ActivationClient.h
)

# QML resources
set(QML_RESOURCES
    qml/qml.qrc
)

# Debug
message(STATUS "SOURCES LIST: ${SOURCES}")

# Create executable
qt_add_executable(BOOTHME               
    ${SOURCES}
    ${HEADERS}
    ${QML_RESOURCES}
)

# ---------------------------------------------------------------------------
# Camera SDK selection
#
#   -DUSE_DUAL_SDK=ON   (recommended)
#       Both Canon EDSDK and Sony Camera Remote SDK compiled in.
#       Runtime auto-detection: SDKs initialised sequentially on main thread,
#       cameras enumerated in parallel worker threads.
#
#   -DUSE_SONY_SDK=ON   (legacy — Sony only)
#
#   default             Canon EDSDK only
# ---------------------------------------------------------------------------
option(USE_DUAL_SDK    "Build with Canon EDSDK, Sony CRSDK, Nikon MAID, and Fuji X SDK (runtime detection)" OFF)
option(USE_SONY_SDK    "Use Sony Camera Remote SDK instead of Canon EDSDK" OFF)
option(SELFBOOTH_ONLY  "Build standalone Self Booth app (no dashboard)" OFF)
option(PHOTOBOOTH_ONLY "Build Photobooth-only app (no Self Booth mode picker)" OFF)
option(USE_WEBCAM_LIVEVIEW "Enable HDMI/webcam live view via OpenCV" OFF)
set(APP_FIXED_OPERATION_MODE "" CACHE STRING "Force app operation mode at build time: mode2 or mode3. Empty keeps runtime setting.")

if(SELFBOOTH_ONLY AND PHOTOBOOTH_ONLY)
    message(FATAL_ERROR "SELFBOOTH_ONLY and PHOTOBOOTH_ONLY are mutually exclusive")
endif()

if(NOT APP_FIXED_OPERATION_MODE STREQUAL "")
    if(NOT APP_FIXED_OPERATION_MODE STREQUAL "mode2" AND NOT APP_FIXED_OPERATION_MODE STREQUAL "mode3")
        message(FATAL_ERROR "APP_FIXED_OPERATION_MODE must be empty, mode2, or mode3")
    endif()
    message(STATUS "Fixed operation mode: ${APP_FIXED_OPERATION_MODE}")
    target_compile_definitions(BOOTHME PRIVATE APP_FIXED_OPERATION_MODE="${APP_FIXED_OPERATION_MODE}")
endif()

if(SELFBOOTH_ONLY)
    message(STATUS "Build mode: SELFBOOTH_ONLY — standalone Self Booth app")
    add_compile_definitions(SELFBOOTH_ONLY)
endif()

if(PHOTOBOOTH_ONLY)
    message(STATUS "Build mode: PHOTOBOOTH_ONLY — Photobooth without Self Booth mode")
    add_compile_definitions(PHOTOBOOTH_ONLY)
endif()

get_filename_component(EDSDK_ROOT     "${CMAKE_CURRENT_SOURCE_DIR}/../EDSDK"           ABSOLUTE)
get_filename_component(EDSDK_LIB_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../EDSDK_64"        ABSOLUTE)
get_filename_component(CAMERAAPP_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../CameraApp"       ABSOLUTE)
get_filename_component(SONYAPP_ROOT   "${CMAKE_CURRENT_SOURCE_DIR}/../SonyApp"         ABSOLUTE)
get_filename_component(CRSDK_ROOT     "${CMAKE_CURRENT_SOURCE_DIR}/../RemoteCli/app/CRSDK"      ABSOLUTE)
get_filename_component(CRSDK_LIB_DIR  "${CMAKE_CURRENT_SOURCE_DIR}/../RemoteCli/external/crsdk" ABSOLUTE)
get_filename_component(NIKONAPP_ROOT  "${CMAKE_CURRENT_SOURCE_DIR}/../NikonApp"                 ABSOLUTE)
get_filename_component(NIKON_SDK_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../nikon/Module/Win"         ABSOLUTE)
get_filename_component(FUJIAPP_ROOT   "${CMAKE_CURRENT_SOURCE_DIR}/../fuji"                     ABSOLUTE)
get_filename_component(FUJI_SDK_ROOT  "${CMAKE_CURRENT_SOURCE_DIR}/../../SDK13410"              ABSOLUTE)
set(FUJI_SDK_RUNTIME_DIR "${FUJI_SDK_ROOT}/FujiSDKTest/build_qml/Release"
    CACHE PATH "Folder containing the FUJIFILM X SDK runtime used by BOOTHME")
if(NOT EXISTS "${FUJI_SDK_RUNTIME_DIR}/XAPI.dll")
    set(FUJI_SDK_RUNTIME_DIR "${FUJI_SDK_ROOT}/SAMPLES/Windows/LiveView/dll"
        CACHE PATH "Folder containing the FUJIFILM X SDK runtime used by BOOTHME" FORCE)
endif()

# EDSDK headers and CameraApp are always needed
# (SonyApp re-exports CameraApp event types, so CameraApp headers must be visible in all modes)
target_include_directories(BOOTHME PRIVATE
    "${EDSDK_ROOT}/Header"
    "${CAMERAAPP_ROOT}"
)

if(USE_DUAL_SDK)
    # ── Dual-SDK: Canon + Sony compiled in, runtime detection ──────────────
    message(STATUS "Camera backend: DUAL (Canon EDSDK + Sony CRSDK + Nikon MAID + Fuji X SDK) - runtime detection")
    target_compile_definitions(BOOTHME PRIVATE USE_DUAL_SDK UNICODE _UNICODE)
    target_include_directories(BOOTHME PRIVATE
        "${SONYAPP_ROOT}"
        "${CRSDK_ROOT}"
        "${NIKONAPP_ROOT}"
        "${FUJIAPP_ROOT}"
    )
    target_sources(BOOTHME PRIVATE
        "${CAMERAAPP_ROOT}/API/CameraController.cpp"
        "${SONYAPP_ROOT}/API/SonyCameraController.cpp"
    )
    # NikonApp is built as a separate MultiByte static lib (see its CMakeLists):
    # the Nikon MAID headers (NkTypes.h) collide with <windows.h> under UNICODE,
    # so they are confined to that lib. BOOTHME only sees the std:: public header.
    add_subdirectory("${NIKONAPP_ROOT}" "${CMAKE_BINARY_DIR}/NikonApp")
    add_subdirectory("${FUJIAPP_ROOT}" "${CMAKE_BINARY_DIR}/FujiApp")
    target_link_libraries(BOOTHME PRIVATE
        Qt6::Core Qt6::Quick Qt6::Sql Qt6::QuickControls2 Qt6::Gui
        Qt6::Qml Qt6::Network Qt6::PrintSupport Qt6::Concurrent Qt6::VirtualKeyboard Qt6::Multimedia
        "${EDSDK_LIB_ROOT}/Library/EDSDK.lib"
        "${CRSDK_LIB_DIR}/Cr_Core.lib"
        NikonApp
        FujiApp
    )
elseif(USE_SONY_SDK)
    # ── Sony only ───────────────────────────────────────────────────────────
    message(STATUS "Camera backend: Sony Camera Remote SDK (Cr_Core)")
    target_compile_definitions(BOOTHME PRIVATE USE_SONY_SDK UNICODE _UNICODE)
    target_include_directories(BOOTHME PRIVATE
        "${SONYAPP_ROOT}"
        "${CRSDK_ROOT}"
    )
    target_sources(BOOTHME PRIVATE "${SONYAPP_ROOT}/API/SonyCameraController.cpp")
    target_link_libraries(BOOTHME PRIVATE
        Qt6::Core Qt6::Quick Qt6::Sql Qt6::QuickControls2 Qt6::Gui
        Qt6::Qml Qt6::Network Qt6::PrintSupport Qt6::Concurrent Qt6::VirtualKeyboard Qt6::Multimedia
        "${CRSDK_LIB_DIR}/Cr_Core.lib"
    )
else()
    # ── Canon only (default) ────────────────────────────────────────────────
    message(STATUS "Camera backend: Canon EDSDK")
    target_sources(BOOTHME PRIVATE "${CAMERAAPP_ROOT}/API/CameraController.cpp")
    target_link_libraries(BOOTHME PRIVATE
        Qt6::Core Qt6::Quick Qt6::Sql Qt6::QuickControls2 Qt6::Gui
        Qt6::Qml Qt6::Network Qt6::PrintSupport Qt6::Concurrent Qt6::VirtualKeyboard Qt6::Multimedia
        "${EDSDK_LIB_ROOT}/Library/EDSDK.lib"
    )
endif()

# Bản standalone Self Booth xuất exe riêng: selfboothvn.exe
if(SELFBOOTH_ONLY)
    set_target_properties(BOOTHME PROPERTIES OUTPUT_NAME "selfboothvn")
endif()

# Windows specific settings
if(WIN32)
    # Gán icon cho file EXE (hiện trong Explorer, Taskbar, Alt+Tab)
    set(APP_ICON_RC "${CMAKE_CURRENT_SOURCE_DIR}/installer_assets/app_icon.rc")
    set(APP_ICON_ICO "${CMAKE_CURRENT_SOURCE_DIR}/installer_assets/app_icon.ico")
    set_source_files_properties("${APP_ICON_RC}" PROPERTIES
        OBJECT_DEPENDS "${APP_ICON_ICO}"
    )
    target_sources(BOOTHME PRIVATE "${APP_ICON_RC}")

    # Ẩn cửa sổ Console/Terminal khi chạy ứng dụng ở chế độ Release.
    # Chỉ bật ở Release để còn thấy qDebug output khi Debug.
    if(CMAKE_BUILD_TYPE STREQUAL "Release")
        if(MINGW)
            # MinGW: dùng -mwindows thay vì WIN32_EXECUTABLE TRUE
            # WIN32_EXECUTABLE TRUE + MinGW gây lỗi "__imp___argc" với libQt6EntryPoint.a
            target_link_options(BOOTHME PRIVATE "-mwindows")
        else()
            # MSVC / Clang-cl: WIN32_EXECUTABLE TRUE hoạt động bình thường
            set_target_properties(BOOTHME PROPERTIES WIN32_EXECUTABLE TRUE)
        endif()
    endif()

    # Link Windows libraries for DEVMODE manipulation
    target_link_libraries(BOOTHME PRIVATE
        winspool
        gdi32
        kernel32
        crypt32
    )

    # ── DLL copying ──────────────────────────────────────────────────────────
    # Copy Canon EDSDK DLLs when Canon is part of the build
    if(USE_DUAL_SDK OR NOT USE_SONY_SDK)
        add_custom_command(TARGET BOOTHME POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${EDSDK_LIB_ROOT}/Dll/EDSDK.dll"
                "$<TARGET_FILE_DIR:BOOTHME>"
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${EDSDK_LIB_ROOT}/Dll/EdsImage.dll"
                "$<TARGET_FILE_DIR:BOOTHME>"
        )
    endif()

    # Copy Sony CRSDK DLLs when Sony is part of the build
    if(USE_DUAL_SDK OR USE_SONY_SDK)
        add_custom_command(TARGET BOOTHME POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${CRSDK_LIB_DIR}/Cr_Core.dll"
                "$<TARGET_FILE_DIR:BOOTHME>"
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${CRSDK_LIB_DIR}/monitor_protocol.dll"
                "$<TARGET_FILE_DIR:BOOTHME>"
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${CRSDK_LIB_DIR}/monitor_protocol_pf.dll"
                "$<TARGET_FILE_DIR:BOOTHME>"
        )
        # CrAdapter DLLs
        add_custom_command(TARGET BOOTHME POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_FILE_DIR:BOOTHME>/CrAdapter"
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${CRSDK_LIB_DIR}/CrAdapter/Cr_PTP_IP.dll"
                "$<TARGET_FILE_DIR:BOOTHME>/CrAdapter"
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${CRSDK_LIB_DIR}/CrAdapter/Cr_PTP_USB.dll"
                "$<TARGET_FILE_DIR:BOOTHME>/CrAdapter"
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${CRSDK_LIB_DIR}/CrAdapter/libssh2.dll"
                "$<TARGET_FILE_DIR:BOOTHME>/CrAdapter"
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${CRSDK_LIB_DIR}/CrAdapter/libusb-1.0.dll"
                "$<TARGET_FILE_DIR:BOOTHME>/CrAdapter"
        )
    endif()

    # Copy Nikon Control Service Layer runtime (DLLs + .config) when Nikon is in the build.
    # The SDK is loaded dynamically (no import .lib); these files MUST sit next to the exe.
    if(USE_DUAL_SDK)
        foreach(_nk_dll ControlServiceLayer.dll NkdPTP.dll NkRoyalmile.dll dnssd.dll)
            add_custom_command(TARGET BOOTHME POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    "${NIKON_SDK_ROOT}/BinaryFile/${_nk_dll}"
                    "$<TARGET_FILE_DIR:BOOTHME>"
            )
        endforeach()
        foreach(_nk_cfg DC_PTP_Config.config MaidLayer.config RangeValue.config)
            add_custom_command(TARGET BOOTHME POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    "${NIKON_SDK_ROOT}/BinaryFile/${_nk_cfg}"
                    "$<TARGET_FILE_DIR:BOOTHME>"
                )
        endforeach()
    endif()

    # Copy FUJIFILM X SDK runtime when Fuji is in the dual-SDK build.
    # Copy only the X SDK runtime files, not the Qt DLLs from FujiSDKTest.
    if(USE_DUAL_SDK)
        set(_fuji_runtime_files
            "${FUJI_SDK_RUNTIME_DIR}/XAPI.dll"
            "${FUJI_SDK_RUNTIME_DIR}/FTLPTP.dll"
            "${FUJI_SDK_RUNTIME_DIR}/FTLPTPIP.dll"
            "${FUJI_SDK_RUNTIME_DIR}/XSDK.DAT"
        )
        file(GLOB _fuji_api_dlls "${FUJI_SDK_RUNTIME_DIR}/FF*API.dll")
        list(APPEND _fuji_runtime_files ${_fuji_api_dlls})
        list(REMOVE_DUPLICATES _fuji_runtime_files)

        set(_fuji_runtime_found FALSE)
        foreach(_fuji_file ${_fuji_runtime_files})
            if(EXISTS "${_fuji_file}")
                set(_fuji_runtime_found TRUE)
                add_custom_command(TARGET BOOTHME POST_BUILD
                    COMMAND ${CMAKE_COMMAND} -E copy_if_different
                        "${_fuji_file}"
                        "$<TARGET_FILE_DIR:BOOTHME>"
                    COMMENT "Copying FUJIFILM X SDK runtime: ${_fuji_file}"
                )
            endif()
        endforeach()

        if(NOT _fuji_runtime_found)
            message(WARNING "FUJIFILM X SDK runtime files not found in ${FUJI_SDK_RUNTIME_DIR}")
        endif()

        # ── FUJIFILM HotFolder.exe (nguồn chụp Hot Folder · Fujifilm) ──────────
        # App mở exe này ở <exe>/tools/fuji_hotfolder/. LIBRARY/ của bản sample
        # thiếu XSDK.DAT + FF*API.dll (file model máy) → chép cả runtime của BOOTHME
        # (cùng phiên bản XAPI.dll) vào đó. installer.iss chép đệ quy thư mục build.
        set(_fuji_hotfolder_exe "${FUJI_SDK_ROOT}/SAMPLES/Windows/HotFolder/x64/Release/HotFolder.exe")
        if(EXISTS "${_fuji_hotfolder_exe}")
            set(_fuji_hotfolder_dir "$<TARGET_FILE_DIR:BOOTHME>/tools/fuji_hotfolder")
            add_custom_command(TARGET BOOTHME POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E make_directory "${_fuji_hotfolder_dir}/LIBRARY"
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    "${_fuji_hotfolder_exe}" "${_fuji_hotfolder_dir}"
                COMMENT "Copying FUJIFILM HotFolder.exe"
            )
            foreach(_fuji_file ${_fuji_runtime_files})
                if(EXISTS "${_fuji_file}")
                    add_custom_command(TARGET BOOTHME POST_BUILD
                        COMMAND ${CMAKE_COMMAND} -E copy_if_different
                            "${_fuji_file}" "${_fuji_hotfolder_dir}/LIBRARY"
                    )
                endif()
            endforeach()
            # Máy dev: dự phòng khi chạy exe chưa có tools/ (vd build cũ).
            target_compile_definitions(BOOTHME PRIVATE
                FUJI_HOTFOLDER_DEV_EXE="${_fuji_hotfolder_exe}")
        else()
            message(WARNING "FUJIFILM HotFolder.exe not found: ${_fuji_hotfolder_exe}")
        endif()

        # ── FUJIFILM Tether App (nguồn chụp Hot Folder · Tether App) ──────────
        # Chép nguyên thư mục cài vào <exe>/tools/fuji_tetherapp/ để đóng gói kèm.
        # Thiếu thì app vẫn dùng bản người dùng tự cài ở Program Files.
        set(FUJI_TETHERAPP_DIR "C:/Program Files/FUJIFILM_TetherApp"
            CACHE PATH "Folder of the installed FUJIFILM Tether App to bundle with BOOTHME")
        if(EXISTS "${FUJI_TETHERAPP_DIR}/FUJIFILM_TetherApp.exe")
            add_custom_command(TARGET BOOTHME POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_directory
                    "${FUJI_TETHERAPP_DIR}" "$<TARGET_FILE_DIR:BOOTHME>/tools/fuji_tetherapp"
                COMMENT "Copying FUJIFILM Tether App"
            )
        else()
            message(WARNING "FUJIFILM Tether App not found: ${FUJI_TETHERAPP_DIR}")
        endif()
    endif()

    # DNP RX1 SDK DLL Copying
    add_custom_command(TARGET BOOTHME POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${CMAKE_CURRENT_SOURCE_DIR}/Status API/Dll/Win64/CyStat64.dll"
            "$<TARGET_FILE_DIR:BOOTHME>"
    )

    # Copy USB Relay helper (32-bit RelayCli.exe + usb_relay_device.dll) vao thu muc relay/.
    # Build truoc bang USBRelay/RelayCpp/build.bat. App goi qua QProcess (RelayController).
    set(RELAY_BUILD_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../USBRelay/RelayCpp/build")
    if(EXISTS "${RELAY_BUILD_DIR}/RelayCli.exe" AND EXISTS "${RELAY_BUILD_DIR}/usb_relay_device.dll")
        add_custom_command(TARGET BOOTHME POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_FILE_DIR:BOOTHME>/relay"
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${RELAY_BUILD_DIR}/RelayCli.exe"
                "$<TARGET_FILE_DIR:BOOTHME>/relay"
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${RELAY_BUILD_DIR}/usb_relay_device.dll"
                "$<TARGET_FILE_DIR:BOOTHME>/relay"
            COMMENT "Copying USB Relay helper (RelayCli.exe) to relay/"
        )
    else()
        message(WARNING "USB Relay helper khong day du tai ${RELAY_BUILD_DIR} (can RelayCli.exe va usb_relay_device.dll) — chay USBRelay/RelayCpp/build.bat truoc neu can dieu khien relay.")
    endif()

    # Copy ffmpeg.exe for video creation feature
    set(FFMPEG_EXE "${CMAKE_CURRENT_SOURCE_DIR}/ffmpeg/bin/ffmpeg.exe")
    if(EXISTS "${FFMPEG_EXE}")
        add_custom_command(TARGET BOOTHME POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${FFMPEG_EXE}"
                "$<TARGET_FILE_DIR:BOOTHME>"
            COMMENT "Copying ffmpeg.exe..."
        )
    else()
        message(WARNING "ffmpeg.exe not found at ${FFMPEG_EXE} — video creation will be unavailable at runtime")
    endif()

    # Copy opengl32sw.dll và d3dcompiler_47.dll — cần thiết cho fallback renderer
    # trên các máy thiếu driver D3D11 hoặc GPU tích hợp yếu
    foreach(_dll opengl32sw.dll d3dcompiler_47.dll)
        find_file(_found_${_dll} ${_dll}
            HINTS "${Qt6_DIR}/../../../bin"
            NO_DEFAULT_PATH
        )
        if(_found_${_dll})
            add_custom_command(TARGET BOOTHME POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    "${_found_${_dll}}"
                    "$<TARGET_FILE_DIR:BOOTHME>"
                COMMENT "Copying ${_dll}..."
            )
        endif()
    endforeach()

    # Chạy windeployqt sau build để deploy Qt DLLs + QML plugins (bao gồm VirtualKeyboard)
    find_program(WINDEPLOYQT windeployqt HINTS "${Qt6_DIR}/../../../bin")
    if(WINDEPLOYQT)
        add_custom_command(TARGET BOOTHME POST_BUILD
            COMMAND ${WINDEPLOYQT}
                --qmldir "${CMAKE_CURRENT_SOURCE_DIR}/qml"
                --no-translations
                --no-system-d3d-compiler
                --no-opengl-sw
                --release
                "$<TARGET_FILE:BOOTHME>"
            COMMENT "Running windeployqt..."
        )
    endif()
endif()


# ---------------------------------------------------------------------------
# Webcam Live View — OpenCV (tùy chọn, bật bằng -DUSE_WEBCAM_LIVEVIEW=ON)
# ---------------------------------------------------------------------------
if(USE_WEBCAM_LIVEVIEW)
    message(STATUS "Webcam live view: enabled (OpenCV required)")
    find_package(OpenCV REQUIRED COMPONENTS core videoio imgproc imgcodecs)
    target_compile_definitions(BOOTHME PRIVATE USE_WEBCAM_LIVEVIEW)
    target_include_directories(BOOTHME PRIVATE ${OpenCV_INCLUDE_DIRS})
    target_link_libraries(BOOTHME PRIVATE ${OpenCV_LIBS})

    # Copy OpenCV DLLs sang thư mục output (Windows)
    if(WIN32)
        foreach(_ocv_lib ${OpenCV_LIBS})
            get_target_property(_ocv_dll ${_ocv_lib} IMPORTED_LOCATION_RELEASE)
            if(_ocv_dll AND EXISTS "${_ocv_dll}")
                string(REPLACE ".lib" ".dll" _ocv_dll_path "${_ocv_dll}")
                if(EXISTS "${_ocv_dll_path}")
                    add_custom_command(TARGET BOOTHME POST_BUILD
                        COMMAND ${CMAKE_COMMAND} -E copy_if_different
                            "${_ocv_dll_path}"
                            "$<TARGET_FILE_DIR:BOOTHME>"
                        COMMENT "Copying OpenCV DLL: ${_ocv_dll_path}"
                    )
                endif()
            endif()
        endforeach()
    endif()
else()
    message(STATUS "Webcam live view: disabled (build with -DUSE_WEBCAM_LIVEVIEW=ON to enable)")
endif()

# Set output directory
set_target_properties(BOOTHME PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)

# Install
install(TARGETS BOOTHME
    RUNTIME DESTINATION bin
)

# ═══════════════════════════════════════════════════════════════════════════
# BOOTHME_ADMIN — cong cu cap giay phep (target thu hai, TUY CHON)
#
# Day la app DUY NHAT giu khoa ky. KHONG cai len may booth, khong dua cho khach.
# Tat mac dinh de ban build khach hang khong vo tinh keo theo.
#
#   cmake -DBUILD_ADMIN_TOOL=ON ..
# ═══════════════════════════════════════════════════════════════════════════
option(BUILD_ADMIN_TOOL "Build cong cu cap giay phep BOOTHME_ADMIN" OFF)
option(BUILD_RX1_TOOL "Build standalone DNP RX1 print test tool" OFF)
option(BUILD_PRINT_STATION "Build standalone Booth Print Station app" OFF)

if(BUILD_PRINT_STATION)
    message(STATUS "Print Station: ENABLED (BoothPrintStation)")

    qt_add_executable(BoothPrintStation
        printstation/src/main.cpp
        printstation/src/PrintJobClient.cpp
        printstation/src/PrintJobClient.h
        printstation/printstation.qrc
        src/backend/ConfigManager.cpp
        src/backend/ConfigManager.h
        src/backend/SecureStore.cpp
        src/backend/SecureStore.h
        src/backend/StudioAccount.cpp
        src/backend/StudioAccount.h
        src/backend/PrinterManager.cpp
        src/backend/PrinterManager.h
        src/backend/PrinterConfig.cpp
        src/backend/PrinterConfig.h
        src/backend/DatabaseManager.cpp
        src/backend/DatabaseManager.h
        src/backend/AppPaths.cpp
        src/backend/AppPaths.h
        src/backend/ImageCompositor.cpp
        src/backend/ImageCompositor.h
    )

    target_include_directories(BoothPrintStation PRIVATE
        "${CMAKE_CURRENT_SOURCE_DIR}/src/backend"
        "${CMAKE_CURRENT_SOURCE_DIR}/printstation/src"
    )

    target_link_libraries(BoothPrintStation PRIVATE
        Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2
        Qt6::Sql Qt6::Network Qt6::PrintSupport Qt6::Concurrent
    )

    set_target_properties(BoothPrintStation PROPERTIES
        OUTPUT_NAME "BoothPrintStation"
        WIN32_EXECUTABLE $<IF:$<CONFIG:Release>,TRUE,FALSE>
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
    )

    if(WIN32)
        target_compile_definitions(BoothPrintStation PRIVATE UNICODE _UNICODE)
        target_link_libraries(BoothPrintStation PRIVATE winspool gdi32 kernel32 crypt32)

        set(PRINT_STATION_ICON_RC "${CMAKE_CURRENT_SOURCE_DIR}/installer_assets/app_icon.rc")
        set(PRINT_STATION_ICON_ICO "${CMAKE_CURRENT_SOURCE_DIR}/installer_assets/app_icon.ico")
        if(EXISTS "${PRINT_STATION_ICON_RC}" AND EXISTS "${PRINT_STATION_ICON_ICO}")
            set_source_files_properties("${PRINT_STATION_ICON_RC}" PROPERTIES
                OBJECT_DEPENDS "${PRINT_STATION_ICON_ICO}"
            )
            target_sources(BoothPrintStation PRIVATE "${PRINT_STATION_ICON_RC}")
        endif()

        set(PRINT_STATION_CYSTAT_DLL "${CMAKE_CURRENT_SOURCE_DIR}/Status API/Dll/Win64/CyStat64.dll")
        if(EXISTS "${PRINT_STATION_CYSTAT_DLL}")
            add_custom_command(TARGET BoothPrintStation POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    "${PRINT_STATION_CYSTAT_DLL}"
                    "$<TARGET_FILE_DIR:BoothPrintStation>"
                COMMENT "Copying CyStat64.dll for BoothPrintStation"
            )
        endif()

        find_program(WINDEPLOYQT_PRINT_STATION windeployqt HINTS "${Qt6_DIR}/../../../bin")
        if(WINDEPLOYQT_PRINT_STATION)
            add_custom_command(TARGET BoothPrintStation POST_BUILD
                COMMAND "${WINDEPLOYQT_PRINT_STATION}"
                    --qmldir "${CMAKE_CURRENT_SOURCE_DIR}/printstation/qml"
                    --no-translations
                    --release
                    "$<TARGET_FILE:BoothPrintStation>"
                COMMENT "Deploying Qt runtime for BoothPrintStation"
            )
        endif()
    endif()
endif()

if(BUILD_RX1_TOOL)
    message(STATUS "RX1 print tool: ENABLED (RX1PrintTool)")

    qt_add_executable(RX1PrintTool
        src/rx1tool/main.cpp
        src/rx1tool/Rx1ToolPrinterBackend.cpp
        src/rx1tool/Rx1ToolPrinterBackend.h
        src/rx1tool/rx1tool.qrc
    )

    target_include_directories(RX1PrintTool PRIVATE
        "${CMAKE_CURRENT_SOURCE_DIR}/src/rx1tool"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/backend"
    )

    target_link_libraries(RX1PrintTool PRIVATE
        Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2
        Qt6::PrintSupport Qt6::Concurrent
    )

    set_target_properties(RX1PrintTool PROPERTIES
        WIN32_EXECUTABLE $<IF:$<CONFIG:Release>,TRUE,FALSE>
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
    )

    if(WIN32)
        target_compile_definitions(RX1PrintTool PRIVATE UNICODE _UNICODE)
        target_link_libraries(RX1PrintTool PRIVATE winspool gdi32 kernel32)

        set(RX1_TOOL_ICON_RC "${CMAKE_CURRENT_SOURCE_DIR}/installer_assets/app_icon.rc")
        set(RX1_TOOL_ICON_ICO "${CMAKE_CURRENT_SOURCE_DIR}/installer_assets/app_icon.ico")
        if(EXISTS "${RX1_TOOL_ICON_RC}" AND EXISTS "${RX1_TOOL_ICON_ICO}")
            set_source_files_properties("${RX1_TOOL_ICON_RC}" PROPERTIES
                OBJECT_DEPENDS "${RX1_TOOL_ICON_ICO}"
            )
            target_sources(RX1PrintTool PRIVATE "${RX1_TOOL_ICON_RC}")
        endif()

        set(RX1_CYSTAT_DLL "${CMAKE_CURRENT_SOURCE_DIR}/Status API/Dll/Win64/CyStat64.dll")
        set(RX1_DIRECT_DLL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/Status API/Window SDK/DirectDLL v0.7.1.2_D_foreign/DirectDLL v0.7.1.2_D_foreign/Dll/64bit")
        set(RX1_CSPSTAT_DLL "${RX1_DIRECT_DLL_DIR}/cspstat64.dll")
        if(EXISTS "${RX1_CYSTAT_DLL}")
            add_custom_command(TARGET RX1PrintTool POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    "${RX1_CYSTAT_DLL}"
                    "$<TARGET_FILE_DIR:RX1PrintTool>"
                COMMENT "Copying CyStat64.dll for RX1PrintTool"
            )
        endif()
        if(EXISTS "${RX1_CSPSTAT_DLL}")
            add_custom_command(TARGET RX1PrintTool POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_FILE_DIR:RX1PrintTool>/dnp"
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    "${RX1_CSPSTAT_DLL}"
                    "$<TARGET_FILE_DIR:RX1PrintTool>"
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    "${RX1_CSPSTAT_DLL}"
                    "$<TARGET_FILE_DIR:RX1PrintTool>/dnp"
                COMMENT "Copying DirectDLL cspstat64.dll for RX1PrintTool"
            )
        else()
            message(WARNING "DirectDLL cspstat64.dll not found at ${RX1_CSPSTAT_DLL}")
        endif()

        find_program(WINDEPLOYQT_RX1 windeployqt HINTS "${Qt6_DIR}/../../../bin")
        if(WINDEPLOYQT_RX1)
            add_custom_command(TARGET RX1PrintTool POST_BUILD
                COMMAND "${WINDEPLOYQT_RX1}"
                    --qmldir "${CMAKE_CURRENT_SOURCE_DIR}/src/rx1tool/qml"
                    --no-translations
                    --release
                    "$<TARGET_FILE:RX1PrintTool>"
                COMMENT "Deploying Qt runtime for RX1PrintTool"
            )
        endif()
    endif()
endif()

if(BUILD_ADMIN_TOOL)
    message(STATUS "Admin tool: ENABLED (BOOTHME_ADMIN)")

    qt_add_executable(BOOTHME_ADMIN
        admin/src/main.cpp
        admin/src/LicenseSigner.cpp
        admin/src/LicenseSigner.h
        admin/src/AdminApi.cpp
        admin/src/AdminApi.h
        # Dung chung thu vien ma hoa da nhung voi app booth. Khac biet duy nhat:
        # app admin dung crypto_ed25519_sign va crypto_argon2; app booth chi
        # dung crypto_ed25519_check.
        src/backend/vendor/monocypher.c
        src/backend/vendor/monocypher-ed25519.c
        admin/admin.qrc
    )

    target_include_directories(BOOTHME_ADMIN PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/admin/src
        ${CMAKE_CURRENT_SOURCE_DIR}/src/backend
    )

    target_link_libraries(BOOTHME_ADMIN PRIVATE
        Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2 Qt6::Network
    )

    set_target_properties(BOOTHME_ADMIN PROPERTIES
        WIN32_EXECUTABLE $<IF:$<CONFIG:Release>,TRUE,FALSE>
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
    )

    if(WIN32)
        find_program(WINDEPLOYQT_EXECUTABLE_ADMIN windeployqt HINTS "${Qt6_DIR}/../../../bin")
        if(WINDEPLOYQT_EXECUTABLE_ADMIN)
            add_custom_command(TARGET BOOTHME_ADMIN POST_BUILD
                COMMAND "${WINDEPLOYQT_EXECUTABLE_ADMIN}"
                        --qmldir "${CMAKE_CURRENT_SOURCE_DIR}/admin/qml"
                        "$<TARGET_FILE:BOOTHME_ADMIN>"
                COMMENT "Deploying Qt runtime for BOOTHME_ADMIN")
        endif()
    endif()
endif()
