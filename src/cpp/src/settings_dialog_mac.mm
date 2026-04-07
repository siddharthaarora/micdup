#import <Cocoa/Cocoa.h>
#include "settings_dialog.h"
#include "log.h"

// ── Helper class to handle dialog actions ───────────────────────────────

@interface MicDupSettingsController : NSObject
@property (strong) NSWindow* window;
@property (strong) NSTextField* hotkeyLabel;
@property (strong) NSButton* captureButton;
@property (strong) NSPopUpButton* modelPopup;
@property (strong) NSButton* autoPasteCheck;
@property (assign) uint32_t capModifiers;
@property (assign) uint32_t capKey;
@property (assign) BOOL capturing;
@property (assign) BOOL saved;
@property (strong) id keyMonitor;
@end

@implementation MicDupSettingsController

- (void)startCapture:(id)sender {
    self.capturing = YES;
    [self.hotkeyLabel setStringValue:@"Press a key combo..."];
    [self.captureButton setTitle:@"Listening..."];
    [self.captureButton setEnabled:NO];

    // Install a local event monitor
    self.keyMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown
        handler:^NSEvent*(NSEvent* event) {
            if (!self.capturing) return event;

            uint32_t mods = 0;
            NSEventModifierFlags flags = event.modifierFlags;
            if (flags & NSEventModifierFlagCommand) mods |= MOD_WIN;
            if (flags & NSEventModifierFlagControl) mods |= MOD_CONTROL;
            if (flags & NSEventModifierFlagOption)  mods |= MOD_ALT;
            if (flags & NSEventModifierFlagShift)   mods |= MOD_SHIFT;

            // Require at least one modifier
            if (mods == 0) return nil;

            // Map Carbon key code to portable VK code
            uint32_t key = 0;
            unsigned short kc = event.keyCode;
            if (kc == 49) key = VK_SPACE;
            else if (kc == 36) key = VK_RETURN;
            else if (kc == 48) key = VK_TAB;
            else if (kc == 53) key = VK_ESCAPE;
            else if (kc == 51) key = VK_BACK;
            else if (kc == 117) key = VK_DELETE;
            else {
                NSString* chars = [event charactersIgnoringModifiers];
                if (chars.length > 0) {
                    unichar ch = [chars characterAtIndex:0];
                    if (ch >= 'a' && ch <= 'z') key = ch - 32;
                    else if (ch >= 'A' && ch <= 'Z') key = ch;
                    else if (ch >= '0' && ch <= '9') key = ch;
                }
            }
            if (key == 0) return nil;

            self.capModifiers = mods;
            self.capKey = key;
            self.capturing = NO;

            micdup::HotkeySettings hk{mods, key, true};
            auto text = micdup::format_hotkey(hk);
            [self.hotkeyLabel setStringValue:[NSString stringWithUTF8String:text.c_str()]];
            [self.captureButton setTitle:@"Change Hotkey..."];
            [self.captureButton setEnabled:YES];

            if (self.keyMonitor) {
                [NSEvent removeMonitor:self.keyMonitor];
                self.keyMonitor = nil;
            }

            return nil; // consume
        }];
}

- (void)saveClicked:(id)sender {
    self.saved = YES;
    [NSApp stopModalWithCode:NSModalResponseOK];
}

- (void)cancelClicked:(id)sender {
    [NSApp stopModalWithCode:NSModalResponseCancel];
}

- (void)cleanup {
    if (self.keyMonitor) {
        [NSEvent removeMonitor:self.keyMonitor];
        self.keyMonitor = nil;
    }
}

@end

// ── Public API ──────────────────────────────────────────────────────────

