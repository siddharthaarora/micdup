#pragma once

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>

namespace micdup {

/// Create a 16x16 icon of a gray microphone (idle state).
HICON create_idle_icon();

/// Create a 16x16 icon of a red microphone (recording state).
HICON create_recording_icon();

/// Create a 16x16 icon of a rotating blue arc (processing animation).
HICON create_processing_icon(int frame);

/// Create a 16x16 icon of a green checkmark (success state).
HICON create_success_icon();

/// Create a 16x16 icon of a red X (error state).
HICON create_error_icon();

} // namespace micdup
