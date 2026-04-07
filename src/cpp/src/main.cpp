#include "micdup.h"
#include <windows.h>

int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE, LPWSTR, int) {
    // Initialise logging
    auto appdata = micdup::get_appdata_dir();
    micdup::log_init(appdata);
    micdup::log_info("MicDup v{} starting...", micdup::app_version());

    int exit_code = micdup::app_run(hInstance, false);

    micdup::log_info("MicDup shutting down");
    micdup::log_shutdown();
    return exit_code;
}
