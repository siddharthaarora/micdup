#import <Cocoa/Cocoa.h>
#include "icons.h"
#include <cmath>

// Menu bar icons: 18x18.
// Idle = black square with white microphone.
// Recording = red circle with white mic (record indicator).
// Processing = spinning blue arc.
// Success = green circle with white checkmark.
// Error = red circle with white X.

namespace micdup {

static constexpr CGFloat ICON_SIZE = 18.0;

// Draw a microphone shape centred at (cx, cy) scaled to fit the icon
static void draw_mic(NSColor* color, CGFloat cx, CGFloat cy, CGFloat scale) {
    [color setFill];
    [color setStroke];

    // Mic head — capsule
    CGFloat headW = 5.0 * scale;
    CGFloat headH = 7.0 * scale;
    NSRect headRect = NSMakeRect(cx - headW / 2, cy + 0.5 * scale, headW, headH);
    NSBezierPath* head = [NSBezierPath bezierPathWithRoundedRect:headRect
        xRadius:headW / 2 yRadius:headW / 2];
    [head fill];

    // Cradle arc
    NSBezierPath* cradle = [NSBezierPath bezierPath];
    cradle.lineWidth = 1.4 * scale;
    cradle.lineCapStyle = NSLineCapStyleRound;
    [cradle appendBezierPathWithArcWithCenter:NSMakePoint(cx, cy + 0.5 * scale)
        radius:4.5 * scale startAngle:200 endAngle:340 clockwise:NO];
    [cradle stroke];

    // Stem
    NSBezierPath* stem = [NSBezierPath bezierPath];
    stem.lineWidth = 1.4 * scale;
    stem.lineCapStyle = NSLineCapStyleRound;
    [stem moveToPoint:NSMakePoint(cx, cy - 4.0 * scale)];
    [stem lineToPoint:NSMakePoint(cx, cy - 2.5 * scale)];
    [stem stroke];

    // Base
    NSBezierPath* base = [NSBezierPath bezierPath];
    base.lineWidth = 1.4 * scale;
    base.lineCapStyle = NSLineCapStyleRound;
    [base moveToPoint:NSMakePoint(cx - 3.0 * scale, cy - 4.8 * scale)];
    [base lineToPoint:NSMakePoint(cx + 3.0 * scale, cy - 4.8 * scale)];
    [base stroke];
}

void* create_idle_icon() {
    NSImage* image = [[NSImage alloc] initWithSize:NSMakeSize(ICON_SIZE, ICON_SIZE)];
    [image lockFocus];

    // Black square background with slight rounding
    NSRect bgRect = NSMakeRect(0.5, 0.5, ICON_SIZE - 1, ICON_SIZE - 1);
    NSBezierPath* bg = [NSBezierPath bezierPathWithRoundedRect:bgRect xRadius:3.5 yRadius:3.5];
    [[NSColor blackColor] setFill];
    [bg fill];

    // White microphone
    draw_mic([NSColor whiteColor], ICON_SIZE / 2, ICON_SIZE / 2, 1.0);

    [image unlockFocus];
    [image setTemplate:NO];
    return (void*)[image retain];
}

void* create_recording_icon() {
    NSImage* image = [[NSImage alloc] initWithSize:NSMakeSize(ICON_SIZE, ICON_SIZE)];
    [image lockFocus];

    // Solid red dot filling the icon
    NSRect bgRect = NSMakeRect(0.5, 0.5, ICON_SIZE - 1, ICON_SIZE - 1);
    NSBezierPath* bg = [NSBezierPath bezierPathWithOvalInRect:bgRect];
    [[NSColor colorWithCalibratedRed:0.92 green:0.1 blue:0.1 alpha:1.0] setFill];
    [bg fill];

    [image unlockFocus];
    [image setTemplate:NO];
    return (void*)[image retain];
}

void* create_processing_icon(int frame) {
    NSImage* image = [[NSImage alloc] initWithSize:NSMakeSize(ICON_SIZE, ICON_SIZE)];
    [image lockFocus];

    CGFloat cx = ICON_SIZE / 2.0;
    CGFloat cy = ICON_SIZE / 2.0;

    float startAngle = (float)((frame * 30) % 360);
    float endAngle = startAngle + 270;

    NSBezierPath* arc = [NSBezierPath bezierPath];
    arc.lineWidth = 2.2;
    arc.lineCapStyle = NSLineCapStyleRound;
    [arc appendBezierPathWithArcWithCenter:NSMakePoint(cx, cy)
        radius:6.5 startAngle:startAngle endAngle:endAngle clockwise:NO];

    [[NSColor colorWithCalibratedRed:0.2 green:0.45 blue:1.0 alpha:1.0] setStroke];
    [arc stroke];

    [image unlockFocus];
    [image setTemplate:NO];
    return (void*)[image retain];
}

void* create_success_icon() {
    NSImage* image = [[NSImage alloc] initWithSize:NSMakeSize(ICON_SIZE, ICON_SIZE)];
    [image lockFocus];

    // Green circle background
    NSRect bgRect = NSMakeRect(0.5, 0.5, ICON_SIZE - 1, ICON_SIZE - 1);
    NSBezierPath* bg = [NSBezierPath bezierPathWithOvalInRect:bgRect];
    [[NSColor colorWithCalibratedRed:0.15 green:0.72 blue:0.15 alpha:1.0] setFill];
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
    NSRect bgRect = NSMakeRect(0.5, 0.5, ICON_SIZE - 1, ICON_SIZE - 1);
    NSBezierPath* bg = [NSBezierPath bezierPathWithOvalInRect:bgRect];
    [[NSColor colorWithCalibratedRed:0.92 green:0.1 blue:0.1 alpha:1.0] setFill];
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
