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
    @autoreleasepool {
        NSRunningApplication* frontApp =
            [[NSWorkspace sharedWorkspace] frontmostApplication];
        return frontApp != nil;
    }
}

void clipboard_autopaste() {
    @autoreleasepool {
        // Short delay to ensure clipboard is settled
        usleep(100000); // 100ms

        // Simulate Cmd+V using CGEvents
        CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);

        CGEventRef cmdDown = CGEventCreateKeyboardEvent(source, (CGKeyCode)kVK_Command, true);
        CGEventRef vDown   = CGEventCreateKeyboardEvent(source, (CGKeyCode)kVK_ANSI_V, true);
        CGEventRef vUp     = CGEventCreateKeyboardEvent(source, (CGKeyCode)kVK_ANSI_V, false);
        CGEventRef cmdUp   = CGEventCreateKeyboardEvent(source, (CGKeyCode)kVK_Command, false);

        CGEventSetFlags(vDown, kCGEventFlagMaskCommand);
        CGEventSetFlags(vUp,   kCGEventFlagMaskCommand);

        CGEventPost(kCGHIDEventTap, cmdDown);
        CGEventPost(kCGHIDEventTap, vDown);
        CGEventPost(kCGHIDEventTap, vUp);
        CGEventPost(kCGHIDEventTap, cmdUp);

        CFRelease(cmdDown);
        CFRelease(vDown);
        CFRelease(vUp);
        CFRelease(cmdUp);
        CFRelease(source);

        log_info("Auto-paste executed (Cmd+V)");
    }
}

} // namespace micdup
