#import <Cocoa/Cocoa.h>
#include "icons.h"
#include <cmath>

// Menu bar icons: 18x18, drawn programmatically.
// Idle = white microphone on dark pill (template-like).
// Recording = red circle (record indicator).
// Processing = spinning blue arc.
// Success = green checkmark.
// Error = red X.

namespace micdup {

static constexpr CGFloat ICON_SIZE = 18.0;

// Draw a microphone shape into the current graphics context
static void draw_mic_shape(NSColor* color, CGFloat cx, CGFloat cy) {
    [color setFill];
    [color setStroke];

    // Mic head — rounded rect (capsule)
    NSRect headRect = NSMakeRect(cx - 2.5, cy + 1, 5, 6);
    NSBezierPath* head = [NSBezierPath bezierPathWithRoundedRect:headRect xRadius:2.5 yRadius:2.5];
    [head fill];

    // Cradle arc
    NSBezierPath* cradle = [NSBezierPath bezierPath];
    cradle.lineWidth = 1.3;
    [cradle appendBezierPathWithArcWithCenter:NSMakePoint(cx, cy + 1)
        radius:4.5 startAngle:200 endAngle:340 clockwise:NO];
    [cradle stroke];

    // Stem
    NSBezierPath* stem = [NSBezierPath bezierPath];
    stem.lineWidth = 1.3;
    [stem moveToPoint:NSMakePoint(cx, cy - 3.5)];
    [stem lineToPoint:NSMakePoint(cx, cy - 2)];
    [stem stroke];

    // Base
    NSBezierPath* base = [NSBezierPath bezierPath];
    base.lineWidth = 1.3;
    [base moveToPoint:NSMakePoint(cx - 3, cy - 4)];
    [base lineToPoint:NSMakePoint(cx + 3, cy - 4)];
    [base stroke];
}

void* create_idle_icon() {
    NSImage* image = [[NSImage alloc] initWithSize:NSMakeSize(ICON_SIZE, ICON_SIZE)];
    [image lockFocus];

    // Dark rounded background pill
    NSRect bgRect = NSMakeRect(1, 1, ICON_SIZE - 2, ICON_SIZE - 2);
    NSBezierPath* bg = [NSBezierPath bezierPathWithRoundedRect:bgRect xRadius:4 yRadius:4];
    [[NSColor colorWithCalibratedWhite:0.15 alpha:1.0] setFill];
    [bg fill];

    // White microphone
    draw_mic_shape([NSColor whiteColor], ICON_SIZE / 2, ICON_SIZE / 2);

    [image unlockFocus];
    [image setTemplate:NO];
    return (void*)[image retain];
}

void* create_recording_icon() {
    NSImage* image = [[NSImage alloc] initWithSize:NSMakeSize(ICON_SIZE, ICON_SIZE)];
    [image lockFocus];

    // Red circle background
    NSRect bgRect = NSMakeRect(1, 1, ICON_SIZE - 2, ICON_SIZE - 2);
    NSBezierPath* bg = [NSBezierPath bezierPathWithOvalInRect:bgRect];
    [[NSColor colorWithCalibratedRed:0.9 green:0.1 blue:0.1 alpha:1.0] setFill];
    [bg fill];

    // White microphone on red
    draw_mic_shape([NSColor whiteColor], ICON_SIZE / 2, ICON_SIZE / 2);

    [image unlockFocus];
    [image setTemplate:NO];
    return (void*)[image retain];
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

    [[NSColor colorWithCalibratedRed:0.3 green:0.5 blue:1.0 alpha:1.0] setStroke];
    [arc stroke];

    [image unlockFocus];
    [image setTemplate:NO];
    return (void*)[image retain];
}

void* create_success_icon() {
    NSImage* image = [[NSImage alloc] initWithSize:NSMakeSize(ICON_SIZE, ICON_SIZE)];
    [image lockFocus];

    // Green circle background
    NSRect bgRect = NSMakeRect(1, 1, ICON_SIZE - 2, ICON_SIZE - 2);
    NSBezierPath* bg = [NSBezierPath bezierPathWithOvalInRect:bgRect];
    [[NSColor colorWithCalibratedRed:0.15 green:0.7 blue:0.15 alpha:1.0] setFill];
    [bg fill];

    // White checkmark
    NSBezierPath* check = [NSBezierPath bezierPath];
    check.lineWidth = 2.5;
    check.lineCapStyle = NSLineCapStyleRound;
    check.lineJoinStyle = NSLineJoinStyleRound;
    [check moveToPoint:NSMakePoint(5, 9)];
    [check lineToPoint:NSMakePoint(7.5, 5.5)];
    [check lineToPoint:NSMakePoint(13, 12.5)];
    [[NSColor whiteColor] setStroke];
    [check stroke];

    [image unlockFocus];
    [image setTemplate:NO];
    return (void*)[image retain];
}

void* create_error_icon() {
    NSImage* image = [[NSImage alloc] initWithSize:NSMakeSize(ICON_SIZE, ICON_SIZE)];
    [image lockFocus];

    // Red circle background
    NSRect bgRect = NSMakeRect(1, 1, ICON_SIZE - 2, ICON_SIZE - 2);
    NSBezierPath* bg = [NSBezierPath bezierPathWithOvalInRect:bgRect];
    [[NSColor colorWithCalibratedRed:0.9 green:0.1 blue:0.1 alpha:1.0] setFill];
    [bg fill];

    // White X
    NSBezierPath* x = [NSBezierPath bezierPath];
    x.lineWidth = 2.5;
    x.lineCapStyle = NSLineCapStyleRound;
    [x moveToPoint:NSMakePoint(5.5, 5.5)];
    [x lineToPoint:NSMakePoint(12.5, 12.5)];
    [x moveToPoint:NSMakePoint(12.5, 5.5)];
    [x lineToPoint:NSMakePoint(5.5, 12.5)];
    [[NSColor whiteColor] setStroke];
    [x stroke];

    [image unlockFocus];
    [image setTemplate:NO];
    return (void*)[image retain];
}

} // namespace micdup
