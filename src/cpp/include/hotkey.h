#pragma once

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <functional>
#include <cstdint>

namespace micdup {

/// Register a global hotkey.  The callback fires on the message-loop thread.
bool hotkey_register(HWND hwnd, uint32_t modifiers, uint32_t vk);

/// Unregister the current hotkey.
void hotkey_unregister(HWND hwnd);

/// Re-register with a new key combination.
bool hotkey_reregister(HWND hwnd, uint32_t modifiers, uint32_t vk);

} // namespace micdup
