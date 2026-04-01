#pragma once

#include <string>

namespace micdup {

/// Copy UTF-8 text to the Windows clipboard.
bool clipboard_set_text(const std::string& text);

/// Simulate Ctrl+V to paste from clipboard into the foreground window.
void clipboard_autopaste();

/// Returns true if there is a foreground window that might accept text.
bool is_foreground_text_input();

} // namespace micdup
