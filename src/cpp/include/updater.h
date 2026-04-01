#pragma once

#include <string>
#include <optional>

namespace micdup {

struct ReleaseInfo {
    std::string tag;
    std::string download_url;   // win-x64 zip asset URL
    std::string name;
};

/// Returns the current compiled-in version string.
const char* app_version();

/// Check GitHub for a newer release.  Returns nullopt if up-to-date.
std::optional<ReleaseInfo> check_for_update();

/// Download the update zip and launch a helper script that replaces the exe
/// after this process exits.  Returns true → caller should exit.
bool download_and_apply_update(const ReleaseInfo& release);

} // namespace micdup
