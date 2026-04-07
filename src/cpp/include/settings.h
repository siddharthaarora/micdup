#pragma once

#include <string>
#include <cstdint>

// Platform-independent modifier and key constants.
// On Windows these match the Win32 MOD_* / VK_* values.
// On macOS they are mapped to Carbon equivalents in the implementation.
#ifndef _WIN32
#ifndef MOD_ALT
#define MOD_ALT     0x0001
#define MOD_CONTROL 0x0002
#define MOD_SHIFT   0x0004
#define MOD_WIN     0x0008  // Command key on macOS
#endif

#ifndef VK_SPACE
#define VK_SPACE   0x20
#define VK_RETURN  0x0D
#define VK_TAB     0x09
#define VK_ESCAPE  0x1B
#define VK_BACK    0x08
#define VK_DELETE  0x2E
#define VK_INSERT  0x2D
#define VK_HOME    0x24
#define VK_END     0x23
#define VK_F1      0x70
#define VK_F2      0x71
#define VK_F3      0x72
#define VK_F4      0x73
#define VK_F5      0x74
#define VK_F6      0x75
#define VK_F7      0x76
#define VK_F8      0x77
#define VK_F9      0x78
#define VK_F10     0x79
#define VK_F11     0x7A
#define VK_F12     0x7B
#define VK_F13     0x7C
#define VK_F14     0x7D
#define VK_F15     0x7E
#define VK_F16     0x7F
#define VK_F17     0x80
#define VK_F18     0x81
#define VK_F19     0x82
#define VK_F20     0x83
#define VK_F21     0x84
#define VK_F22     0x85
#define VK_F23     0x86
#define VK_F24     0x87
#endif
#endif // !_WIN32

namespace micdup {

struct HotkeySettings {
#ifdef __APPLE__
    uint32_t modifiers = 0x0C; // MOD_WIN | MOD_SHIFT (Cmd+Shift)
#else
    uint32_t modifiers = 0x06; // MOD_CONTROL | MOD_SHIFT (Ctrl+Shift)
#endif
    uint32_t key       = 0x20; // VK_SPACE
    bool     enabled   = true;
};

struct WhisperSettings {
    std::string model    = "base";
    std::string language = "en";
};

struct BehaviorSettings {
    bool auto_paste        = true;
    bool show_notifications = true;
};

struct AppSettings {
    HotkeySettings   hotkey;
    WhisperSettings   whisper;
    BehaviorSettings  behavior;
};

/// Load settings from disk (returns defaults if missing).
AppSettings settings_load();

/// Save settings to disk.
void settings_save(const AppSettings& s);

/// Returns the app data directory (creates it if needed).
#ifdef _WIN32
std::wstring get_appdata_dir();
std::wstring get_models_dir();
#elif defined(__APPLE__)
std::string get_appdata_dir();
std::string get_models_dir();
#endif

/// Returns the current compiled-in version string.
const char* app_version();

/// Format modifier flags as human-readable string (e.g. "Ctrl + Shift").
std::string format_modifiers(uint32_t mods);

/// Format full hotkey as human-readable string (e.g. "Ctrl + Shift + Space").
std::string format_hotkey(const HotkeySettings& hk);

/// Map a VK code to a display name.
std::string vk_to_string(uint32_t vk);

} // namespace micdup
