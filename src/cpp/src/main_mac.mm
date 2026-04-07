#import <Cocoa/Cocoa.h>
#include "micdup.h"

int main(int argc, const char* argv[]) {
    @autoreleasepool {
        // Check for --updated flag
        bool just_updated = false;
        for (int i = 1; i < argc; i++) {
            if (strcmp(argv[i], "--updated") == 0) just_updated = true;
        }

        // Initialise logging
        auto appdata = micdup::get_appdata_dir();
        micdup::log_init(appdata);
        micdup::log_info("MicDup v{} starting...", micdup::app_version());

        int exit_code = micdup::app_run(just_updated);

        micdup::log_info("MicDup shutting down");
        micdup::log_shutdown();
        return exit_code;
    }
}
