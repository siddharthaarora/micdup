#include "tray.h"
#include "icons.h"
#include "settings.h"
#include "log.h"

#include <shellapi.h>
#include <string>

namespace micdup {

// ── Private state ───────────────────────────────────────────────────────

static constexpr UINT WM_TRAY_ICON    = WM_APP + 1;
static constexpr UINT IDM_START_STOP  = 1001;
static constexpr UINT IDM_SETTINGS    = 1002;
static constexpr UINT IDM_EXIT        = 1004;
static constexpr UINT IDT_ANIMATION   = 2001;
static constexpr UINT IDT_RESET_IDLE  = 2002;

static HWND          g_hwnd = nullptr;
static HMENU         g_menu = nullptr;
static NOTIFYICONDATAW g_nid{};
static TrayCallbacks g_cb;
static TrayState     g_state = TrayState::Idle;
static int           g_anim_frame = 0;
static HICON         g_current_icon = nullptr;

static void update_icon(HICON icon) {
    if (g_current_icon) DestroyIcon(g_current_icon);
    g_current_icon   = icon;
    g_nid.hIcon      = icon;
    g_nid.uFlags     = NIF_ICON | NIF_TIP | NIF_MESSAGE;
    Shell_NotifyIconW(NIM_MODIFY, &g_nid);
}

static void set_tooltip(const wchar_t* text) {
    wcsncpy_s(g_nid.szTip, text, _countof(g_nid.szTip) - 1);
    g_nid.uFlags = NIF_TIP;
    Shell_NotifyIconW(NIM_MODIFY, &g_nid);
}

static void rebuild_menu() {
    if (g_menu) DestroyMenu(g_menu);
    g_menu = CreatePopupMenu();

    // Version label (grayed)
    std::wstring ver = L"MicDup v";
    auto v = app_version();
    ver += std::wstring(v, v + strlen(v));
    AppendMenuW(g_menu, MF_STRING | MF_GRAYED, 0, ver.c_str());

    // Status line (grayed)
    const wchar_t* status = L"Status: Ready";
    switch (g_state) {
        case TrayState::Idle:       status = L"Status: Ready"; break;
        case TrayState::Recording:  status = L"Status: Recording..."; break;
        case TrayState::Processing: status = L"Status: Transcribing..."; break;
        case TrayState::Success:    status = L"Status: Text copied!"; break;
        case TrayState::Error:      status = L"Status: Error occurred"; break;
    }
    AppendMenuW(g_menu, MF_STRING | MF_GRAYED, 0, status);
    AppendMenuW(g_menu, MF_SEPARATOR, 0, nullptr);

    // Start / Stop
    const wchar_t* toggle = (g_state == TrayState::Recording) ? L"Stop Recording" : L"Start Recording";
    UINT flags = MF_STRING;
    if (g_state == TrayState::Processing) flags |= MF_GRAYED;
    AppendMenuW(g_menu, flags, IDM_START_STOP, toggle);

    AppendMenuW(g_menu, MF_SEPARATOR, 0, nullptr);
    AppendMenuW(g_menu, MF_STRING, IDM_SETTINGS, L"Settings...");
    AppendMenuW(g_menu, MF_SEPARATOR, 0, nullptr);
    AppendMenuW(g_menu, MF_STRING, IDM_EXIT, L"Exit");
}

// ── Window procedure ────────────────────────────────────────────────────

static LRESULT CALLBACK tray_wndproc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    switch (msg) {
        case WM_TRAY_ICON:
            if (LOWORD(lp) == WM_RBUTTONUP || LOWORD(lp) == WM_CONTEXTMENU) {
                POINT pt;
                GetCursorPos(&pt);
                SetForegroundWindow(hwnd);
                rebuild_menu();
                TrackPopupMenu(g_menu, TPM_RIGHTALIGN | TPM_BOTTOMALIGN,
                               pt.x, pt.y, 0, hwnd, nullptr);
                PostMessage(hwnd, WM_NULL, 0, 0);
            } else if (LOWORD(lp) == WM_LBUTTONDBLCLK) {
                if (g_cb.on_start_stop) g_cb.on_start_stop();
            }
            return 0;

        case WM_COMMAND:
            switch (LOWORD(wp)) {
                case IDM_START_STOP: if (g_cb.on_start_stop)    g_cb.on_start_stop();    break;
                case IDM_SETTINGS:   if (g_cb.on_settings)      g_cb.on_settings();      break;
                case IDM_EXIT:       if (g_cb.on_exit)          g_cb.on_exit();          break;
            }
            return 0;

        case WM_HOTKEY:
            if (g_cb.on_start_stop) g_cb.on_start_stop();
            return 0;

        case WM_TIMER:
            if (wp == IDT_ANIMATION) {
                tray_animate_tick();
            } else if (wp == IDT_RESET_IDLE) {
                KillTimer(hwnd, IDT_RESET_IDLE);
                tray_set_state(TrayState::Idle);
            }
            return 0;

        case WM_DESTROY:
            PostQuitMessage(0);
            return 0;
    }
    return DefWindowProcW(hwnd, msg, wp, lp);
}

