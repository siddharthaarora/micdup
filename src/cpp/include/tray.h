#pragma once

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <functional>

namespace micdup {

enum class TrayState { Idle, Recording, Processing, Success, Error };

/// Callbacks the tray will invoke on user interaction.
struct TrayCallbacks {
    std::function<void()> on_start_stop;
    std::function<void()> on_settings;
    std::function<void()> on_check_updates;
    std::function<void()> on_exit;
};

/// Initialise the system tray icon (call from the message-loop thread).
bool tray_init(HINSTANCE hInstance, const TrayCallbacks& cb);

/// Update the tray icon/tooltip/menu to reflect a new state.
void tray_set_state(TrayState state);

/// Show a balloon notification.
void tray_notify(const wchar_t* title, const wchar_t* message);

/// Advance the processing-animation by one frame (call on a timer tick).
void tray_animate_tick();

/// Remove the tray icon and clean up.
void tray_shutdown();

/// Returns the hidden tray message window HWND.
HWND tray_hwnd();

} // namespace micdup
