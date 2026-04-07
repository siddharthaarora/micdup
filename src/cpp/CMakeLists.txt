cmake_minimum_required(VERSION 3.20)
project(MicDup VERSION 1.2.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ── Platform detection ──────────────────────────────────────────────────
if(APPLE)
    enable_language(OBJC OBJCXX)
    set(CMAKE_OBJCXX_STANDARD 20)
    set(CMAKE_OBJCXX_STANDARD_REQUIRED ON)
elseif(WIN32)
    # Static CRT linkage — zero runtime DLL dependencies
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endif()

# ── whisper.cpp ──────────────────────────────────────────────────────────
include(FetchContent)
FetchContent_Declare(
    whisper
    GIT_REPOSITORY https://github.com/ggerganov/whisper.cpp.git
    GIT_TAG        v1.7.5
    GIT_SHALLOW    TRUE
)

# Configure whisper.cpp build options
set(BUILD_SHARED_LIBS      OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_TESTS    OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_SERVER   OFF CACHE BOOL "" FORCE)

if(APPLE)
    # Metal GPU backend for macOS (works on both Intel and Apple Silicon)
    option(MICDUP_METAL "Enable Metal GPU acceleration" ON)
    if(MICDUP_METAL)
        set(GGML_METAL ON CACHE BOOL "" FORCE)
        message(STATUS "MicDup: Metal GPU backend ENABLED")
    else()
        set(GGML_METAL OFF CACHE BOOL "" FORCE)
        message(STATUS "MicDup: CPU-only build")
    endif()
    # Disable non-Apple backends
    set(GGML_VULKAN OFF CACHE BOOL "" FORCE)
    set(GGML_CUDA   OFF CACHE BOOL "" FORCE)
else()
    # GPU backend options for Windows
    option(MICDUP_VULKAN "Enable Vulkan GPU acceleration" ON)
    if(MICDUP_VULKAN)
        set(GGML_VULKAN ON CACHE BOOL "" FORCE)
        message(STATUS "MicDup: Vulkan GPU backend ENABLED")
    else()
        set(GGML_VULKAN OFF CACHE BOOL "" FORCE)
        message(STATUS "MicDup: CPU-only build")
    endif()

    option(MICDUP_CUDA "Enable CUDA GPU acceleration (NVIDIA)" OFF)
    if(MICDUP_CUDA)
        set(GGML_CUDA ON CACHE BOOL "" FORCE)
        message(STATUS "MicDup: CUDA GPU backend ENABLED")
    endif()
endif()

FetchContent_MakeAvailable(whisper)

# ── MicDup executable ───────────────────────────────────────────────────

# Common source (cross-platform)
set(MICDUP_COMMON_SOURCES
    src/whisper_engine.cpp
)

if(WIN32)
    set(MICDUP_PLATFORM_SOURCES
        src/main.cpp
        src/app.cpp
        src/tray.cpp
        src/hotkey.cpp
        src/audio.cpp
        src/clipboard.cpp
        src/settings.cpp
        src/settings_dialog.cpp
        src/model_downloader.cpp
        src/icons.cpp
        src/log.cpp
    )
elseif(APPLE)
    set(MICDUP_PLATFORM_SOURCES
        src/main_mac.mm
        src/app_mac.mm
        src/tray_mac.mm
        src/hotkey_mac.mm
        src/audio_mac.mm
        src/clipboard_mac.mm
        src/settings_mac.mm
        src/settings_dialog_mac.mm
        src/model_downloader_mac.mm
        src/icons_mac.mm
        src/log_mac.mm
    )
endif()

set(MICDUP_SOURCES ${MICDUP_COMMON_SOURCES} ${MICDUP_PLATFORM_SOURCES})

if(WIN32)
    add_executable(MicDup WIN32 ${MICDUP_SOURCES})
elseif(APPLE)
    # Generate app icon
    set(ICON_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}")
    set(ICON_FILE "${ICON_OUTPUT_DIR}/AppIcon.icns")
    add_custom_command(
        OUTPUT "${ICON_FILE}"
        COMMAND swift "${CMAKE_CURRENT_SOURCE_DIR}/scripts/generate_icon.swift" "${ICON_OUTPUT_DIR}"
        DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/scripts/generate_icon.swift"
        COMMENT "Generating app icon..."
    )

    add_executable(MicDup MACOSX_BUNDLE ${MICDUP_SOURCES} "${ICON_FILE}")
    set_source_files_properties("${ICON_FILE}" PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
    set_target_properties(MicDup PROPERTIES
        MACOSX_BUNDLE_GUI_IDENTIFIER "com.micdup.app"
        MACOSX_BUNDLE_BUNDLE_NAME "MicDup"
        MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist.in"
        MACOSX_BUNDLE_ICON_FILE "AppIcon"
    )
endif()

target_include_directories(MicDup PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${whisper_SOURCE_DIR}/include
)

# ── Platform-specific linking ────────────────────────────────────────────

if(WIN32)
    target_link_libraries(MicDup PRIVATE
        whisper
        winhttp
        winmm
        ole32
        shell32
        user32
        gdi32
        comctl32
        shlwapi
    )
elseif(APPLE)
    find_library(COCOA_FRAMEWORK Cocoa REQUIRED)
    find_library(AVFOUNDATION_FRAMEWORK AVFoundation REQUIRED)
    find_library(CARBON_FRAMEWORK Carbon REQUIRED)
    find_library(COREGRAPHICS_FRAMEWORK CoreGraphics REQUIRED)
    find_library(COREAUDIO_FRAMEWORK CoreAudio REQUIRED)
    find_library(AUDIOTOOLBOX_FRAMEWORK AudioToolbox REQUIRED)
    find_library(USERNOTIFICATIONS_FRAMEWORK UserNotifications REQUIRED)

    target_link_libraries(MicDup PRIVATE
        whisper
        ${COCOA_FRAMEWORK}
        ${AVFOUNDATION_FRAMEWORK}
        ${CARBON_FRAMEWORK}
        ${COREGRAPHICS_FRAMEWORK}
        ${COREAUDIO_FRAMEWORK}
        ${AUDIOTOOLBOX_FRAMEWORK}
        ${USERNOTIFICATIONS_FRAMEWORK}
    )
endif()

# ── Compile definitions ─────────────────────────────────────────────────

target_compile_definitions(MicDup PRIVATE
    MICDUP_VERSION="${PROJECT_VERSION}"
    MICDUP_VERSION_MAJOR=${PROJECT_VERSION_MAJOR}
    MICDUP_VERSION_MINOR=${PROJECT_VERSION_MINOR}
    MICDUP_VERSION_PATCH=${PROJECT_VERSION_PATCH}
)

if(WIN32)
    target_compile_definitions(MicDup PRIVATE
        UNICODE
        _UNICODE
        WIN32_LEAN_AND_MEAN
        NOMINMAX
    )
    if(MICDUP_VULKAN)
        target_compile_definitions(MicDup PRIVATE MICDUP_HAS_VULKAN=1)
    endif()
    if(MICDUP_CUDA)
        target_compile_definitions(MicDup PRIVATE MICDUP_HAS_CUDA=1)
    endif()
elseif(APPLE)
    if(MICDUP_METAL)
        target_compile_definitions(MicDup PRIVATE MICDUP_HAS_METAL=1)
    endif()
endif()

# ── Output name ──────────────────────────────────────────────────────────

set_target_properties(MicDup PROPERTIES
    OUTPUT_NAME "MicDup"
)

if(WIN32)
    set_target_properties(MicDup PROPERTIES
        VS_DPI_AWARE "PerMonitor"
    )
endif()
