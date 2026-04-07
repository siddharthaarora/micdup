#import <Cocoa/Cocoa.h>
#include "app.h"
#include "micdup.h"

#include <thread>
#include <string>
#include <filesystem>

namespace micdup {

// ── Application state ───────────────────────────────────────────────────

enum class AppState { Idle, Recording, Processing };

static AppSettings  g_settings;
static AppState     g_state = AppState::Idle;
static std::string  g_recording_path;
static bool         g_running = true;

// ── Forward declarations ────────────────────────────────────────────────

static void toggle_recording();
static void start_recording();
static void stop_and_transcribe();
static void on_settings();

} // namespace micdup

// ── App Delegate ────────────────────────────────────────────────────────

@interface MicDupAppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation MicDupAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification*)notification {
    using namespace micdup;

    g_settings = settings_load();

    // Initialise tray (menu bar status item)
    TrayCallbacks cb;
    cb.on_start_stop    = []() { toggle_recording(); };
    cb.on_settings      = []() { on_settings(); };
    cb.on_exit          = []() {
        g_running = false;
        [NSApp terminate:nil];
    };

    if (!tray_init(cb)) {
        log_error("Failed to initialise tray");
        NSAlert* alert = [[NSAlert alloc] init];
        alert.messageText = @"MicDup Error";
        alert.informativeText = @"Failed to initialise menu bar icon.";
        alert.alertStyle = NSAlertStyleCritical;
        [alert runModal];
        [NSApp terminate:nil];
        return;
    }

    // Ensure the whisper model is downloaded, then load it
    tray_notify("MicDup", "Loading speech model...");
    auto model_path = ensure_model(g_settings.whisper.model, [](int64_t bytes) {
        if (bytes == 0) log_info("Model download started");
        else if (bytes == -1) log_info("Model download complete");
    });

    if (model_path.empty()) {
        log_error("Failed to download model");
        NSAlert* alert = [[NSAlert alloc] init];
        alert.messageText = @"MicDup Error";
        alert.informativeText = @"Failed to download Whisper model.\nCheck your internet connection.";
        alert.alertStyle = NSAlertStyleCritical;
        [alert runModal];
        tray_shutdown();
        [NSApp terminate:nil];
        return;
    }

    if (!whisper_init(model_path, g_settings.whisper.language)) {
        log_error("Failed to load whisper model");
        NSAlert* alert = [[NSAlert alloc] init];
        alert.messageText = @"MicDup Error";
        alert.informativeText = @"Failed to load speech model.";
        alert.alertStyle = NSAlertStyleCritical;
        [alert runModal];
        tray_shutdown();
        [NSApp terminate:nil];
        return;
    }

    // Register global hotkey
    hotkey_set_callback([]() {
        // Ensure we're on the main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            toggle_recording();
        });
    });
    hotkey_register(g_settings.hotkey.modifiers, g_settings.hotkey.key);

    tray_set_state(TrayState::Idle);
    tray_notify("MicDup", "Ready! Press Cmd+Shift+Space to record.");

    log_info("App initialised, entering run loop");
}

- (void)applicationWillTerminate:(NSNotification*)notification {
    using namespace micdup;
    hotkey_unregister();
    whisper_shutdown();
    tray_shutdown();
}

@end

// ── App entry ───────────────────────────────────────────────────────────

namespace micdup {

int app_run(bool just_updated) {
    @autoreleasepool {
        NSApplication* app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];

        MicDupAppDelegate* delegate = [[MicDupAppDelegate alloc] init];
        [app setDelegate:delegate];

        [app run];
        return 0;
    }
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
    NSString* tmpDir = NSTemporaryDirectory();
    auto tick = [[NSProcessInfo processInfo] systemUptime];
    g_recording_path = std::string([tmpDir UTF8String]) + "micdup_" +
                       std::to_string((uint64_t)(tick * 1000)) + ".wav";

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
        auto text = whisper_transcribe(audio_path);

        // Clean up audio file
        std::error_code ec2;
        std::filesystem::remove(audio_path, ec2);

        if (text.empty()) {
            log_warn("Transcription returned empty");
            dispatch_async(dispatch_get_main_queue(), ^{
                g_state = AppState::Idle;
                tray_set_state(TrayState::Error);
            });
            return;
        }

        // Copy to clipboard
        clipboard_set_text(text);

        // Auto-paste if enabled
        if (g_settings.behavior.auto_paste && is_foreground_text_input()) {
            clipboard_autopaste();
            log_info("Auto-pasted transcription");
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            g_state = AppState::Idle;
            tray_set_state(TrayState::Success);
        });
    }).detach();
}

// ── Settings ────────────────────────────────────────────────────────────

static void on_settings() {
    AppSettings old = g_settings;
    if (show_settings_dialog(g_settings)) {
        // Re-register hotkey if changed
        if (old.hotkey.modifiers != g_settings.hotkey.modifiers ||
            old.hotkey.key != g_settings.hotkey.key) {
            hotkey_reregister(g_settings.hotkey.modifiers, g_settings.hotkey.key);
        }

        // Reload whisper if model changed
        if (old.whisper.model != g_settings.whisper.model) {
            tray_notify("MicDup", "Loading new model...");
            whisper_shutdown();
            auto path = ensure_model(g_settings.whisper.model);
            if (!path.empty()) {
                whisper_init(path, g_settings.whisper.language);
            }
            tray_notify("MicDup", "Model loaded.");
        }

        log_info("Settings applied");
    }
}

} // namespace micdup
