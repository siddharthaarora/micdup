#pragma once

#include <string>
#include <functional>

namespace micdup {

/// Ensure the named Whisper GGML model is present in the models directory.
/// Downloads from Hugging Face if missing.
/// `progress_cb` receives bytes-downloaded so far (0 = starting, -1 = done).
/// Returns the full path to the model file (UTF-8).
std::string ensure_model(const std::string& model_name,
                         std::function<void(int64_t)> progress_cb = nullptr);

/// Returns the Hugging Face URL for a given model name.
std::string model_url(const std::string& model_name);

} // namespace micdup
