#include "model_downloader.h"
#include "settings.h"
#include "log.h"

#include <windows.h>
#include <winhttp.h>
#include <fstream>
#include <filesystem>
#include <string>

#pragma comment(lib, "winhttp.lib")

namespace micdup {

static std::string wstr_to_utf8(const std::wstring& wstr) {
    if (wstr.empty()) return {};
    int size = WideCharToMultiByte(CP_UTF8, 0, wstr.data(), (int)wstr.size(), nullptr, 0, nullptr, nullptr);
    std::string result(size, '\0');
    WideCharToMultiByte(CP_UTF8, 0, wstr.data(), (int)wstr.size(), result.data(), size, nullptr, nullptr);
    return result;
}

std::string model_url(const std::string& model_name) {
    // Hugging Face ggml model URLs (same ones Whisper.net uses)
    return "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-"
           + model_name + ".bin";
}

// Download a file via WinHTTP with redirect following.
// Returns true on success.
static bool download_file(const std::wstring& url, const std::wstring& output_path,
                          std::function<void(int64_t)> progress_cb) {
    // Parse URL
    URL_COMPONENTS uc{};
    uc.dwStructSize     = sizeof(uc);
    wchar_t host[256]{}, path_buf[2048]{};
    uc.lpszHostName     = host;
    uc.dwHostNameLength = _countof(host);
    uc.lpszUrlPath      = path_buf;
    uc.dwUrlPathLength  = _countof(path_buf);
    if (!WinHttpCrackUrl(url.c_str(), 0, 0, &uc)) {
        log_error("Failed to parse URL");
        return false;
    }

    HINTERNET hSession = WinHttpOpen(L"MicDup/1.0", WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
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

    // Enable automatic redirect following
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

    // Check status code
    DWORD status = 0, sz = sizeof(status);
    WinHttpQueryHeaders(hRequest, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
                        WINHTTP_HEADER_NAME_BY_INDEX, &status, &sz, WINHTTP_NO_HEADER_INDEX);
    if (status != 200) {
        log_error("HTTP download returned status {}", status);
        WinHttpCloseHandle(hRequest);
        WinHttpCloseHandle(hConnect);
        WinHttpCloseHandle(hSession);
        return false;
    }

    std::ofstream out(output_path, std::ios::binary);
    if (!out) {
        WinHttpCloseHandle(hRequest);
        WinHttpCloseHandle(hConnect);
        WinHttpCloseHandle(hSession);
        return false;
    }

    char buf[65536];
    DWORD bytes_read;
    int64_t total = 0;
    if (progress_cb) progress_cb(0);

    while (WinHttpReadData(hRequest, buf, sizeof(buf), &bytes_read) && bytes_read > 0) {
        out.write(buf, bytes_read);
        total += bytes_read;
        if (progress_cb) progress_cb(total);
    }

    out.close();
    if (progress_cb) progress_cb(-1); // done

    WinHttpCloseHandle(hRequest);
    WinHttpCloseHandle(hConnect);
    WinHttpCloseHandle(hSession);
    return true;
}

std::string ensure_model(const std::string& model_name,
                         std::function<void(int64_t)> progress_cb) {
    auto models_dir = get_models_dir();
    auto filename   = "ggml-" + model_name + ".bin";
    auto full_path  = models_dir + L"\\" + std::wstring(filename.begin(), filename.end());

    // Already downloaded?
    if (std::filesystem::exists(full_path)) {
        log_info("Model already present: {}", filename);
        return wstr_to_utf8(full_path);
    }

    auto url_str = model_url(model_name);
    log_info("Downloading model '{}' from {}", model_name, url_str);

    auto wurl = std::wstring(url_str.begin(), url_str.end());

    // Download to a temp file first, then rename (atomic-ish)
    auto tmp_path = full_path + L".tmp";
    if (!download_file(wurl, tmp_path, progress_cb)) {
        log_error("Model download failed");
        std::filesystem::remove(tmp_path);
        return {};
    }

    std::filesystem::rename(tmp_path, full_path);
    log_info("Model downloaded: {}", filename);
    return wstr_to_utf8(full_path);
}

} // namespace micdup
