#import <Cocoa/Cocoa.h>
#import <UserNotifications/UserNotifications.h>
#include "tray.h"
#include "icons.h"
#include "updater.h"
#include "log.h"

// ── Tray controller ─────────────────────────────────────────────────────

@interface MicDupTrayController : NSObject <UNUserNotificationCenterDelegate>
@property (strong) NSStatusItem* statusItem;
@property (assign) micdup::TrayState state;
@property (assign) int animFrame;
@property (strong) NSTimer* animTimer;
@property (strong) NSTimer* resetTimer;
@end

static MicDupTrayController* g_controller = nil;
static micdup::TrayCallbacks g_cb;

@implementation MicDupTrayController

- (void)setupWithCallbacks {
    self.statusItem = [[NSStatusBar systemStatusBar]
        statusItemWithLength:NSSquareStatusItemLength];
    self.state = micdup::TrayState::Idle;
    self.animFrame = 0;

    // Set initial icon
    NSImage* icon = (NSImage*)micdup::create_idle_icon();
    self.statusItem.button.image = icon;
    [icon release];
    self.statusItem.button.toolTip = @"MicDup - Speech to Text";

    // Request notification permission
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    center.delegate = self;
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound)
        completionHandler:^(BOOL granted, NSError* error) {
            if (!granted) {
                micdup::log_warn("Notification permission not granted");
            }
        }];

    [self rebuildMenu];
}

// Show notifications even when app is in foreground
- (void)userNotificationCenter:(UNUserNotificationCenter*)center
       willPresentNotification:(UNNotification*)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    completionHandler(UNNotificationPresentationOptionBanner);
}

- (void)rebuildMenu {
    NSMenu* menu = [[NSMenu alloc] init];

    // Version label
    auto ver = micdup::app_version();
    NSString* verStr = [NSString stringWithFormat:@"MicDup v%s", ver];
    NSMenuItem* verItem = [[NSMenuItem alloc] initWithTitle:verStr action:nil keyEquivalent:@""];
    verItem.enabled = NO;
    [menu addItem:verItem];

    // Status line
    NSString* status = @"Status: Ready";
    switch (self.state) {
        case micdup::TrayState::Idle:       status = @"Status: Ready"; break;
        case micdup::TrayState::Recording:  status = @"Status: Recording..."; break;
        case micdup::TrayState::Processing: status = @"Status: Transcribing..."; break;
        case micdup::TrayState::Success:    status = @"Status: Text copied!"; break;
        case micdup::TrayState::Error:      status = @"Status: Error occurred"; break;
    }
    NSMenuItem* statusItem = [[NSMenuItem alloc] initWithTitle:status action:nil keyEquivalent:@""];
    statusItem.enabled = NO;
    [menu addItem:statusItem];
    [menu addItem:[NSMenuItem separatorItem]];

    // Start/Stop
    NSString* toggle = (self.state == micdup::TrayState::Recording)
        ? @"Stop Recording" : @"Start Recording";
    NSMenuItem* toggleItem = [[NSMenuItem alloc] initWithTitle:toggle
        action:@selector(onStartStop:) keyEquivalent:@""];
    toggleItem.target = self;
    if (self.state == micdup::TrayState::Processing) toggleItem.enabled = NO;
    [menu addItem:toggleItem];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem* settingsItem = [[NSMenuItem alloc] initWithTitle:@"Settings..."
        action:@selector(onSettings:) keyEquivalent:@""];
    settingsItem.target = self;
    [menu addItem:settingsItem];

    NSMenuItem* updateItem = [[NSMenuItem alloc] initWithTitle:@"Check for Updates..."
        action:@selector(onCheckUpdates:) keyEquivalent:@""];
    updateItem.target = self;
    [menu addItem:updateItem];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem* exitItem = [[NSMenuItem alloc] initWithTitle:@"Quit MicDup"
        action:@selector(onExit:) keyEquivalent:@"q"];
    exitItem.target = self;
    [menu addItem:exitItem];

    self.statusItem.menu = menu;
}

- (void)onStartStop:(id)sender {
    if (g_cb.on_start_stop) g_cb.on_start_stop();
    [self rebuildMenu];
}

