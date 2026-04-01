#include "settings_dialog.h"
#include "log.h"

#include <commctrl.h>
#include <string>
#include <vector>

#pragma comment(lib, "comctl32.lib")

namespace micdup {

// ── Control IDs ─────────────────────────────────────────────────────────

static constexpr int IDC_HOTKEY_LABEL   = 101;
static constexpr int IDC_HOTKEY_BTN     = 102;
static constexpr int IDC_MODEL_COMBO    = 103;
static constexpr int IDC_AUTOPASTE_CHK  = 104;
static constexpr int IDC_SAVE_BTN       = 105;
static constexpr int IDC_CANCEL_BTN     = 106;

static constexpr int DLG_WIDTH  = 380;
static constexpr int DLG_HEIGHT = 260;

// ── Dialog state ────────────────────────────────────────────────────────

struct DlgState {
    AppSettings* settings;
    uint32_t cap_modifiers;
    uint32_t cap_key;
    bool     capturing;
    bool     saved;
    HWND     hotkey_label;
    HWND     hotkey_btn;
};

static const char* MODELS[] = {"tiny", "base", "small", "medium", "large"};
static constexpr int NUM_MODELS = 5;

static int model_index(const std::string& name) {
    for (int i = 0; i < NUM_MODELS; i++)
        if (name == MODELS[i]) return i;
    return 1; // default: base
}

static void update_hotkey_label(DlgState* ds) {
    HotkeySettings hk{ds->cap_modifiers, ds->cap_key, true};
    auto text = format_hotkey(hk);
    auto wtext = std::wstring(text.begin(), text.end());
    SetWindowTextW(ds->hotkey_label, wtext.c_str());
}

// ── Window procedure ────────────────────────────────────────────────────

static LRESULT CALLBACK dlg_proc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    auto* ds = reinterpret_cast<DlgState*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));

    switch (msg) {
        case WM_CREATE: {
            auto* cs = reinterpret_cast<CREATESTRUCTW*>(lp);
            ds = static_cast<DlgState*>(cs->lpCreateParams);
            SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(ds));

            HFONT hFont = (HFONT)GetStockObject(DEFAULT_GUI_FONT);
            int y = 20;

            // Hotkey label
            auto label = CreateWindowW(L"STATIC", L"Hotkey:", WS_CHILD | WS_VISIBLE,
                                       20, y, 80, 20, hwnd, nullptr, nullptr, nullptr);
            SendMessage(label, WM_SETFONT, (WPARAM)hFont, TRUE);

            ds->hotkey_label = CreateWindowW(L"STATIC", L"", WS_CHILD | WS_VISIBLE,
                                             120, y, 200, 20, hwnd, (HMENU)(INT_PTR)IDC_HOTKEY_LABEL,
                                             nullptr, nullptr);
            SendMessage(ds->hotkey_label, WM_SETFONT, (WPARAM)hFont, TRUE);
            update_hotkey_label(ds);

            y += 35;

            ds->hotkey_btn = CreateWindowW(L"BUTTON", L"Press to change hotkey...",
                                           WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
                                           120, y, 200, 28, hwnd, (HMENU)(INT_PTR)IDC_HOTKEY_BTN,
                                           nullptr, nullptr);
            SendMessage(ds->hotkey_btn, WM_SETFONT, (WPARAM)hFont, TRUE);

            y += 50;

            // Model combo
            auto mlbl = CreateWindowW(L"STATIC", L"Whisper Model:", WS_CHILD | WS_VISIBLE,
                                      20, y + 3, 100, 20, hwnd, nullptr, nullptr, nullptr);
            SendMessage(mlbl, WM_SETFONT, (WPARAM)hFont, TRUE);

            HWND combo = CreateWindowW(L"COMBOBOX", nullptr,
                                       WS_CHILD | WS_VISIBLE | CBS_DROPDOWNLIST | WS_VSCROLL,
                                       120, y, 200, 150, hwnd, (HMENU)(INT_PTR)IDC_MODEL_COMBO,
                                       nullptr, nullptr);
            SendMessage(combo, WM_SETFONT, (WPARAM)hFont, TRUE);
            for (int i = 0; i < NUM_MODELS; i++) {
                auto wm = std::wstring(MODELS[i], MODELS[i] + strlen(MODELS[i]));
                SendMessageW(combo, CB_ADDSTRING, 0, (LPARAM)wm.c_str());
            }
            SendMessage(combo, CB_SETCURSEL, model_index(ds->settings->whisper.model), 0);

            y += 40;

            // Auto-paste checkbox
            HWND chk = CreateWindowW(L"BUTTON", L"Auto-paste transcription",
                                     WS_CHILD | WS_VISIBLE | BS_AUTOCHECKBOX,
                                     120, y, 220, 20, hwnd, (HMENU)(INT_PTR)IDC_AUTOPASTE_CHK,
                                     nullptr, nullptr);
            SendMessage(chk, WM_SETFONT, (WPARAM)hFont, TRUE);
            SendMessage(chk, BM_SETCHECK, ds->settings->behavior.auto_paste ? BST_CHECKED : BST_UNCHECKED, 0);

            y += 50;

            // Save / Cancel buttons
            HWND saveBtn = CreateWindowW(L"BUTTON", L"Save",
                                         WS_CHILD | WS_VISIBLE | BS_DEFPUSHBUTTON,
                                         180, y, 80, 28, hwnd, (HMENU)(INT_PTR)IDC_SAVE_BTN,
                                         nullptr, nullptr);
            SendMessage(saveBtn, WM_SETFONT, (WPARAM)hFont, TRUE);

            HWND cancelBtn = CreateWindowW(L"BUTTON", L"Cancel",
                                           WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
                                           270, y, 80, 28, hwnd, (HMENU)(INT_PTR)IDC_CANCEL_BTN,
                                           nullptr, nullptr);
            SendMessage(cancelBtn, WM_SETFONT, (WPARAM)hFont, TRUE);

            return 0;
        }

        case WM_COMMAND:
            if (!ds) break;
            switch (LOWORD(wp)) {
                case IDC_HOTKEY_BTN:
                    ds->capturing = true;
                    SetWindowTextW(ds->hotkey_label, L"Press a key combo...");
                    SetWindowTextW(ds->hotkey_btn, L"Listening...");
                    SetFocus(hwnd); // so we get WM_KEYDOWN
                    break;

                case IDC_SAVE_BTN: {
                    ds->settings->hotkey.modifiers = ds->cap_modifiers;
                    ds->settings->hotkey.key       = ds->cap_key;

                    HWND combo = GetDlgItem(hwnd, IDC_MODEL_COMBO);
                    int idx = (int)SendMessage(combo, CB_GETCURSEL, 0, 0);
                    if (idx >= 0 && idx < NUM_MODELS)
                        ds->settings->whisper.model = MODELS[idx];

                    HWND chk = GetDlgItem(hwnd, IDC_AUTOPASTE_CHK);
                    ds->settings->behavior.auto_paste =
                        (SendMessage(chk, BM_GETCHECK, 0, 0) == BST_CHECKED);

                    settings_save(*ds->settings);
                    ds->saved = true;
                    DestroyWindow(hwnd);
                    break;
                }

                case IDC_CANCEL_BTN:
                    DestroyWindow(hwnd);
                    break;
            }
            return 0;

        case WM_KEYDOWN:
            if (ds && ds->capturing) {
                // Ignore standalone modifier presses
                if (wp == VK_CONTROL || wp == VK_SHIFT || wp == VK_MENU ||
                    wp == VK_LWIN || wp == VK_RWIN ||
                    wp == VK_LCONTROL || wp == VK_RCONTROL ||
                    wp == VK_LSHIFT || wp == VK_RSHIFT ||
                    wp == VK_LMENU || wp == VK_RMENU)
                    return 0;

                uint32_t mods = 0;
                if (GetKeyState(VK_CONTROL) & 0x8000) mods |= MOD_CONTROL;
                if (GetKeyState(VK_SHIFT)   & 0x8000) mods |= MOD_SHIFT;
                if (GetKeyState(VK_MENU)    & 0x8000) mods |= MOD_ALT;

                ds->cap_modifiers = mods;
                ds->cap_key       = static_cast<uint32_t>(wp);
                ds->capturing     = false;

                update_hotkey_label(ds);
                SetWindowTextW(ds->hotkey_btn, L"Press to change hotkey...");
                return 0;
            }
            break;

        case WM_CLOSE:
            DestroyWindow(hwnd);
            return 0;

        case WM_DESTROY:
            return 0;
    }
    return DefWindowProcW(hwnd, msg, wp, lp);
}