namespace micdup {

static const char* MODELS[] = {"tiny", "base", "small", "medium", "large"};
static constexpr int NUM_MODELS = 5;

static int model_index(const std::string& name) {
    for (int i = 0; i < NUM_MODELS; i++)
        if (name == MODELS[i]) return i;
    return 1;
}

bool show_settings_dialog(AppSettings& settings) {
    @autoreleasepool {
        [NSApp activateIgnoringOtherApps:YES];

        MicDupSettingsController* ctrl = [[MicDupSettingsController alloc] init];
        ctrl.capModifiers = settings.hotkey.modifiers;
        ctrl.capKey = settings.hotkey.key;
        ctrl.capturing = NO;
        ctrl.saved = NO;

        // ── Create window ───────────────────────────────────────────
        CGFloat W = 420, H = 260;
        NSRect frame = NSMakeRect(0, 0, W, H);
        NSWindow* window = [[NSWindow alloc]
            initWithContentRect:frame
            styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
            backing:NSBackingStoreBuffered
            defer:NO];
        [window setTitle:@"MicDup Settings"];
        [window center];
        ctrl.window = window;

        NSView* v = [window contentView];
        CGFloat leftCol = 130;  // label column width
        CGFloat rightX = leftCol + 10;
        CGFloat rightW = W - rightX - 30;
        CGFloat y = H - 60;

        // ── Hotkey row ──────────────────────────────────────────────
        NSTextField* hkLbl = [NSTextField labelWithString:@"Hotkey:"];
        [hkLbl setFont:[NSFont systemFontOfSize:13 weight:NSFontWeightMedium]];
        hkLbl.frame = NSMakeRect(30, y + 2, 90, 20);
        [v addSubview:hkLbl];

        auto hkStr = format_hotkey(settings.hotkey);
        NSTextField* hkValue = [NSTextField labelWithString:
            [NSString stringWithUTF8String:hkStr.c_str()]];
        [hkValue setFont:[NSFont monospacedSystemFontOfSize:13 weight:NSFontWeightRegular]];
        hkValue.frame = NSMakeRect(rightX, y + 2, rightW, 20);
        [v addSubview:hkValue];
        ctrl.hotkeyLabel = hkValue;

        y -= 36;

        NSButton* captureBtn = [NSButton buttonWithTitle:@"Change Hotkey..."
            target:ctrl action:@selector(startCapture:)];
        captureBtn.bezelStyle = NSBezelStyleRounded;
        captureBtn.frame = NSMakeRect(rightX, y, 160, 28);
        [v addSubview:captureBtn];
        ctrl.captureButton = captureBtn;

        y -= 48;

        // ── Model row ───────────────────────────────────────────────
        NSTextField* modelLbl = [NSTextField labelWithString:@"Whisper Model:"];
        [modelLbl setFont:[NSFont systemFontOfSize:13 weight:NSFontWeightMedium]];
        modelLbl.frame = NSMakeRect(30, y + 4, 110, 20);
        [v addSubview:modelLbl];

        NSPopUpButton* modelPopup = [[NSPopUpButton alloc]
            initWithFrame:NSMakeRect(rightX, y, rightW, 28) pullsDown:NO];
        for (int i = 0; i < NUM_MODELS; i++) {
            [modelPopup addItemWithTitle:[NSString stringWithUTF8String:MODELS[i]]];
        }
        [modelPopup selectItemAtIndex:model_index(settings.whisper.model)];
        [v addSubview:modelPopup];
        ctrl.modelPopup = modelPopup;

        y -= 40;

        // ── Auto-paste row ──────────────────────────────────────────
        NSButton* autoChk = [NSButton checkboxWithTitle:@"Auto-paste transcription"
            target:nil action:nil];
        autoChk.frame = NSMakeRect(rightX, y, rightW, 20);
        autoChk.state = settings.behavior.auto_paste
            ? NSControlStateValueOn : NSControlStateValueOff;
        [v addSubview:autoChk];
        ctrl.autoPasteCheck = autoChk;

        y -= 52;

        // ── Buttons ─────────────────────────────────────────────────
        NSButton* saveBtn = [NSButton buttonWithTitle:@"Save"
            target:ctrl action:@selector(saveClicked:)];
        saveBtn.bezelStyle = NSBezelStyleRounded;
        saveBtn.frame = NSMakeRect(W - 210, y, 80, 32);
        saveBtn.keyEquivalent = @"\r";
        [v addSubview:saveBtn];

        NSButton* cancelBtn = [NSButton buttonWithTitle:@"Cancel"
            target:ctrl action:@selector(cancelClicked:)];
        cancelBtn.bezelStyle = NSBezelStyleRounded;
        cancelBtn.frame = NSMakeRect(W - 110, y, 80, 32);
        cancelBtn.keyEquivalent = @"\033";
        [v addSubview:cancelBtn];

        // ── Run modal ───────────────────────────────────────────────
        NSModalResponse result = [NSApp runModalForWindow:window];
        [ctrl cleanup];
        [window orderOut:nil];

        if (result == NSModalResponseOK) {
            settings.hotkey.modifiers = ctrl.capModifiers;
            settings.hotkey.key = ctrl.capKey;

            NSInteger idx = [ctrl.modelPopup indexOfSelectedItem];
            if (idx >= 0 && idx < NUM_MODELS)
                settings.whisper.model = MODELS[idx];

            settings.behavior.auto_paste =
                (ctrl.autoPasteCheck.state == NSControlStateValueOn);

            settings_save(settings);
            log_info("Settings dialog: saved");
            return true;
        }

        log_info("Settings dialog: cancelled");
        return false;
    }
}

} // namespace micdup
