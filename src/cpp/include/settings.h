#pragma once

#include <string>
#include <cstdint>

namespace micdup {

struct HotkeySettings {
    uint32_t modifiers = 0x06; // MOD_CONTROL | MOD_SHIFT
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

/// Load settings from %APPDATA%\MicDup\settings.json (returns defaults if missing).
AppSettings settings_load();

/// Save settings to %APPDATA%\MicDup\settings.json.
void settings_save(const AppSettings& s);

/// Returns %APPDATA%\MicDup  (creates it if needed).
std::wstring get_appdata_dir();

/// Returns %LOCALAPPDATA%\MicDup\Models  (creates it if needed).
std::wstring get_models_dir();

/// Format modifier flags as human-readable string (e.g. "Ctrl + Shift").
std::string format_modifiers(uint32_t mods);

/// Format full hotkey as human-readable string (e.g. "Ctrl + Shift + Space").
std::string format_hotkey(const HotkeySettings& hk);

/// Map a VK code to a display name.
std::string vk_to_string(uint32_t vk);

} // namespace micdup
