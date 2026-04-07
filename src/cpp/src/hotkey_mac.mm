#import <Carbon/Carbon.h>
#include "hotkey.h"
#include "settings.h"
#include "log.h"

namespace micdup {

static EventHotKeyRef  g_hotkey_ref = nullptr;
static EventHandlerRef g_handler_ref = nullptr;
static bool            g_registered = false;
static std::function<void()> g_callback;

// ── Map portable VK codes to macOS Carbon key codes ─────────────────────

static UInt32 vk_to_carbon(uint32_t vk) {
    // Letters A-Z: VK codes match ASCII ('A'=0x41), Carbon uses kVK_ANSI_*
    if (vk >= 'A' && vk <= 'Z') {
        // Carbon key codes for A-Z (not in alphabetical order)
        static const UInt32 map[] = {
            kVK_ANSI_A, kVK_ANSI_B, kVK_ANSI_C, kVK_ANSI_D, kVK_ANSI_E,
            kVK_ANSI_F, kVK_ANSI_G, kVK_ANSI_H, kVK_ANSI_I, kVK_ANSI_J,
            kVK_ANSI_K, kVK_ANSI_L, kVK_ANSI_M, kVK_ANSI_N, kVK_ANSI_O,
            kVK_ANSI_P, kVK_ANSI_Q, kVK_ANSI_R, kVK_ANSI_S, kVK_ANSI_T,
            kVK_ANSI_U, kVK_ANSI_V, kVK_ANSI_W, kVK_ANSI_X, kVK_ANSI_Y,
            kVK_ANSI_Z
        };
        return map[vk - 'A'];
    }
    // Numbers 0-9
    if (vk >= '0' && vk <= '9') {
        static const UInt32 map[] = {
            kVK_ANSI_0, kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4,
            kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9
        };
        return map[vk - '0'];
    }
    // Special keys
    switch (vk) {
        case 0x20: return kVK_Space;     // VK_SPACE
        case 0x0D: return kVK_Return;    // VK_RETURN
        case 0x09: return kVK_Tab;       // VK_TAB
        case 0x1B: return kVK_Escape;    // VK_ESCAPE
        case 0x08: return kVK_Delete;    // VK_BACK (backspace)
        case 0x2E: return kVK_ForwardDelete; // VK_DELETE
        case 0x24: return kVK_Home;      // VK_HOME
        case 0x23: return kVK_End;       // VK_END
        // Function keys: VK_F1=0x70 through VK_F12=0x7B
        case 0x70: return kVK_F1;
        case 0x71: return kVK_F2;
        case 0x72: return kVK_F3;
        case 0x73: return kVK_F4;
        case 0x74: return kVK_F5;
        case 0x75: return kVK_F6;
        case 0x76: return kVK_F7;
        case 0x77: return kVK_F8;
        case 0x78: return kVK_F9;
        case 0x79: return kVK_F10;
        case 0x7A: return kVK_F11;
        case 0x7B: return kVK_F12;
        default: return vk; // pass through
    }
}

// ── Map portable modifier flags to Carbon modifier flags ────────────────

static UInt32 mods_to_carbon(uint32_t mods) {
    UInt32 carbon = 0;
    if (mods & MOD_CONTROL) carbon |= controlKey;
    if (mods & MOD_SHIFT)   carbon |= shiftKey;
    if (mods & MOD_ALT)     carbon |= optionKey;
    if (mods & MOD_WIN)     carbon |= cmdKey;
    return carbon;
}

// ── Carbon event handler ────────────────────────────────────────────────

static OSStatus hotkey_handler(EventHandlerCallRef, EventRef event, void*) {
    if (g_callback) {
        g_callback();
    }
    return noErr;
}

// ── Public API ──────────────────────────────────────────────────────────

void hotkey_set_callback(std::function<void()> callback) {
    g_callback = std::move(callback);
}

bool hotkey_register(uint32_t modifiers, uint32_t vk) {
    if (g_registered) {
        log_warn("Hotkey already registered");
        return true;
    }

    // Install the Carbon event handler if not done yet
    if (!g_handler_ref) {
        EventTypeSpec eventType = { kEventClassKeyboard, kEventHotKeyPressed };
        InstallApplicationEventHandler(&hotkey_handler, 1, &eventType, nullptr, &g_handler_ref);
    }

    EventHotKeyID hotKeyID = { 'MDUP', 1 };
    UInt32 carbonKey  = vk_to_carbon(vk);
    UInt32 carbonMods = mods_to_carbon(modifiers);

    OSStatus status = RegisterEventHotKey(carbonKey, carbonMods, hotKeyID,
                                          GetApplicationEventTarget(), 0, &g_hotkey_ref);
    if (status != noErr) {
        log_error("Failed to register hotkey, error={}", (int)status);
        return false;
    }

    g_registered = true;
    log_info("Hotkey registered: mods=0x{:X} vk=0x{:X} (carbon key={} mods={})",
             modifiers, vk, carbonKey, carbonMods);
    return true;
}

void hotkey_unregister() {
    if (!g_registered) return;
    if (g_hotkey_ref) {
        UnregisterEventHotKey(g_hotkey_ref);
        g_hotkey_ref = nullptr;
    }
    g_registered = false;
    log_info("Hotkey unregistered");
}

bool hotkey_reregister(uint32_t modifiers, uint32_t vk) {
    hotkey_unregister();
    return hotkey_register(modifiers, vk);
}

} // namespace micdup
