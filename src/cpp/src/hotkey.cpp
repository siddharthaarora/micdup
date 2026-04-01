#include "hotkey.h"
#include "log.h"

namespace micdup {

static constexpr int HOTKEY_ID = 1;
static bool g_registered = false;

bool hotkey_register(HWND hwnd, uint32_t modifiers, uint32_t vk) {
    if (g_registered) {
        log_warn("Hotkey already registered");
        return true;
    }
    if (RegisterHotKey(hwnd, HOTKEY_ID, modifiers, vk)) {
        g_registered = true;
        log_info("Hotkey registered: mods=0x{:X} vk=0x{:X}", modifiers, vk);
        return true;
    }
    log_error("Failed to register hotkey, error={}", GetLastError());
    return false;
}

void hotkey_unregister(HWND hwnd) {
    if (!g_registered) return;
    UnregisterHotKey(hwnd, HOTKEY_ID);
    g_registered = false;
    log_info("Hotkey unregistered");
}

bool hotkey_reregister(HWND hwnd, uint32_t modifiers, uint32_t vk) {
    hotkey_unregister(hwnd);
    return hotkey_register(hwnd, modifiers, vk);
}

} // namespace micdup
