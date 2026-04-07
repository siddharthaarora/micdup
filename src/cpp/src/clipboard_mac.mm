#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#include "clipboard.h"
#include "log.h"

#include <unistd.h>

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
    // On macOS we always attempt paste — accessibility will gate it
    return true;
}

void clipboard_autopaste() {
    @autoreleasepool {
        // Delay to let clipboard settle and target app regain focus
        usleep(200000); // 200ms

        // Simulate Cmd+V using CGEvents
        CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
        if (!source) {
            log_error("Failed to create CGEventSource for paste");
            return;
        }

        CGEventRef vDown = CGEventCreateKeyboardEvent(source, (CGKeyCode)kVK_ANSI_V, true);
        CGEventRef vUp   = CGEventCreateKeyboardEvent(source, (CGKeyCode)kVK_ANSI_V, false);

        CGEventSetFlags(vDown, kCGEventFlagMaskCommand);
        CGEventSetFlags(vUp,   kCGEventFlagMaskCommand);

        CGEventPost(kCGAnnotatedSessionEventTap, vDown);
        CGEventPost(kCGAnnotatedSessionEventTap, vUp);

        CFRelease(vDown);
        CFRelease(vUp);
        CFRelease(source);

        log_info("Auto-paste executed (Cmd+V)");
    }
}

} // namespace micdup
