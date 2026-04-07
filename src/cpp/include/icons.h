#pragma once

#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#endif

namespace micdup {

#ifdef _WIN32
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

#elif defined(__APPLE__)
/// Create a menu bar icon for idle state.  Returns NSImage* (caller owns).
void* create_idle_icon();

/// Create a menu bar icon for recording state.  Returns NSImage*.
void* create_recording_icon();

/// Create a menu bar icon for processing animation.  Returns NSImage*.
void* create_processing_icon(int frame);

/// Create a menu bar icon for success state.  Returns NSImage*.
void* create_success_icon();

/// Create a menu bar icon for error state.  Returns NSImage*.
void* create_error_icon();
#endif

} // namespace micdup
