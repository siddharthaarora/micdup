#pragma once

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include "settings.h"

namespace micdup {

/// Show a modal settings dialog.
/// Returns true if the user clicked Save (settings are written to disk).
bool show_settings_dialog(HWND parent, AppSettings& settings);

} // namespace micdup
