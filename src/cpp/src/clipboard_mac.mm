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
    // Dispatch to main thread with delay so hotkey modifiers (Cmd+Shift)
    // have been fully released and the target app has regained focus.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC),
                   dispatch_get_main_queue(), ^{
        @autoreleasepool {
            CGEventSourceRef source =
                CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
            if (!source) {
                log_error("Auto-paste: failed to create event source");
                return;
            }

            // First, release all modifier keys to clear any stuck state
            CGEventRef flagsClear = CGEventCreate(source);
            CGEventSetFlags(flagsClear, (CGEventFlags)0);
            CGEventPost(kCGHIDEventTap, flagsClear);
            CFRelease(flagsClear);

            // Small delay after clearing flags
            usleep(50000); // 50ms

            // Key down: V with Command
            CGEventRef keyDown = CGEventCreateKeyboardEvent(source, kVK_ANSI_V, true);
            CGEventSetFlags(keyDown, kCGEventFlagMaskCommand);
            CGEventPost(kCGHIDEventTap, keyDown);
            CFRelease(keyDown);

            // Small delay between down and up
            usleep(20000); // 20ms

            // Key up: V with Command
            CGEventRef keyUp = CGEventCreateKeyboardEvent(source, kVK_ANSI_V, false);
            CGEventSetFlags(keyUp, kCGEventFlagMaskCommand);
            CGEventPost(kCGHIDEventTap, keyUp);
            CFRelease(keyUp);

            CFRelease(source);
            log_info("Auto-paste executed (Cmd+V)");
        }
    });
}

} // namespace micdup
