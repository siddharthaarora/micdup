#pragma once

#include <functional>
#include <cstdint>

#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#endif

namespace micdup {

#ifdef _WIN32
/// Register a global hotkey.  The callback fires on the message-loop thread.
bool hotkey_register(HWND hwnd, uint32_t modifiers, uint32_t vk);

/// Unregister the current hotkey.
void hotkey_unregister(HWND hwnd);

/// Re-register with a new key combination.
bool hotkey_reregister(HWND hwnd, uint32_t modifiers, uint32_t vk);

#elif defined(__APPLE__)
/// Set the callback invoked when the hotkey is pressed.
void hotkey_set_callback(std::function<void()> callback);

/// Register a global hotkey.
bool hotkey_register(uint32_t modifiers, uint32_t vk);

/// Unregister the current hotkey.
void hotkey_unregister();

/// Re-register with a new key combination.
bool hotkey_reregister(uint32_t modifiers, uint32_t vk);
#endif

} // namespace micdup
