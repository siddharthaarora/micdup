#include "settings.h"
#include "log.h"

#import <Foundation/Foundation.h>
#include <fstream>
#include <sstream>
#include <filesystem>

namespace micdup {

// ── Path helpers ────────────────────────────────────────────────────────

std::string get_appdata_dir() {
    @autoreleasepool {
        NSArray* paths = NSSearchPathForDirectoriesInDomains(
            NSApplicationSupportDirectory, NSUserDomainMask, YES);
        NSString* appSupport = [paths firstObject];
        std::string dir = std::string([appSupport UTF8String]) + "/MicDup";
        std::filesystem::create_directories(dir);
        return dir;
    }
}

std::string get_models_dir() {
    auto dir = get_appdata_dir() + "/Models";
    std::filesystem::create_directories(dir);
    return dir;
}

static std::string settings_path() {
    return get_appdata_dir() + "/settings.json";
}

// ── Tiny JSON reader ────────────────────────────────────────────────────

static std::string trim(const std::string& s) {
    auto a = s.find_first_not_of(" \t\r\n\"");
    auto b = s.find_last_not_of(" \t\r\n\"");
    return (a == std::string::npos) ? "" : s.substr(a, b - a + 1);
}

static std::string json_value(const std::string& json, const std::string& key) {
    auto pos = json.find("\"" + key + "\"");
    if (pos == std::string::npos) return "";
    pos = json.find(':', pos);
    if (pos == std::string::npos) return "";
    pos++;
    while (pos < json.size() && (json[pos] == ' ' || json[pos] == '\t')) pos++;
    if (pos >= json.size()) return "";

    if (json[pos] == 't') return "true";
    if (json[pos] == 'f') return "false";
    if (json[pos] >= '0' && json[pos] <= '9') {
        auto end = json.find_first_of(",}\n", pos);
        return trim(json.substr(pos, end - pos));
    }
    if (json[pos] == '"') {
        auto end = json.find('"', pos + 1);
        return json.substr(pos + 1, end - pos - 1);
    }
    return "";
}

// ── Load / Save ─────────────────────────────────────────────────────────

AppSettings settings_load() {
    AppSettings s;
    auto path = settings_path();

    std::ifstream f(path);
    if (!f.is_open()) {
        log_info("No settings file found, using defaults");
        return s;
    }

    std::string json((std::istreambuf_iterator<char>(f)),
                      std::istreambuf_iterator<char>());

    // Hotkey — on macOS: "Command" maps to MOD_WIN, "Option" maps to MOD_ALT
    auto mods_str = json_value(json, "modifiers");
    if (!mods_str.empty()) {
        uint32_t m = 0;
        if (mods_str.find("Control") != std::string::npos) m |= MOD_CONTROL;
        if (mods_str.find("Shift")   != std::string::npos) m |= MOD_SHIFT;
        if (mods_str.find("Option")  != std::string::npos ||
            mods_str.find("Alt")     != std::string::npos) m |= MOD_ALT;
        if (mods_str.find("Command") != std::string::npos ||
            mods_str.find("Cmd")     != std::string::npos ||
            mods_str.find("Win")     != std::string::npos) m |= MOD_WIN;
        s.hotkey.modifiers = m;
    }
    auto key_str = json_value(json, "key");
    if (!key_str.empty()) {
        if (key_str == "Space") s.hotkey.key = VK_SPACE;
        else if (key_str.size() == 1 && key_str[0] >= 'A' && key_str[0] <= 'Z')
            s.hotkey.key = static_cast<uint32_t>(key_str[0]);
        else if (key_str.size() == 1 && key_str[0] >= 'a' && key_str[0] <= 'z')
            s.hotkey.key = static_cast<uint32_t>(key_str[0] - 32);
    }

    // Whisper
    auto model = json_value(json, "model");
    if (!model.empty()) s.whisper.model = model;
    auto lang = json_value(json, "language");
    if (!lang.empty()) s.whisper.language = lang;

    // Behavior
    auto ap = json_value(json, "autoPaste");
    if (ap == "false") s.behavior.auto_paste = false;
    auto sn = json_value(json, "showNotifications");
    if (sn == "false") s.behavior.show_notifications = false;

    log_info("Settings loaded");
    return s;
}

void settings_save(const AppSettings& s) {
    auto path = settings_path();

    // Build modifiers string (macOS names)
    std::string mods;
    if (s.hotkey.modifiers & MOD_WIN)     { if (!mods.empty()) mods += "+"; mods += "Command"; }
    if (s.hotkey.modifiers & MOD_CONTROL) { if (!mods.empty()) mods += "+"; mods += "Control"; }
    if (s.hotkey.modifiers & MOD_ALT)     { if (!mods.empty()) mods += "+"; mods += "Option"; }
    if (s.hotkey.modifiers & MOD_SHIFT)   { if (!mods.empty()) mods += "+"; mods += "Shift"; }

    std::string key_name = vk_to_string(s.hotkey.key);

    std::ostringstream json;
    json << "{\n"
         << "  \"modifiers\": \"" << mods << "\",\n"
         << "  \"key\": \"" << key_name << "\",\n"
         << "  \"model\": \"" << s.whisper.model << "\",\n"
         << "  \"language\": \"" << s.whisper.language << "\",\n"
         << "  \"autoPaste\": " << (s.behavior.auto_paste ? "true" : "false") << ",\n"
         << "  \"showNotifications\": " << (s.behavior.show_notifications ? "true" : "false") << "\n"
         << "}\n";

    std::ofstream f(path);
    f << json.str();
    log_info("Settings saved");
}

// ── Display helpers ─────────────────────────────────────────────────────

std::string vk_to_string(uint32_t vk) {
    switch (vk) {
        case VK_SPACE:  return "Space";
        case VK_RETURN: return "Enter";
        case VK_TAB:    return "Tab";
        case VK_ESCAPE: return "Escape";
        case VK_BACK:   return "Backspace";
        case VK_DELETE: return "Delete";
        case VK_HOME:   return "Home";
        case VK_END:    return "End";
        default:
            if (vk >= 'A' && vk <= 'Z') return std::string(1, static_cast<char>(vk));
            if (vk >= '0' && vk <= '9') return std::string(1, static_cast<char>(vk));
            if (vk >= VK_F1 && vk <= VK_F24) return "F" + std::to_string(vk - VK_F1 + 1);
            return std::format("0x{:02X}", vk);
    }
}

std::string format_modifiers(uint32_t mods) {
    std::string r;
    if (mods & MOD_WIN)     { if (!r.empty()) r += " + "; r += "Cmd"; }
    if (mods & MOD_CONTROL) { if (!r.empty()) r += " + "; r += "Ctrl"; }
    if (mods & MOD_ALT)     { if (!r.empty()) r += " + "; r += "Option"; }
    if (mods & MOD_SHIFT)   { if (!r.empty()) r += " + "; r += "Shift"; }
    return r;
}

std::string format_hotkey(const HotkeySettings& hk) {
    auto m = format_modifiers(hk.modifiers);
    auto k = vk_to_string(hk.key);
    return m.empty() ? k : m + " + " + k;
}

} // namespace micdup
