#include "icons.h"
#include <cmath>

// All icons are drawn at 16x16 directly using GDI.
// No GDI+ dependency — pure Win32 GDI calls.

namespace micdup {

static constexpr int ICON_SIZE = 16;

static HICON bitmap_to_icon(HBITMAP hBitmap) {
    ICONINFO ii{};
    ii.fIcon    = TRUE;
    ii.hbmMask  = CreateBitmap(ICON_SIZE, ICON_SIZE, 1, 1, nullptr);
    ii.hbmColor = hBitmap;
    HICON icon  = CreateIconIndirect(&ii);
    DeleteObject(ii.hbmMask);
    return icon;
}

static HBITMAP create_blank_bitmap(HDC hdc) {
    BITMAPINFO bmi{};
    bmi.bmiHeader.biSize        = sizeof(BITMAPINFOHEADER);
    bmi.bmiHeader.biWidth       = ICON_SIZE;
    bmi.bmiHeader.biHeight      = -ICON_SIZE; // top-down
    bmi.bmiHeader.biPlanes      = 1;
    bmi.bmiHeader.biBitCount    = 32;
    bmi.bmiHeader.biCompression = BI_RGB;
    void* bits = nullptr;
    return CreateDIBSection(hdc, &bmi, DIB_RGB_COLORS, &bits, nullptr, 0);
}

// Draw a simple microphone shape in the given colour
static HICON draw_microphone(COLORREF color) {
    HDC screen = GetDC(nullptr);
    HDC mem    = CreateCompatibleDC(screen);
    HBITMAP bmp = create_blank_bitmap(mem);
    HGDIOBJ old = SelectObject(mem, bmp);

    // Transparent background (alpha will be handled by the mask)
    RECT rc = {0, 0, ICON_SIZE, ICON_SIZE};
    FillRect(mem, &rc, (HBRUSH)GetStockObject(BLACK_BRUSH));

    HPEN pen     = CreatePen(PS_SOLID, 1, color);
    HBRUSH brush = CreateSolidBrush(color);
    SelectObject(mem, pen);
    SelectObject(mem, brush);

    // Mic head (rounded rect approximation) — capsule at top center
    RoundRect(mem, 5, 1, 11, 8, 4, 4);

    // Cradle arc — draw left arm, bottom, right arm
    HPEN cradlePen = CreatePen(PS_SOLID, 1, color);
    SelectObject(mem, cradlePen);
    SelectObject(mem, GetStockObject(NULL_BRUSH));
    Arc(mem, 3, 5, 13, 13, 13, 8, 3, 8);

    // Vertical stem
    MoveToEx(mem, 8, 12, nullptr);
    LineTo(mem, 8, 14);

    // Horizontal base
    MoveToEx(mem, 5, 14, nullptr);
    LineTo(mem, 11, 14);

    SelectObject(mem, old);
    DeleteObject(pen);
    DeleteObject(brush);
    DeleteObject(cradlePen);
    DeleteDC(mem);
    ReleaseDC(nullptr, screen);

    HICON icon = bitmap_to_icon(bmp);
    DeleteObject(bmp);
    return icon;
}

HICON create_idle_icon() {
    return draw_microphone(RGB(180, 180, 180));
}

HICON create_recording_icon() {
    return draw_microphone(RGB(220, 50, 50));
}

HICON create_processing_icon(int frame) {
    HDC screen = GetDC(nullptr);
    HDC mem    = CreateCompatibleDC(screen);
    HBITMAP bmp = create_blank_bitmap(mem);
    HGDIOBJ old = SelectObject(mem, bmp);

    RECT rc = {0, 0, ICON_SIZE, ICON_SIZE};
    FillRect(mem, &rc, (HBRUSH)GetStockObject(BLACK_BRUSH));

    HPEN pen = CreatePen(PS_SOLID, 2, RGB(100, 100, 255));
    SelectObject(mem, pen);
    SelectObject(mem, GetStockObject(NULL_BRUSH));

    // Rotating arc
    int start_angle = (frame * 30) % 360;
    int end_angle   = start_angle + 270;
    double sa = start_angle * 3.14159265 / 180.0;
    double ea = end_angle   * 3.14159265 / 180.0;

    int x1 = 8 + (int)(6 * cos(sa));
    int y1 = 8 - (int)(6 * sin(sa));
    int x2 = 8 + (int)(6 * cos(ea));
    int y2 = 8 - (int)(6 * sin(ea));

    Arc(mem, 2, 2, 14, 14, x1, y1, x2, y2);

    SelectObject(mem, old);
    DeleteObject(pen);
    DeleteDC(mem);
    ReleaseDC(nullptr, screen);

    HICON icon = bitmap_to_icon(bmp);
    DeleteObject(bmp);
    return icon;
}

HICON create_success_icon() {
    HDC screen = GetDC(nullptr);
    HDC mem    = CreateCompatibleDC(screen);
    HBITMAP bmp = create_blank_bitmap(mem);
    HGDIOBJ old = SelectObject(mem, bmp);

    RECT rc = {0, 0, ICON_SIZE, ICON_SIZE};
    FillRect(mem, &rc, (HBRUSH)GetStockObject(BLACK_BRUSH));

    HPEN pen = CreatePen(PS_SOLID, 2, RGB(40, 180, 40));
    SelectObject(mem, pen);

    // Checkmark
    MoveToEx(mem, 3, 8, nullptr);
    LineTo(mem, 6, 11);
    LineTo(mem, 12, 4);

    SelectObject(mem, old);
    DeleteObject(pen);
    DeleteDC(mem);
    ReleaseDC(nullptr, screen);

    HICON icon = bitmap_to_icon(bmp);
    DeleteObject(bmp);
    return icon;
}

HICON create_error_icon() {
    HDC screen = GetDC(nullptr);
    HDC mem    = CreateCompatibleDC(screen);
    HBITMAP bmp = create_blank_bitmap(mem);
    HGDIOBJ old = SelectObject(mem, bmp);

    RECT rc = {0, 0, ICON_SIZE, ICON_SIZE};
    FillRect(mem, &rc, (HBRUSH)GetStockObject(BLACK_BRUSH));

    HPEN pen = CreatePen(PS_SOLID, 2, RGB(220, 50, 50));
    SelectObject(mem, pen);

    // X shape
    MoveToEx(mem, 4, 4, nullptr);
    LineTo(mem, 12, 12);
    MoveToEx(mem, 12, 4, nullptr);
    LineTo(mem, 4, 12);

    SelectObject(mem, old);
    DeleteObject(pen);
    DeleteDC(mem);
    ReleaseDC(nullptr, screen);

    HICON icon = bitmap_to_icon(bmp);
    DeleteObject(bmp);
    return icon;
}

} // namespace micdup
