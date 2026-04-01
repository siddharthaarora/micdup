#include "clipboard.h"
#include "log.h"

#include <windows.h>
#include <string>

namespace micdup {

bool clipboard_set_text(const std::string& text) {
    if (text.empty()) return false;

    // Convert UTF-8 to wide string
    int wlen = MultiByteToWideChar(CP_UTF8, 0, text.c_str(), -1, nullptr, 0);
    if (wlen <= 0) return false;

    HGLOBAL hMem = GlobalAlloc(GMEM_MOVEABLE, wlen * sizeof(wchar_t));
    if (!hMem) return false;

    auto* ptr = static_cast<wchar_t*>(GlobalLock(hMem));
    MultiByteToWideChar(CP_UTF8, 0, text.c_str(), -1, ptr, wlen);
    GlobalUnlock(hMem);

    if (!OpenClipboard(nullptr)) {
        GlobalFree(hMem);
        return false;
    }

    EmptyClipboard();
    SetClipboardData(CF_UNICODETEXT, hMem);
    CloseClipboard();

    log_info("Copied {} chars to clipboard", text.size());
    return true;
}

bool is_foreground_text_input() {
    return GetForegroundWindow() != nullptr;
}

void clipboard_autopaste() {
    // Short delay to ensure clipboard is settled
    Sleep(100);

    // Simulate Ctrl+V
    INPUT inputs[4]{};

    // Press Ctrl
    inputs[0].type       = INPUT_KEYBOARD;
    inputs[0].ki.wVk     = VK_CONTROL;

    // Press V
    inputs[1].type       = INPUT_KEYBOARD;
    inputs[1].ki.wVk     = 'V';

    // Release V
    inputs[2].type       = INPUT_KEYBOARD;
    inputs[2].ki.wVk     = 'V';
    inputs[2].ki.dwFlags = KEYEVENTF_KEYUP;

    // Release Ctrl
    inputs[3].type       = INPUT_KEYBOARD;
    inputs[3].ki.wVk     = VK_CONTROL;
    inputs[3].ki.dwFlags = KEYEVENTF_KEYUP;

    SendInput(4, inputs, sizeof(INPUT));
    log_info("Auto-paste executed (Ctrl+V)");
}

} // namespace micdup
