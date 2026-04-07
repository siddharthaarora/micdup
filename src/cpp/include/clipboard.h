#pragma once

#include <string>

namespace micdup {

/// Copy UTF-8 text to the clipboard.
bool clipboard_set_text(const std::string& text);

/// Simulate paste (Ctrl+V on Windows, Cmd+V on macOS).
void clipboard_autopaste();

/// Returns true if there is a foreground window that might accept text.
bool is_foreground_text_input();

} // namespace micdup
