#pragma once

#include <string>
#include <vector>
#include <cstdint>

namespace micdup {

#ifdef _WIN32
/// Start recording from the default microphone.
/// Writes 16 kHz / mono / 16-bit PCM WAV to `output_path`.
bool audio_start_recording(const std::wstring& output_path);

/// Stop recording and finalise the WAV file.  Returns the file path.
std::wstring audio_stop_recording();
#elif defined(__APPLE__)
/// Start recording from the default microphone.
/// Writes 16 kHz / mono / 16-bit PCM WAV to `output_path`.
bool audio_start_recording(const std::string& output_path);

/// Stop recording and finalise the WAV file.  Returns the file path.
std::string audio_stop_recording();
#endif

/// True while recording is active.
bool audio_is_recording();

} // namespace micdup
