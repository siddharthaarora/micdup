#include "updater.h"
#include "log.h"

#include <windows.h>
#include <winhttp.h>
#include <shlobj.h>
#include <fstream>
#include <sstream>
#include <filesystem>
#include <cstdlib>

#pragma comment(lib, "winhttp.lib")

namespace micdup {

const char* app_version() {
    return MICDUP_VERSION;
}

// ── Tiny JSON helpers for GitHub API ────────────────────────────────────

static std::string json_str(const std::string& json, const std::string& key) {
    auto kpos = json.find("\"" + key + "\"");
    if (kpos == std::string::npos) return {};
    auto colon = json.find(':', kpos + key.size() + 2);
    if (colon == std::string::npos) return {};
    auto q1 = json.find('"', colon + 1);
    if (q1 == std::string::npos) return {};
    auto q2 = json.find('"', q1 + 1);
    if (q2 == std::string::npos) return {};
    return json.substr(q1 + 1, q2 - q1 - 1);
}

static bool json_bool(const std::string& json, const std::string& key) {
    auto kpos = json.find("\"" + key + "\"");
    if (kpos == std::string::npos) return false;
    return json.find("true", kpos) < json.find('\n', kpos);
}

// ── Version comparison ──────────────────────────────────────────────────

struct SemVer { int major = 0, minor = 0, patch = 0; };

static SemVer parse_version(const std::string& s) {
    SemVer v;
    std::string clean = s;
    if (!clean.empty() && (clean[0] == 'v' || clean[0] == 'V')) clean.erase(0, 1);
    auto dash = clean.find('-');
    if (dash != std::string::npos) clean = clean.substr(0, dash);
    sscanf_s(clean.c_str(), "%d.%d.%d", &v.major, &v.minor, &v.patch);
    return v;
}

static bool is_newer(const SemVer& remote, const SemVer& local) {
    if (remote.major != local.major) return remote.major > local.major;
    if (remote.minor != local.minor) return remote.minor > local.minor;
    return remote.patch > local.patch;
}

// ── WinHTTP GET helper ──────────────────────────────────────────────────

static std::string http_get(const wchar_t* host, const wchar_t* path) {
    HINTERNET hSession = WinHttpOpen(L"MicDup-Update/1.0",
                                      WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
                                      WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
    if (!hSession) return {};

    HINTERNET hConnect = WinHttpConnect(hSession, host, INTERNET_DEFAULT_HTTPS_PORT, 0);
    if (!hConnect) { WinHttpCloseHandle(hSession); return {}; }

    HINTERNET hRequest = WinHttpOpenRequest(hConnect, L"GET", path, nullptr,
                                             WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES,
                                             WINHTTP_FLAG_SECURE);
    if (!hRequest) {
        WinHttpCloseHandle(hConnect);
        WinHttpCloseHandle(hSession);
        return {};
    }

    if (!WinHttpSendRequest(hRequest, WINHTTP_NO_ADDITIONAL_HEADERS, 0,
                             WINHTTP_NO_REQUEST_DATA, 0, 0, 0) ||
        !WinHttpReceiveResponse(hRequest, nullptr)) {
        WinHttpCloseHandle(hRequest);
        WinHttpCloseHandle(hConnect);
        WinHttpCloseHandle(hSession);
        return {};
    }

    std::string result;
    char buf[8192];
    DWORD bytes_read;
    while (WinHttpReadData(hRequest, buf, sizeof(buf), &bytes_read) && bytes_read > 0) {
        result.append(buf, bytes_read);
    }

    WinHttpCloseHandle(hRequest);
    WinHttpCloseHandle(hConnect);
    WinHttpCloseHandle(hSession);
    return result;
}

// ── Download a file ─────────────────────────────────────────────────────

static bool download_file(const std::wstring& url, const std::wstring& output) {
    URL_COMPONENTS uc{};
    uc.dwStructSize     = sizeof(uc);
    wchar_t host[256]{}, path_buf[2048]{};
    uc.lpszHostName     = host;
    uc.dwHostNameLength = _countof(host);
    uc.lpszUrlPath      = path_buf;
    uc.dwUrlPathLength  = _countof(path_buf);
    if (!WinHttpCrackUrl(url.c_str(), 0, 0, &uc)) return false;

    HINTERNET hSession = WinHttpOpen(L"MicDup-Update/1.0",
                                      WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
                                      WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
    if (!hSession) return false;

    HINTERNET hConnect = WinHttpConnect(hSession, host, uc.nPort, 0);
    if (!hConnect) { WinHttpCloseHandle(hSession); return false; }

    DWORD flags = (uc.nScheme == INTERNET_SCHEME_HTTPS) ? WINHTTP_FLAG_SECURE : 0;
    HINTERNET hRequest = WinHttpOpenRequest(hConnect, L"GET", path_buf, nullptr,
                                             WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES,
                                             flags);
    if (!hRequest) {
        WinHttpCloseHandle(hConnect);
        WinHttpCloseHandle(hSession);
        return false;
    }

    DWORD opt = WINHTTP_OPTION_REDIRECT_POLICY_ALWAYS;
    WinHttpSetOption(hRequest, WINHTTP_OPTION_REDIRECT_POLICY, &opt, sizeof(opt));

    if (!WinHttpSendRequest(hRequest, WINHTTP_NO_ADDITIONAL_HEADERS, 0,
                             WINHTTP_NO_REQUEST_DATA, 0, 0, 0) ||
        !WinHttpReceiveResponse(hRequest, nullptr)) {
        WinHttpCloseHandle(hRequest);
        WinHttpCloseHandle(hConnect);
        WinHttpCloseHandle(hSession);
        return false;
    }

    std::ofstream out(output, std::ios::binary);
    char buf[65536];
    DWORD bytes_read;
    while (WinHttpReadData(hRequest, buf, sizeof(buf), &bytes_read) && bytes_read > 0) {
        out.write(buf, bytes_read);
    }
    out.close();

    WinHttpCloseHandle(hRequest);
    WinHttpCloseHandle(hConnect);
    WinHttpCloseHandle(hSession);
    return true;
}

// ── Public API ──────────────────────────────────────────────────────────

std::optional<ReleaseInfo> check_for_update() {
    try {
        auto json = http_get(L"api.github.com",
                             L"/repos/siddharthaarora/micdup/releases/latest");
        if (json.empty()) return std::nullopt;

        if (json_bool(json, "draft") || json_bool(json, "prerelease"))
            return std::nullopt;

        auto tag = json_str(json, "tag_name");
        if (tag.empty()) return std::nullopt;

        auto remote = parse_version(tag);
        auto local  = parse_version(app_version());

        if (!is_newer(remote, local)) {
            log_info("App is up to date ({})", app_version());
            return std::nullopt;
        }

        // Find the win-x64 zip asset
        // Search for browser_download_url containing "win-x64" and ".zip"
        ReleaseInfo info;
        info.tag  = tag;
        info.name = json_str(json, "name");

        // Find asset URL — scan for browser_download_url entries
        std::string search = "browser_download_url";
        size_t pos = 0;
        while ((pos = json.find(search, pos)) != std::string::npos) {
            auto q1 = json.find('"', pos + search.size() + 2);
            auto q2 = json.find('"', q1 + 1);
            if (q1 != std::string::npos && q2 != std::string::npos) {
                auto url = json.substr(q1 + 1, q2 - q1 - 1);
                if (url.find("win-x64") != std::string::npos &&
                    url.find(".zip") != std::string::npos) {
                    info.download_url = url;
                    break;
                }
            }
            pos = q2;
        }

        if (info.download_url.empty()) {
            log_warn("No win-x64 asset found in release {}", tag);
            return std::nullopt;
        }

        log_info("Update available: {} -> {}", app_version(), tag);
        return info;
    } catch (...) {
        log_warn("Failed to check for updates");
        return std::nullopt;
    }
}

bool download_and_apply_update(const ReleaseInfo& release) {
    try {
        wchar_t tmp[MAX_PATH]{};
        GetTempPathW(MAX_PATH, tmp);
        std::wstring tmp_dir(tmp);

        auto zip_path = tmp_dir + L"micdup-update.zip";
        auto wurl = std::wstring(release.download_url.begin(), release.download_url.end());

        log_info("Downloading update from {}", release.download_url);
        if (!download_file(wurl, zip_path)) {
            log_error("Update download failed");
            return false;
        }

        // Get current exe path
        wchar_t exe_path[MAX_PATH]{};
        GetModuleFileNameW(nullptr, exe_path, MAX_PATH);
        std::wstring current_dir = std::filesystem::path(exe_path).parent_path().wstring();
        DWORD pid = GetCurrentProcessId();

        // Write a CMD script that replaces the exe after we exit
        auto script_path = tmp_dir + L"micdup-update.cmd";
        std::wofstream script(script_path);
        script << L"@echo off\n"
               << L"echo Waiting for MicDup to exit...\n"
               << L":waitloop\n"
               << L"tasklist /fi \"PID eq " << pid << L"\" 2>nul | find \"" << pid << L"\" >nul\n"
               << L"if not errorlevel 1 (\n"
               << L"    timeout /t 1 /nobreak >nul\n"
               << L"    goto waitloop\n"
               << L")\n"
               << L"timeout /t 2 /nobreak >nul\n"
               << L"echo Extracting update...\n"
               << L"powershell -Command \"Expand-Archive -Path '" << zip_path << L"' -DestinationPath '" << current_dir << L"' -Force\"\n"
               << L"echo Starting updated MicDup...\n"
               << L"start \"\" \"" << exe_path << L"\" --updated\n"
               << L"del \"" << zip_path << L"\" 2>nul\n"
               << L"del \"%~f0\"\n";
        script.close();

        STARTUPINFOW si{};
        si.cb = sizeof(si);
        si.dwFlags = STARTF_USESHOWWINDOW;
        si.wShowWindow = SW_HIDE;
        PROCESS_INFORMATION pi{};

        std::wstring cmd = L"cmd.exe /c \"" + script_path + L"\"";
        CreateProcessW(nullptr, cmd.data(), nullptr, nullptr, FALSE,
                       CREATE_NO_WINDOW, nullptr, nullptr, &si, &pi);
        CloseHandle(pi.hProcess);
        CloseHandle(pi.hThread);

        log_info("Update script launched, shutting down...");
        return true;
    } catch (...) {
        log_error("Failed to apply update");
        return false;
    }
}

} // namespace micdup
