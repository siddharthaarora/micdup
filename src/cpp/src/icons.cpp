#include "icons.h"
#include <cmath>
#include <cstring>

// Icons are drawn into 32-bit ARGB bitmaps with proper alpha channel.
// This ensures they render correctly on both light and dark taskbars.

namespace micdup {

static constexpr int ICON_SIZE = 16;

struct ARGB { uint8_t b, g, r, a; };

static HICON argb_to_icon(ARGB* pixels) {
    BITMAPV5HEADER bi{};
    bi.bV5Size        = sizeof(bi);
    bi.bV5Width       = ICON_SIZE;
    bi.bV5Height      = -ICON_SIZE; // top-down
    bi.bV5Planes      = 1;
    bi.bV5BitCount    = 32;
    bi.bV5Compression = BI_BITFIELDS;
    bi.bV5RedMask     = 0x00FF0000;
    bi.bV5GreenMask   = 0x0000FF00;
    bi.bV5BlueMask    = 0x000000FF;
    bi.bV5AlphaMask   = 0xFF000000;

    HDC hdc = GetDC(nullptr);
    void* bits = nullptr;
    HBITMAP hBitmap = CreateDIBSection(hdc, reinterpret_cast<BITMAPINFO*>(&bi),
                                       DIB_RGB_COLORS, &bits, nullptr, 0);
    ReleaseDC(nullptr, hdc);
    if (!hBitmap || !bits) return nullptr;

    memcpy(bits, pixels, ICON_SIZE * ICON_SIZE * sizeof(ARGB));

    HBITMAP hMask = CreateBitmap(ICON_SIZE, ICON_SIZE, 1, 1, nullptr);

    ICONINFO ii{};
    ii.fIcon    = TRUE;
    ii.hbmMask  = hMask;
    ii.hbmColor = hBitmap;
    HICON icon  = CreateIconIndirect(&ii);

    DeleteObject(hBitmap);
    DeleteObject(hMask);
    return icon;
}

// ── Drawing primitives into ARGB buffer ─────────────────────────────────

static void set_pixel(ARGB* buf, int x, int y, uint8_t r, uint8_t g, uint8_t b, uint8_t a = 255) {
    if (x < 0 || x >= ICON_SIZE || y < 0 || y >= ICON_SIZE) return;
    auto& p = buf[y * ICON_SIZE + x];
    // Alpha blend
    if (p.a == 0) {
        p = {b, g, r, a};
    } else {
        float sa = a / 255.0f;
        float da = p.a / 255.0f;
        float oa = sa + da * (1 - sa);
        if (oa > 0) {
            p.r = (uint8_t)((r * sa + p.r * da * (1 - sa)) / oa);
            p.g = (uint8_t)((g * sa + p.g * da * (1 - sa)) / oa);
            p.b = (uint8_t)((b * sa + p.b * da * (1 - sa)) / oa);
            p.a = (uint8_t)(oa * 255);
        }
    }
}

// Bresenham thick line
static void draw_line(ARGB* buf, int x0, int y0, int x1, int y1,
                      uint8_t r, uint8_t g, uint8_t b, int thickness = 2) {
    int dx = abs(x1 - x0), sx = x0 < x1 ? 1 : -1;
    int dy = -abs(y1 - y0), sy = y0 < y1 ? 1 : -1;
    int err = dx + dy;

    int half = thickness / 2;
    while (true) {
        for (int ty = -half; ty <= half; ty++)
            for (int tx = -half; tx <= half; tx++)
                set_pixel(buf, x0 + tx, y0 + ty, r, g, b);

        if (x0 == x1 && y0 == y1) break;
        int e2 = 2 * err;
        if (e2 >= dy) { err += dy; x0 += sx; }
        if (e2 <= dx) { err += dx; y0 += sy; }
    }
}

// Filled rounded rectangle (pill shape)
static void fill_rounded_rect(ARGB* buf, int x0, int y0, int x1, int y1, int radius,
                               uint8_t r, uint8_t g, uint8_t b) {
    for (int y = y0; y <= y1; y++) {
        for (int x = x0; x <= x1; x++) {
            // Check if inside rounded corners
            bool inside = true;
            // Top-left corner
            if (x < x0 + radius && y < y0 + radius) {
                int dx2 = x - (x0 + radius), dy2 = y - (y0 + radius);
                inside = (dx2 * dx2 + dy2 * dy2) <= radius * radius;
            }
            // Top-right
            if (x > x1 - radius && y < y0 + radius) {
                int dx2 = x - (x1 - radius), dy2 = y - (y0 + radius);
                inside = (dx2 * dx2 + dy2 * dy2) <= radius * radius;
            }
            // Bottom-left
            if (x < x0 + radius && y > y1 - radius) {
                int dx2 = x - (x0 + radius), dy2 = y - (y1 - radius);
                inside = (dx2 * dx2 + dy2 * dy2) <= radius * radius;
            }
            // Bottom-right
            if (x > x1 - radius && y > y1 - radius) {
                int dx2 = x - (x1 - radius), dy2 = y - (y1 - radius);
                inside = (dx2 * dx2 + dy2 * dy2) <= radius * radius;
            }
            if (inside) set_pixel(buf, x, y, r, g, b);
        }
    }
}

// Draw arc (circle outline segment)
static void draw_arc(ARGB* buf, int cx, int cy, int radius,
                     float start_deg, float end_deg,
                     uint8_t r, uint8_t g, uint8_t b, int thickness = 2) {
    int half = thickness / 2;
    float step = 2.0f; // degrees
    for (float a = start_deg; a <= end_deg; a += step) {
        float rad = a * 3.14159265f / 180.0f;
        int px = cx + (int)(radius * cosf(rad));
        int py = cy + (int)(radius * sinf(rad));
        for (int ty = -half; ty <= half; ty++)
            for (int tx = -half; tx <= half; tx++)
                set_pixel(buf, px + tx, py + ty, r, g, b);
    }
}

// ── Icon generators ─────────────────────────────────────────────────────

static HICON draw_microphone(uint8_t r, uint8_t g, uint8_t b) {
    ARGB pixels[ICON_SIZE * ICON_SIZE]{};

    // Mic head — filled rounded rect (capsule) at top center
    fill_rounded_rect(pixels, 5, 1, 10, 7, 3, r, g, b);

    // Cradle arc (U-shape under the mic head)
    draw_arc(pixels, 8, 7, 5, 20, 160, r, g, b, 2);

    // Vertical stem
    draw_line(pixels, 8, 12, 8, 13, r, g, b, 1);

    // Horizontal base
    draw_line(pixels, 5, 14, 11, 14, r, g, b, 1);

    return argb_to_icon(pixels);
}

HICON create_idle_icon() {
    // Bright white — visible on both light and dark taskbars
    return draw_microphone(220, 220, 220);
}

HICON create_recording_icon() {
    return draw_microphone(240, 60, 60);
}

HICON create_processing_icon(int frame) {
    ARGB pixels[ICON_SIZE * ICON_SIZE]{};

    float start = (float)((frame * 30) % 360);
    draw_arc(pixels, 8, 8, 5, start, start + 270, 100, 130, 255, 2);

    return argb_to_icon(pixels);
}

HICON create_success_icon() {
    ARGB pixels[ICON_SIZE * ICON_SIZE]{};

    // Bold green checkmark
    draw_line(pixels, 3, 8, 6, 11, 60, 210, 60, 2);
    draw_line(pixels, 6, 11, 12, 4, 60, 210, 60, 2);

    return argb_to_icon(pixels);
}

HICON create_error_icon() {
    ARGB pixels[ICON_SIZE * ICON_SIZE]{};

    // Bold red X
    draw_line(pixels, 4, 4, 12, 12, 240, 60, 60, 2);
    draw_line(pixels, 12, 4, 4, 12, 240, 60, 60, 2);

    return argb_to_icon(pixels);
}

} // namespace micdup
