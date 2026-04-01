#include "micdup.h"
#include <windows.h>
#include <string>

int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE, LPWSTR lpCmdLine, int) {
    // Check for --updated flag
    bool just_updated = false;
    if (lpCmdLine) {
        std::wstring args(lpCmdLine);
        just_updated = args.find(L"--updated") != std::wstring::npos;
    }

    // Initialise logging
    auto appdata = micdup::get_appdata_dir();
    micdup::log_init(appdata);
    micdup::log_info("MicDup v{} starting...", micdup::app_version());

    int exit_code = micdup::app_run(hInstance, just_updated);

    micdup::log_info("MicDup shutting down");
    micdup::log_shutdown();
    return exit_code;
}
