cmake_minimum_required(VERSION 3.16)
project(canon_edsdk LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# MSVC: expose __cplusplus properly
if(MSVC)
    add_compile_options(/Zc:__cplusplus /EHsc)
endif()

# ─────────────────────────────────────────────────────────────────────────────
# pybind11 — tải tự động nếu chưa cài
# ─────────────────────────────────────────────────────────────────────────────
include(FetchContent)
FetchContent_Declare(
    pybind11
    GIT_REPOSITORY https://github.com/pybind/pybind11.git
    GIT_TAG        v2.13.1
)
FetchContent_MakeAvailable(pybind11)

# ─────────────────────────────────────────────────────────────────────────────
# Canon EDSDK paths
# ─────────────────────────────────────────────────────────────────────────────
set(EDSDK_ROOT    "${CMAKE_CURRENT_SOURCE_DIR}/../../EDSDK")
set(EDSDK_64_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../EDSDK_64")

# Headers
include_directories(${EDSDK_ROOT}/Header)

# 64-bit vs 32-bit
if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(EDSDK_LIB_DIR "${EDSDK_64_ROOT}/Library")
    set(EDSDK_DLL_DIR "${EDSDK_64_ROOT}/Dll")
else()
    set(EDSDK_LIB_DIR "${EDSDK_ROOT}/Library")
    set(EDSDK_DLL_DIR "${EDSDK_ROOT}/Dll")
endif()

find_library(EDSDK_LIB EDSDK PATHS ${EDSDK_LIB_DIR} NO_DEFAULT_PATH)
if(NOT EDSDK_LIB)
    message(FATAL_ERROR "EDSDK library not found in ${EDSDK_LIB_DIR}")
endif()

# ─────────────────────────────────────────────────────────────────────────────
# Python extension module
# ─────────────────────────────────────────────────────────────────────────────
pybind11_add_module(canon_edsdk
    canon_edsdk_bind.cpp
    ../API/CameraController.cpp   # The only .cpp needed — all other modules are header-only
)

target_include_directories(canon_edsdk PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/..   # CameraApp root → allows #include "API/..."
    ${CMAKE_CURRENT_SOURCE_DIR}      # this folder
)

target_link_libraries(canon_edsdk PRIVATE ${EDSDK_LIB})

if(WIN32)
    target_link_libraries(canon_edsdk PRIVATE ole32)
endif()

# ─────────────────────────────────────────────────────────────────────────────
# Sau khi build: copy EDSDK DLLs vào cùng thư mục với .pyd
# ─────────────────────────────────────────────────────────────────────────────
add_custom_command(TARGET canon_edsdk POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${EDSDK_DLL_DIR}/EDSDK.dll"
        "$<TARGET_FILE_DIR:canon_edsdk>"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${EDSDK_DLL_DIR}/EdsImage.dll"
        "$<TARGET_FILE_DIR:canon_edsdk>"
    COMMENT "Copying EDSDK DLLs..."
)

# ─────────────────────────────────────────────────────────────────────────────
# Install: copy .pyd + DLLs vào thư mục src/ của Python app
# ─────────────────────────────────────────────────────────────────────────────
set(PYTHON_SRC_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../src")

install(TARGETS canon_edsdk
    LIBRARY DESTINATION "${PYTHON_SRC_DIR}"
    RUNTIME DESTINATION "${PYTHON_SRC_DIR}"
)
install(FILES
    "${EDSDK_DLL_DIR}/EDSDK.dll"
    "${EDSDK_DLL_DIR}/EdsImage.dll"
    DESTINATION "${PYTHON_SRC_DIR}"
)

message(STATUS "canon_edsdk module will be installed to: ${PYTHON_SRC_DIR}")
