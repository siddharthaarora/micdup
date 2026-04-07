#pragma once

#include "settings.h"

#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#endif

namespace micdup {

/// Show a modal settings dialog.
/// Returns true if the user clicked Save (settings are written to disk).
#ifdef _WIN32
bool show_settings_dialog(HWND parent, AppSettings& settings);
#elif defined(__APPLE__)
bool show_settings_dialog(AppSettings& settings);
#endif

} // namespace micdup