- (void)onSettings:(id)sender {
    if (g_cb.on_settings) g_cb.on_settings();
}

- (void)onCheckUpdates:(id)sender {
    if (g_cb.on_check_updates) g_cb.on_check_updates();
}

- (void)onExit:(id)sender {
    if (g_cb.on_exit) g_cb.on_exit();
}

- (void)onAnimTick:(NSTimer*)timer {
    micdup::tray_animate_tick();
}

- (void)onResetIdle:(NSTimer*)timer {
    self.resetTimer = nil;
    micdup::tray_set_state(micdup::TrayState::Idle);
}

@end

// ── Public API ──────────────────────────────────────────────────────────

namespace micdup {

bool tray_init(const TrayCallbacks& cb) {
    @autoreleasepool {
        g_cb = cb;
        g_controller = [[MicDupTrayController alloc] init];
        [g_controller setupWithCallbacks];
        log_info("Menu bar icon initialised");
        return true;
    }
}

void tray_set_state(TrayState state) {
    @autoreleasepool {
        if (!g_controller) return;
        g_controller.state = state;

        // Stop timers
        [g_controller.animTimer invalidate];
        g_controller.animTimer = nil;
        [g_controller.resetTimer invalidate];
        g_controller.resetTimer = nil;

        NSImage* icon = nil;
        NSString* tooltip = nil;

        switch (state) {
            case TrayState::Idle:
                icon = (NSImage*)create_idle_icon();
                tooltip = @"MicDup - Ready";
                break;
            case TrayState::Recording:
                icon = (NSImage*)create_recording_icon();
                tooltip = @"MicDup - Recording...";
                break;
            case TrayState::Processing:
                g_controller.animFrame = 0;
                g_controller.animTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                    target:g_controller selector:@selector(onAnimTick:) userInfo:nil repeats:YES];
                tooltip = @"MicDup - Transcribing...";
                icon = (NSImage*)create_processing_icon(0);
                break;
            case TrayState::Success:
                icon = (NSImage*)create_success_icon();
                tooltip = @"MicDup - Text copied!";
                g_controller.resetTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                    target:g_controller selector:@selector(onResetIdle:) userInfo:nil repeats:NO];
                break;
            case TrayState::Error:
                icon = (NSImage*)create_error_icon();
                tooltip = @"MicDup - Error";
                g_controller.resetTimer = [NSTimer scheduledTimerWithTimeInterval:3.0
                    target:g_controller selector:@selector(onResetIdle:) userInfo:nil repeats:NO];
                break;
        }

        if (icon) {
            g_controller.statusItem.button.image = icon;
            [icon release]; // create_*_icon() returns a retained object
        }
        if (tooltip) g_controller.statusItem.button.toolTip = tooltip;
        [g_controller rebuildMenu];
    }
}

void tray_notify(const char* title, const char* message) {
    @autoreleasepool {
        UNMutableNotificationContent* content = [[UNMutableNotificationContent alloc] init];
        content.title = [NSString stringWithUTF8String:title];
        content.body = [NSString stringWithUTF8String:message];

        NSString* identifier = [NSString stringWithFormat:@"micdup-%f",
            [[NSDate date] timeIntervalSince1970]];
        UNNotificationRequest* request = [UNNotificationRequest
            requestWithIdentifier:identifier content:content trigger:nil];

        [[UNUserNotificationCenter currentNotificationCenter]
            addNotificationRequest:request withCompletionHandler:nil];
    }
}

void tray_animate_tick() {
    @autoreleasepool {
        if (!g_controller || g_controller.state != TrayState::Processing) return;
        g_controller.animFrame++;
        NSImage* icon = (NSImage*)create_processing_icon(g_controller.animFrame);
        g_controller.statusItem.button.image = icon;
        [icon release];
    }
}

void tray_shutdown() {
    @autoreleasepool {
        if (!g_controller) return;
        [g_controller.animTimer invalidate];
        [g_controller.resetTimer invalidate];
        [[NSStatusBar systemStatusBar] removeStatusItem:g_controller.statusItem];
        [g_controller release];
        g_controller = nil;
        log_info("Menu bar icon shut down");
    }
}

} // namespace micdup
