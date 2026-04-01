#include "app.h"
#include "micdup.h"

#include <thread>
#include <string>
#include <filesystem>

namespace micdup {

static std::string wstr_to_utf8(const std::wstring& wstr) {
    if (wstr.empty()) return {};
    int size = WideCharToMultiByte(CP_UTF8, 0, wstr.data(), (int)wstr.size(), nullptr, 0, nullptr, nullptr);
    std::string result(size, '\0');
    WideCharToMultiByte(CP_UTF8, 0, wstr.data(), (int)wstr.size(), result.data(), size, nullptr, nullptr);
    return result;
}

// ── Application state ───────────────────────────────────────────────────

enum class AppState { Idle, Recording, Processing };

static AppSettings  g_settings;
static AppState     g_state = AppState::Idle;
static std::wstring g_recording_path;
static bool         g_running = true;

// ── Forward declarations ────────────────────────────────────────────────

static void toggle_recording();
static void start_recording();
static void stop_and_transcribe();
static void on_settings();
static void on_check_updates(bool silent);

// ── App entry ───────────────────────────────────────────────────────────

int app_run(HINSTANCE hInstance, bool just_updated) {
    g_settings = settings_load();

    // Initialise tray
    TrayCallbacks cb;
    cb.on_start_stop    = []() { toggle_recording(); };
    cb.on_settings      = []() { on_settings(); };
    cb.on_check_updates = []() { on_check_updates(false); };
    cb.on_exit          = []() { g_running = false; PostQuitMessage(0); };

    if (!tray_init(hInstance, cb)) {
        log_error("Failed to initialise tray");
        MessageBoxW(nullptr, L"Failed to initialise system tray.", L"MicDup Error", MB_ICONERROR);
        return 1;
    }

    // Ensure the whisper model is downloaded, then load it
    tray_notify(L"MicDup", L"Loading speech model...");
    auto model_path = ensure_model(g_settings.whisper.model, [](int64_t bytes) {
        // Could update a progress UI here; for now just log
        if (bytes == 0) log_info("Model download started");
        else if (bytes == -1) log_info("Model download complete");
    });

    if (model_path.empty()) {
        log_error("Failed to download model");
        MessageBoxW(nullptr, L"Failed to download Whisper model.\nCheck your internet connection.",
                    L"MicDup Error", MB_ICONERROR);
        tray_shutdown();
        return 1;
    }

    if (!whisper_init(model_path, g_settings.whisper.language)) {
        log_error("Failed to load whisper model");
        MessageBoxW(nullptr, L"Failed to load speech model.", L"MicDup Error", MB_ICONERROR);
        tray_shutdown();
        return 1;
    }

    // Register global hotkey
    hotkey_register(tray_hwnd(), g_settings.hotkey.modifiers, g_settings.hotkey.key);

    tray_set_state(TrayState::Idle);

    if (just_updated) {
        auto msg = std::wstring(L"Successfully updated to v") +
                   std::wstring(MICDUP_VERSION, MICDUP_VERSION + strlen(MICDUP_VERSION)) + L"!";
        tray_notify(L"MicDup", msg.c_str());
    } else {
        tray_notify(L"MicDup", L"Ready! Press Ctrl+Shift+Space to record.");
    }

    // Background update check after 5 seconds
    std::thread([]() {
        Sleep(5000);
        on_check_updates(true);
    }).detach();

    log_info("App initialised, entering message loop");

    // Win32 message loop
    MSG msg;
    while (GetMessageW(&msg, nullptr, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }

    // Cleanup
    hotkey_unregister(tray_hwnd());
    whisper_shutdown();
    tray_shutdown();
    return 0;
}

// ── Recording logic ─────────────────────────────────────────────────────

static void toggle_recording() {
    switch (g_state) {
        case AppState::Idle:
            start_recording();
            break;
        case AppState::Recording:
            stop_and_transcribe();
            break;
        case AppState::Processing:
            log_debug("Ignoring input while processing");
            break;
    }
}

static void start_recording() {
    if (g_state != AppState::Idle) return;

    // Generate temp file path
    wchar_t tmp[MAX_PATH]{};
    GetTempPathW(MAX_PATH, tmp);
    g_recording_path = std::wstring(tmp) + L"micdup_" + std::to_wstring(GetTickCount64()) + L".wav";

    if (!audio_start_recording(g_recording_path)) {
        log_error("Failed to start recording");
        tray_set_state(TrayState::Error);
        return;
    }

    g_state = AppState::Recording;
    tray_set_state(TrayState::Recording);
    log_info("Recording started");
}

static void stop_and_transcribe() {
    if (g_state != AppState::Recording) return;

    g_state = AppState::Processing;
    tray_set_state(TrayState::Processing);

    auto audio_path = audio_stop_recording();
    log_info("Recording stopped");

    // Check file size
    std::error_code ec;
    auto fsize = std::filesystem::file_size(audio_path, ec);
    if (ec || fsize < 1000) {
        log_warn("Audio file too small ({} bytes)", fsize);
        g_state = AppState::Idle;
        tray_set_state(TrayState::Error);
        std::filesystem::remove(audio_path, ec);
        return;
    }

    // Transcribe on a background thread so the UI stays responsive
    std::thread([audio_path]() {
        auto wav_utf8 = wstr_to_utf8(audio_path);
        auto text = whisper_transcribe(wav_utf8);

        // Clean up audio file
        std::error_code ec2;
        std::filesystem::remove(audio_path, ec2);

        if (text.empty()) {
            log_warn("Transcription returned empty");
            g_state = AppState::Idle;
            tray_set_state(TrayState::Error);
            return;
        }

        // Copy to clipboard
        clipboard_set_text(text);

        // Auto-paste if enabled
        if (g_settings.behavior.auto_paste && is_foreground_text_input()) {
            clipboard_autopaste();
            log_info("Auto-pasted transcription");
        }

        g_state = AppState::Idle;
        tray_set_state(TrayState::Success);
    }).detach();
}

// ── Settings ────────────────────────────────────────────────────────────

static void on_settings() {
    AppSettings old = g_settings;
    if (show_settings_dialog(tray_hwnd(), g_settings)) {
        // Re-register hotkey if changed
        if (old.hotkey.modifiers != g_settings.hotkey.modifiers ||
            old.hotkey.key != g_settings.hotkey.key) {
            hotkey_reregister(tray_hwnd(), g_settings.hotkey.modifiers, g_settings.hotkey.key);
        }

        // Reload whisper if model changed
        if (old.whisper.model != g_settings.whisper.model) {
            tray_notify(L"MicDup", L"Loading new model...");
            whisper_shutdown();
            auto path = ensure_model(g_settings.whisper.model);
            if (!path.empty()) {
                whisper_init(path, g_settings.whisper.language);
            }
            tray_notify(L"MicDup", L"Model loaded.");
        }

        log_info("Settings applied");
    }
}

// ── Update check ────────────────────────────────────────────────────────

static void on_check_updates(bool silent) {
    auto release = check_for_update();
    if (!release) {
        if (!silent) {
            auto msg = std::wstring(L"You're running the latest version (v") +
                       std::wstring(MICDUP_VERSION, MICDUP_VERSION + strlen(MICDUP_VERSION)) + L").";
            MessageBoxW(nullptr, msg.c_str(), L"MicDup", MB_ICONINFORMATION);
        }
        return;
    }

    auto tag_w = std::wstring(release->tag.begin(), release->tag.end());
    auto ver_w = std::wstring(MICDUP_VERSION, MICDUP_VERSION + strlen(MICDUP_VERSION));
    auto msg = L"A new version is available: " + tag_w +
               L"\nCurrent version: v" + ver_w +
               L"\n\nDownload and install the update?";

    if (MessageBoxW(nullptr, msg.c_str(), L"MicDup Update", MB_YESNO | MB_ICONINFORMATION) != IDYES)
        return;

    tray_notify(L"MicDup", L"Downloading update...");
    if (download_and_apply_update(*release)) {
        PostQuitMessage(0);
    } else {
        MessageBoxW(nullptr, L"Update failed. Try again later or download from GitHub.",
                    L"MicDup", MB_ICONWARNING);
    }
}

} // namespace micdup
