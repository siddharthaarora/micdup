#pragma once

#include <string>
#include <functional>

namespace micdup {

/// Initialise the Whisper engine with the given GGML model file.
/// Returns false if the model cannot be loaded.
bool whisper_init(const std::string& model_path, const std::string& language = "en");

/// Transcribe a 16 kHz mono 16-bit WAV file.  Returns the text.
/// `progress_cb` is called with 0..100 progress values (optional).
std::string whisper_transcribe(const std::string& wav_path,
                               std::function<void(int)> progress_cb = nullptr);

/// Release whisper resources.
void whisper_shutdown();

/// Returns true if the engine is loaded and ready.
bool whisper_is_ready();

} // namespace micdup
