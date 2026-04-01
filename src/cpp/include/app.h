#pragma once

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>

namespace micdup {

/// Run the application.  Returns the process exit code.
int app_run(HINSTANCE hInstance, bool just_updated);

} // namespace micdup
