#import <Cocoa/Cocoa.h>
#include "settings_dialog.h"
#include "log.h"

namespace micdup {

static const char* MODELS[] = {"tiny", "base", "small", "medium", "large"};
static constexpr int NUM_MODELS = 5;

static int model_index(const std::string& name) {
    for (int i = 0; i < NUM_MODELS; i++)
        if (name == MODELS[i]) return i;
    return 1; // default: base
}

bool show_settings_dialog(AppSettings& settings) {
    @autoreleasepool {
        // Activate the app so the window can come to front
        [NSApp activateIgnoringOtherApps:YES];

        // Create the settings window
        NSRect frame = NSMakeRect(0, 0, 380, 280);
        NSWindow* window = [[NSWindow alloc]
            initWithContentRect:frame
            styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
            backing:NSBackingStoreBuffered
            defer:NO];
        [window setTitle:@"MicDup Settings"];
        [window center];

        NSView* content = [window contentView];
        CGFloat y = 220;

        // ── Hotkey display ──────────────────────────────────────────────
        NSTextField* hkLabel = [NSTextField labelWithString:@"Hotkey:"];
        hkLabel.frame = NSMakeRect(20, y, 80, 20);
        [content addSubview:hkLabel];

        auto hkStr = format_hotkey(settings.hotkey);
        NSTextField* hkValue = [NSTextField labelWithString:
            [NSString stringWithUTF8String:hkStr.c_str()]];
        hkValue.frame = NSMakeRect(110, y, 200, 20);
        [content addSubview:hkValue];

        y -= 30;

        // Hotkey capture button
        __block uint32_t capMods = settings.hotkey.modifiers;
        __block uint32_t capKey  = settings.hotkey.key;
        __block bool capturing = false;

        NSButton* captureBtn = [NSButton buttonWithTitle:@"Press to change hotkey..."
            target:nil action:nil];
        captureBtn.frame = NSMakeRect(110, y, 200, 28);
        [content addSubview:captureBtn];

        // We'll use a local event monitor for key capture
        __block id keyMonitor = nil;
        captureBtn.target = captureBtn; // will be overridden below
        captureBtn.action = nil;

        // Use a simple click handler via NSButton subclass approach
        // For simplicity, we'll handle capture via the panel's key events

        y -= 50;

        // ── Model selector ──────────────────────────────────────────────
        NSTextField* modelLabel = [NSTextField labelWithString:@"Whisper Model:"];
        modelLabel.frame = NSMakeRect(20, y + 3, 90, 20);
        [content addSubview:modelLabel];

        NSPopUpButton* modelPopup = [[NSPopUpButton alloc]
            initWithFrame:NSMakeRect(110, y, 200, 28) pullsDown:NO];
        for (int i = 0; i < NUM_MODELS; i++) {
            [modelPopup addItemWithTitle:
                [NSString stringWithUTF8String:MODELS[i]]];
        }
        [modelPopup selectItemAtIndex:model_index(settings.whisper.model)];
        [content addSubview:modelPopup];

        y -= 40;

        // ── Auto-paste checkbox ─────────────────────────────────────────
        NSButton* autoPasteChk = [NSButton checkboxWithTitle:@"Auto-paste transcription"
            target:nil action:nil];
        autoPasteChk.frame = NSMakeRect(110, y, 220, 20);
        autoPasteChk.state = settings.behavior.auto_paste
            ? NSControlStateValueOn : NSControlStateValueOff;
        [content addSubview:autoPasteChk];

        y -= 50;

        // ── Save / Cancel buttons ───────────────────────────────────────
        __block bool saved = false;

        NSButton* saveBtn = [NSButton buttonWithTitle:@"Save" target:nil action:nil];
        saveBtn.frame = NSMakeRect(170, y, 80, 28);
        saveBtn.bezelStyle = NSBezelStyleRounded;
        saveBtn.keyEquivalent = @"\r"; // Enter key
        [content addSubview:saveBtn];

        NSButton* cancelBtn = [NSButton buttonWithTitle:@"Cancel" target:nil action:nil];
        cancelBtn.frame = NSMakeRect(260, y, 80, 28);
        cancelBtn.bezelStyle = NSBezelStyleRounded;
        cancelBtn.keyEquivalent = @"\033"; // Escape key
        [content addSubview:cancelBtn];

        // Button actions using blocks via NSApp modal session
        saveBtn.target = window;
        saveBtn.action = @selector(performClose:);

        cancelBtn.target = window;
        cancelBtn.action = @selector(performClose:);

        // Set up a delegate to distinguish save vs cancel
        // We'll use a simpler approach: run modal and check a flag

        // Capture hotkey: install a local key event monitor
        captureBtn.target = nil;
        // Override: use a simple block-based action
        // For hotkey capture, set up a local event monitor when button is clicked

        __block NSTextField* hkValueRef = hkValue;
        __block NSButton* captureBtnRef = captureBtn;

        // Use NSApp.nextEvent-based modal loop
        [window setDefaultButtonCell:[saveBtn cell]];

        // Override close to track which button was pressed
        __block bool closedBySave = false;

        // Replace button actions
        saveBtn.target = nil;
        saveBtn.action = nil;
        cancelBtn.target = nil;
        cancelBtn.action = nil;

        // Use a responder-based approach: make the window a modal panel
        [window makeKeyAndOrderFront:nil];

        // Run a modal session
        NSModalSession session = [NSApp beginModalSessionForWindow:window];
        NSInteger result;

        // Wire up button clicks using action dispatching
        saveBtn.target = NSApp;
        saveBtn.action = @selector(stopModalWithCode:);
        saveBtn.tag = NSModalResponseOK;

        cancelBtn.target = NSApp;
        cancelBtn.action = @selector(stopModalWithCode:);
        cancelBtn.tag = NSModalResponseCancel;

        // Wire capture button
        captureBtn.target = NSApp;
        captureBtn.action = nil;

        // Simple approach: just run the modal loop
        // For capture button, we'll set up a local monitor
        __block bool captureActive = false;

        keyMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown
            handler:^NSEvent*(NSEvent* event) {
                if (!captureActive) return event;

                // Ignore standalone modifier presses (they come as flagsChanged, not keyDown)
                uint32_t mods = 0;
                NSEventModifierFlags flags = event.modifierFlags;
                if (flags & NSEventModifierFlagCommand) mods |= MOD_WIN;
                if (flags & NSEventModifierFlagControl) mods |= MOD_CONTROL;
                if (flags & NSEventModifierFlagOption)  mods |= MOD_ALT;
                if (flags & NSEventModifierFlagShift)   mods |= MOD_SHIFT;

                // Map the key code to our portable VK code
                uint32_t key = 0;
                unsigned short kc = event.keyCode;

                // Map Carbon key codes to our VK codes
                if (kc == 49) key = VK_SPACE;       // kVK_Space
                else if (kc == 36) key = VK_RETURN;  // kVK_Return
                else if (kc == 48) key = VK_TAB;     // kVK_Tab
                else if (kc == 53) key = VK_ESCAPE;  // kVK_Escape
                else if (kc == 51) key = VK_BACK;    // kVK_Delete (backspace)
                else if (kc == 117) key = VK_DELETE;  // kVK_ForwardDelete
                else {
                    // Try to get the character
                    NSString* chars = [event charactersIgnoringModifiers];
                    if (chars.length > 0) {
                        unichar ch = [chars characterAtIndex:0];
                        if (ch >= 'a' && ch <= 'z') key = ch - 32; // uppercase
                        else if (ch >= 'A' && ch <= 'Z') key = ch;
                        else if (ch >= '0' && ch <= '9') key = ch;
                    }
                }

                if (key == 0) return event; // Unknown key, ignore

                capMods = mods;
                capKey = key;
                captureActive = false;

                HotkeySettings hk{capMods, capKey, true};
                auto text = format_hotkey(hk);
                [hkValueRef setStringValue:
                    [NSString stringWithUTF8String:text.c_str()]];
                [captureBtnRef setTitle:@"Press to change hotkey..."];

                return nil; // consume the event
            }];

        // Wire capture button to toggle capture mode
        // We'll check the capture button state in the loop
        [captureBtn setTarget:nil];
        [captureBtn setAction:nil];

        // Simple way: use block-based button
        // Since NSButton doesn't directly support blocks as action,
        // use a helper approach
        captureBtn.target = captureBtn;
        captureBtn.action = @selector(performClick:);
        // Override: we'll check button state changes in the loop

        // Actually, let's use a much simpler approach with objc_setAssociatedObject
        // or just check periodically. For simplicity:

        // Replace capture button to toggle capture mode
        [captureBtn setTarget:nil];
        [captureBtn setAction:nil];

        // Create a helper object for the capture button action
        __block BOOL wasCaptureBtnPressed = NO;

        do {
            result = [NSApp runModalSession:session];

            // Check if capture button was clicked (simple polling approach)
            // This works because the modal session processes events
            if ([captureBtn.cell isHighlighted] && !wasCaptureBtnPressed) {
                wasCaptureBtnPressed = YES;
            } else if (!([captureBtn.cell isHighlighted]) && wasCaptureBtnPressed) {
                wasCaptureBtnPressed = NO;
                captureActive = true;
                [hkValueRef setStringValue:@"Press a key combo..."];
                [captureBtnRef setTitle:@"Listening..."];
            }

        } while (result == NSModalResponseContinue);

        [NSApp endModalSession:session];
        [window orderOut:nil];

        if (keyMonitor) {
            [NSEvent removeMonitor:keyMonitor];
        }

        if (result == NSModalResponseOK) {
            // Save settings
            settings.hotkey.modifiers = capMods;
            settings.hotkey.key = capKey;

            NSInteger idx = [modelPopup indexOfSelectedItem];
            if (idx >= 0 && idx < NUM_MODELS)
                settings.whisper.model = MODELS[idx];

            settings.behavior.auto_paste =
                (autoPasteChk.state == NSControlStateValueOn);

            settings_save(settings);
            saved = true;
            log_info("Settings dialog: saved");
        } else {
            log_info("Settings dialog: cancelled");
        }

        return saved;
    }
}

} // namespace micdup