// ── Public API ──────────────────────────────────────────────────────────

bool tray_init(HINSTANCE hInstance, const TrayCallbacks& cb) {
    g_cb = cb;

    WNDCLASSEXW wc{};
    wc.cbSize        = sizeof(wc);
    wc.lpfnWndProc   = tray_wndproc;
    wc.hInstance      = hInstance;
    wc.lpszClassName  = L"MicDupTrayWnd";
    if (!RegisterClassExW(&wc)) return false;

    g_hwnd = CreateWindowExW(0, L"MicDupTrayWnd", L"MicDup", 0,
                              0, 0, 0, 0, HWND_MESSAGE, nullptr, hInstance, nullptr);
    if (!g_hwnd) return false;

    // Add tray icon
    g_nid.cbSize           = sizeof(g_nid);
    g_nid.hWnd             = g_hwnd;
    g_nid.uID              = 1;
    g_nid.uFlags           = NIF_ICON | NIF_TIP | NIF_MESSAGE;
    g_nid.uCallbackMessage = WM_TRAY_ICON;
    g_nid.hIcon            = create_idle_icon();
    g_current_icon         = g_nid.hIcon;
    wcscpy_s(g_nid.szTip, L"MicDup - Speech to Text");
    Shell_NotifyIconW(NIM_ADD, &g_nid);

    // Accept version 4 balloon features
    g_nid.uVersion = NOTIFYICON_VERSION_4;
    Shell_NotifyIconW(NIM_SETVERSION, &g_nid);

    log_info("Tray icon initialised");
    return true;
}

void tray_set_state(TrayState state) {
    g_state = state;
    KillTimer(g_hwnd, IDT_ANIMATION);
    KillTimer(g_hwnd, IDT_RESET_IDLE);

    switch (state) {
        case TrayState::Idle:
            update_icon(create_idle_icon());
            set_tooltip(L"MicDup - Ready");
            break;
        case TrayState::Recording:
            update_icon(create_recording_icon());
            set_tooltip(L"MicDup - Recording...");
            break;
        case TrayState::Processing:
            g_anim_frame = 0;
            SetTimer(g_hwnd, IDT_ANIMATION, 100, nullptr);
            set_tooltip(L"MicDup - Transcribing...");
            break;
        case TrayState::Success:
            update_icon(create_success_icon());
            set_tooltip(L"MicDup - Text copied!");
            SetTimer(g_hwnd, IDT_RESET_IDLE, 2000, nullptr);
            break;
        case TrayState::Error:
            update_icon(create_error_icon());
            set_tooltip(L"MicDup - Error");
            SetTimer(g_hwnd, IDT_RESET_IDLE, 3000, nullptr);
            break;
    }
}

void tray_notify(const wchar_t* title, const wchar_t* message) {
    g_nid.uFlags = NIF_INFO;
    wcsncpy_s(g_nid.szInfoTitle, title, _countof(g_nid.szInfoTitle) - 1);
    wcsncpy_s(g_nid.szInfo, message, _countof(g_nid.szInfo) - 1);
    g_nid.dwInfoFlags = NIIF_NONE;
    Shell_NotifyIconW(NIM_MODIFY, &g_nid);
}

void tray_animate_tick() {
    if (g_state != TrayState::Processing) return;
    g_anim_frame++;
    update_icon(create_processing_icon(g_anim_frame));
}

void tray_shutdown() {
    KillTimer(g_hwnd, IDT_ANIMATION);
    KillTimer(g_hwnd, IDT_RESET_IDLE);
    Shell_NotifyIconW(NIM_DELETE, &g_nid);
    if (g_current_icon) { DestroyIcon(g_current_icon); g_current_icon = nullptr; }
    if (g_menu) { DestroyMenu(g_menu); g_menu = nullptr; }
    if (g_hwnd) { DestroyWindow(g_hwnd); g_hwnd = nullptr; }
    log_info("Tray shut down");
}

HWND tray_hwnd() { return g_hwnd; }

} // namespace micdup
