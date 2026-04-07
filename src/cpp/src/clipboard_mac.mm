#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#include "clipboard.h"
#include "log.h"

namespace micdup {

bool clipboard_set_text(const std::string& text) {
    @autoreleasepool {
        if (text.empty()) return false;

        NSPasteboard* pb = [NSPasteboard generalPasteboard];
        [pb clearContents];
        NSString* nsText = [NSString stringWithUTF8String:text.c_str()];
        BOOL ok = [pb setString:nsText forType:NSPasteboardTypeString];

        if (ok) {
            log_info("Copied {} chars to clipboard", text.size());
        } else {
            log_error("Failed to copy to clipboard");
        }
        return ok;
    }
}

bool is_foreground_text_input() {
    return true;
}

void clipboard_autopaste() {
    // Dispatch to main thread with delay to let hotkey modifiers release
    // and target app regain focus
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 400 * NSEC_PER_MSEC),
                   dispatch_get_main_queue(), ^{
        @autoreleasepool {
            // Use AppleScript to simulate Cmd+V — most reliable method on macOS
            NSString* script = @"tell application \"System Events\" to keystroke \"v\" using command down";
            NSAppleScript* appleScript = [[NSAppleScript alloc] initWithSource:script];
            NSDictionary* errorDict = nil;
            [appleScript executeAndReturnError:&errorDict];

            if (errorDict) {
                NSString* errMsg = [errorDict objectForKey:NSAppleScriptErrorMessage];
                log_error("Auto-paste AppleScript failed: {}",
                          errMsg ? [errMsg UTF8String] : "unknown error");
            } else {
                log_info("Auto-paste executed (Cmd+V via AppleScript)");
            }
        }
    });
}

} // namespace micdup
