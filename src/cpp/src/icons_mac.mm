#import <Cocoa/Cocoa.h>
#include "icons.h"
#include <cmath>

// Menu bar icons are drawn as template images (18x18) for proper
// dark/light mode handling.  Recording uses a non-template coloured icon.

namespace micdup {

static constexpr CGFloat ICON_SIZE = 18.0;

static NSImage* draw_microphone(NSColor* color, bool isTemplate) {
    NSImage* image = [[NSImage alloc] initWithSize:NSMakeSize(ICON_SIZE, ICON_SIZE)];
    [image lockFocus];

    [color setFill];
    [color setStroke];

    NSBezierPath* path = [NSBezierPath bezierPath];
    path.lineWidth = 1.5;

    // Mic head — rounded rect (capsule)
    NSRect headRect = NSMakeRect(6, 9, 6, 7);
    NSBezierPath* head = [NSBezierPath bezierPathWithRoundedRect:headRect xRadius:3 yRadius:3];
    [head fill];

    // Cradle arc (U-shape under the mic head)
    NSBezierPath* cradle = [NSBezierPath bezierPath];
    [cradle appendBezierPathWithArcWithCenter:NSMakePoint(9, 9)
        radius:5.5 startAngle:200 endAngle:340 clockwise:NO];
    cradle.lineWidth = 1.5;
    [cradle stroke];

    // Vertical stem
    [NSBezierPath strokeLineFromPoint:NSMakePoint(9, 3.5) toPoint:NSMakePoint(9, 5)];

    // Horizontal base
    NSBezierPath* baseLine = [NSBezierPath bezierPath];
    baseLine.lineWidth = 1.5;
    [baseLine moveToPoint:NSMakePoint(6, 3)];
    [baseLine lineToPoint:NSMakePoint(12, 3)];
    [baseLine stroke];

    [image unlockFocus];
    [image setTemplate:isTemplate];
    return image;
}

void* create_idle_icon() {
    // Template image — system handles dark/light mode
    NSImage* img = draw_microphone([NSColor blackColor], YES);
    return (void*)[img retain];
}

void* create_recording_icon() {
    // Non-template red icon for visual distinction
    NSImage* img = draw_microphone([NSColor redColor], NO);
    return (void*)[img retain];
}

void* create_processing_icon(int frame) {
    NSImage* image = [[NSImage alloc] initWithSize:NSMakeSize(ICON_SIZE, ICON_SIZE)];
    [image lockFocus];

    CGFloat cx = ICON_SIZE / 2.0;
    CGFloat cy = ICON_SIZE / 2.0;
    CGFloat radius = 6.0;

    float startAngle = (float)((frame * 30) % 360);
    float endAngle = startAngle + 270;

    NSBezierPath* arc = [NSBezierPath bezierPath];
    arc.lineWidth = 2.0;
    [arc appendBezierPathWithArcWithCenter:NSMakePoint(cx, cy)
        radius:radius startAngle:startAngle endAngle:endAngle clockwise:NO];

    [[NSColor colorWithCalibratedRed:0.4 green:0.5 blue:1.0 alpha:1.0] setStroke];
    [arc stroke];

    [image unlockFocus];
    [image setTemplate:NO];
    return (void*)[image retain];
}

void* create_success_icon() {
    NSImage* image = [[NSImage alloc] initWithSize:NSMakeSize(ICON_SIZE, ICON_SIZE)];
    [image lockFocus];

    NSBezierPath* check = [NSBezierPath bezierPath];
    check.lineWidth = 2.5;
    [check moveToPoint:NSMakePoint(4, 9)];
    [check lineToPoint:NSMakePoint(7, 5)];
    [check lineToPoint:NSMakePoint(14, 13)];

    [[NSColor colorWithCalibratedRed:0.2 green:0.8 blue:0.2 alpha:1.0] setStroke];
    [check stroke];

    [image unlockFocus];
    [image setTemplate:NO];
    return (void*)[image retain];
}

void* create_error_icon() {
    NSImage* image = [[NSImage alloc] initWithSize:NSMakeSize(ICON_SIZE, ICON_SIZE)];
    [image lockFocus];

    NSBezierPath* x = [NSBezierPath bezierPath];
    x.lineWidth = 2.5;
    [x moveToPoint:NSMakePoint(5, 5)];
    [x lineToPoint:NSMakePoint(13, 13)];
    [x moveToPoint:NSMakePoint(13, 5)];
    [x lineToPoint:NSMakePoint(5, 13)];

    [[NSColor redColor] setStroke];
    [x stroke];

    [image unlockFocus];
    [image setTemplate:NO];
    return (void*)[image retain];
}

} // namespace micdup
