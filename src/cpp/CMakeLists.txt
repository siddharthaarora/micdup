cmake_minimum_required(VERSION 3.20)
project(MicDup VERSION 1.2.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Static CRT linkage — zero runtime DLL dependencies
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

# ── whisper.cpp ──────────────────────────────────────────────────────────
# Fetch whisper.cpp as a dependency
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

# GPU backend options — enable Vulkan for cross-vendor GPU support
option(MICDUP_VULKAN "Enable Vulkan GPU acceleration" ON)
if(MICDUP_VULKAN)
    set(GGML_VULKAN ON CACHE BOOL "" FORCE)
    message(STATUS "MicDup: Vulkan GPU backend ENABLED")
else()
    set(GGML_VULKAN OFF CACHE BOOL "" FORCE)
    message(STATUS "MicDup: CPU-only build")
endif()

# CUDA support (NVIDIA GPUs)
option(MICDUP_CUDA "Enable CUDA GPU acceleration (NVIDIA)" OFF)
if(MICDUP_CUDA)
    set(GGML_CUDA ON CACHE BOOL "" FORCE)
    message(STATUS "MicDup: CUDA GPU backend ENABLED")
endif()

FetchContent_MakeAvailable(whisper)

# ── MicDup executable ───────────────────────────────────────────────────
set(MICDUP_SOURCES
    src/main.cpp
    src/app.cpp
    src/tray.cpp
    src/hotkey.cpp
    src/audio.cpp
    src/whisper_engine.cpp
    src/clipboard.cpp
    src/settings.cpp
    src/settings_dialog.cpp
    src/model_downloader.cpp
    src/updater.cpp
    src/icons.cpp
    src/log.cpp
)

add_executable(MicDup WIN32 ${MICDUP_SOURCES})

target_include_directories(MicDup PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${whisper_SOURCE_DIR}/include
)

target_link_libraries(MicDup PRIVATE
    whisper
    # Windows system libraries
    winhttp
    winmm
    ole32
    shell32
    user32
    gdi32
    comctl32
    shlwapi
)

# Embed version info
target_compile_definitions(MicDup PRIVATE
    MICDUP_VERSION="${PROJECT_VERSION}"
    MICDUP_VERSION_MAJOR=${PROJECT_VERSION_MAJOR}
    MICDUP_VERSION_MINOR=${PROJECT_VERSION_MINOR}
    MICDUP_VERSION_PATCH=${PROJECT_VERSION_PATCH}
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

# Windows manifest for DPI awareness and modern look
set_target_properties(MicDup PROPERTIES
    OUTPUT_NAME "MicDup"
    VS_DPI_AWARE "PerMonitor"
)
