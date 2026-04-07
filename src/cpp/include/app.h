#pragma once

#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#endif

namespace micdup {

#ifdef _WIN32
/// Run the application.  Returns the process exit code.
int app_run(HINSTANCE hInstance, bool just_updated);
#elif defined(__APPLE__)
/// Run the application.  Returns the process exit code.
int app_run(bool just_updated);
#endif

} // namespace micdup