// ── Public API ──────────────────────────────────────────────────────────

bool show_settings_dialog(HWND parent, AppSettings& settings) {
    static bool class_registered = false;
    HINSTANCE hInst = GetModuleHandleW(nullptr);

    if (!class_registered) {
        WNDCLASSEXW wc{};
        wc.cbSize        = sizeof(wc);
        wc.lpfnWndProc   = dlg_proc;
        wc.hInstance      = hInst;
        wc.hCursor       = LoadCursor(nullptr, IDC_ARROW);
        wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
        wc.lpszClassName = L"MicDupSettingsDlg";
        RegisterClassExW(&wc);
        class_registered = true;
    }

    DlgState ds{};
    ds.settings      = &settings;
    ds.cap_modifiers = settings.hotkey.modifiers;
    ds.cap_key       = settings.hotkey.key;
    ds.capturing     = false;
    ds.saved         = false;

    // Center on screen
    int sx = GetSystemMetrics(SM_CXSCREEN);
    int sy = GetSystemMetrics(SM_CYSCREEN);
    int x  = (sx - DLG_WIDTH)  / 2;
    int y  = (sy - DLG_HEIGHT) / 2;

    HWND hwnd = CreateWindowExW(WS_EX_DLGMODALFRAME | WS_EX_TOPMOST,
                                 L"MicDupSettingsDlg", L"MicDup Settings",
                                 WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_VISIBLE,
                                 x, y, DLG_WIDTH, DLG_HEIGHT,
                                 parent, nullptr, hInst, &ds);
    if (!hwnd) return false;

    // Modal message loop
    EnableWindow(parent, FALSE);
    MSG msg;
    while (GetMessageW(&msg, nullptr, 0, 0)) {
        if (!IsWindow(hwnd)) break;
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }
    EnableWindow(parent, TRUE);
    SetForegroundWindow(parent);

    return ds.saved;
}

} // namespace micdup
