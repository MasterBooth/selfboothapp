cmake_minimum_required(VERSION 3.16)
project(CameraApp LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# --------------------------------------------------------------------------
# EDSDK paths
# --------------------------------------------------------------------------
set(EDSDK_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../EDSDK")
set(EDSDK_64_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../EDSDK_64")

# Headers
include_directories(${EDSDK_ROOT}/Header)

# Select 32-bit or 64-bit library
if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(EDSDK_LIB_DIR "${EDSDK_64_ROOT}/Library")
    set(EDSDK_DLL_DIR "${EDSDK_64_ROOT}/Dll")
else()
    set(EDSDK_LIB_DIR "${EDSDK_ROOT}/Library")
    set(EDSDK_DLL_DIR "${EDSDK_ROOT}/Dll")
endif()

# Link library
find_library(EDSDK_LIB EDSDK PATHS ${EDSDK_LIB_DIR} NO_DEFAULT_PATH)

# --------------------------------------------------------------------------
# Common headers
# --------------------------------------------------------------------------
set(HEADERS
    Core/Types.h
    Core/ErrorHandler.h
    Core/EDSDKContext.h
    Core/CommandQueue.h
    Event/EventTypes.h
    Event/IEventListener.h
    Event/EventDispatcher.h
    Camera/CameraState.h
    Camera/CameraProperties.h
    Camera/CameraManager.h
    Camera/CameraDevice.h
    Capture/FileDownloader.h
    Capture/CaptureController.h
    LiveView/LiveViewController.h
    Interface/ICameraCallback.h
    Interface/CameraFacade.h
)

set(UI_HEADERS
    UI/MainWindow.h
    UI/UIHandler.h
    UI/PropertyLabels.h
)

# --------------------------------------------------------------------------
# Target 1: Console app (CameraApp)
# --------------------------------------------------------------------------
add_executable(CameraApp main.cpp ${HEADERS})
target_link_libraries(CameraApp PRIVATE ${EDSDK_LIB})
if(WIN32)
    target_link_libraries(CameraApp PRIVATE ole32)
endif()

# --------------------------------------------------------------------------
# Target 2: GUI app (CameraAppGUI) - WIN32 subsystem
# --------------------------------------------------------------------------
add_executable(CameraAppGUI WIN32 main_gui.cpp ${HEADERS} ${UI_HEADERS})
target_link_libraries(CameraAppGUI PRIVATE
    ${EDSDK_LIB}
    ole32
    gdiplus
    comctl32
    shell32
)

# --------------------------------------------------------------------------
# Target 3: GUI Driver script
# --------------------------------------------------------------------------
add_executable(gui_driver gui_driver.cpp)

# --------------------------------------------------------------------------
# Copy DLLs + create image/ folder for both targets
# --------------------------------------------------------------------------
foreach(TARGET_NAME CameraApp CameraAppGUI)
    add_custom_command(TARGET ${TARGET_NAME} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${EDSDK_DLL_DIR}/EDSDK.dll"
            "$<TARGET_FILE_DIR:${TARGET_NAME}>"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${EDSDK_DLL_DIR}/EdsImage.dll"
            "$<TARGET_FILE_DIR:${TARGET_NAME}>"
        COMMAND ${CMAKE_COMMAND} -E make_directory
            "$<TARGET_FILE_DIR:${TARGET_NAME}>/image"
    )
endforeach()
