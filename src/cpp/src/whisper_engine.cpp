#include "whisper_engine.h"
#include "log.h"

#include <whisper.h>
#include <fstream>
#include <vector>
#include <cstdint>
#include <cstring>

namespace micdup {

static struct whisper_context* g_ctx = nullptr;
static std::string g_language;

bool whisper_init(const std::string& model_path, const std::string& language) {
    if (g_ctx) whisper_shutdown();

    g_language = language;

    struct whisper_context_params cparams = whisper_context_default_params();
    // Let whisper.cpp auto-detect the best backend (CPU, Vulkan, CUDA)
    // based on what was compiled in.
    cparams.use_gpu = true;

    g_ctx = whisper_init_from_file_with_params(model_path.c_str(), cparams);
    if (!g_ctx) {
        log_error("Failed to load whisper model: {}", model_path);
        return false;
    }

    log_info("Whisper model loaded: {} (gpu={})", model_path,
             cparams.use_gpu ? "yes" : "no");
    return true;
}

// Read a 16 kHz mono 16-bit PCM WAV and return float samples in [-1, 1]
static bool load_wav_f32(const std::string& path, std::vector<float>& out) {
    std::ifstream f(path, std::ios::binary);
    if (!f) return false;

    // Skip to data chunk — our WAV writer places it at byte 44
    f.seekg(44);
    if (!f) return false;

    // Read rest of file as int16 samples
    std::vector<char> raw((std::istreambuf_iterator<char>(f)),
                           std::istreambuf_iterator<char>());

    size_t n_samples = raw.size() / 2;
    out.resize(n_samples);
    auto* samples = reinterpret_cast<const int16_t*>(raw.data());
    for (size_t i = 0; i < n_samples; i++) {
        out[i] = static_cast<float>(samples[i]) / 32768.0f;
    }
    return n_samples > 0;
}

std::string whisper_transcribe(const std::string& wav_path,
                               std::function<void(int)> progress_cb) {
    if (!g_ctx) {
        log_error("Whisper not initialised");
        return {};
    }

    std::vector<float> pcm;
    if (!load_wav_f32(wav_path, pcm)) {
        log_error("Failed to load WAV: {}", wav_path);
        return {};
    }

    if (pcm.size() < 100) {
        log_warn("Audio too short ({} samples)", pcm.size());
        return {};
    }

    struct whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.print_progress   = false;
    params.print_special    = false;
    params.print_realtime   = false;
    params.print_timestamps = false;
    params.single_segment   = false;
    params.temperature      = 0.0f;
    params.no_timestamps    = true;

    if (!g_language.empty() && g_language != "auto") {
        params.language = g_language.c_str();
    } else {
        params.language  = nullptr;
        params.detect_language = true;
    }

    // Progress callback
    if (progress_cb) {
        params.progress_callback = [](struct whisper_context*, struct whisper_state*,
                                      int progress, void* user_data) {
            auto* cb = static_cast<std::function<void(int)>*>(user_data);
            (*cb)(progress);
        };
        params.progress_callback_user_data = &progress_cb;
    }

    log_info("Starting transcription ({} samples, {:.1f}s)",
             pcm.size(), static_cast<float>(pcm.size()) / 16000.0f);

    int result = whisper_full(g_ctx, params, pcm.data(), static_cast<int>(pcm.size()));
    if (result != 0) {
        log_error("whisper_full failed: {}", result);
        return {};
    }

    // Collect segments
    std::string text;
    int n = whisper_full_n_segments(g_ctx);
    for (int i = 0; i < n; i++) {
        const char* seg = whisper_full_get_segment_text(g_ctx, i);
        if (seg) {
            if (!text.empty()) text += " ";
            text += seg;
        }
    }

    // Trim whitespace
    auto start = text.find_first_not_of(" \t\n\r");
    auto end   = text.find_last_not_of(" \t\n\r");
    if (start == std::string::npos) return {};
    text = text.substr(start, end - start + 1);

    log_info("Transcription complete: {} chars", text.size());
    return text;
}

void whisper_shutdown() {
    if (g_ctx) {
        whisper_free(g_ctx);
        g_ctx = nullptr;
        log_info("Whisper engine shut down");
    }
}

bool whisper_is_ready() {
    return g_ctx != nullptr;
}

} // namespace micdup
