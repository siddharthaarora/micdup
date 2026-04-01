#include "log.h"

#include <windows.h>
#include <fstream>
#include <mutex>
#include <chrono>
#include <ctime>

namespace micdup {

static std::ofstream g_log_file;
static std::mutex    g_log_mutex;

static std::string timestamp() {
    auto now = std::chrono::system_clock::now();
    auto t   = std::chrono::system_clock::to_time_t(now);
    struct tm local {};
    localtime_s(&local, &t);
    char buf[32];
    std::strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", &local);
    return buf;
}

static std::string date_string() {
    auto now = std::chrono::system_clock::now();
    auto t   = std::chrono::system_clock::to_time_t(now);
    struct tm local {};
    localtime_s(&local, &t);
    char buf[16];
    std::strftime(buf, sizeof(buf), "%Y-%m-%d", &local);
    return buf;
}

static const char* level_str(LogLevel lv) {
    switch (lv) {
        case LogLevel::Debug:   return "DBG";
        case LogLevel::Info:    return "INF";
        case LogLevel::Warning: return "WRN";
        case LogLevel::Error:   return "ERR";
        case LogLevel::Fatal:   return "FTL";
    }
    return "???";
}

void log_init(const std::wstring& app_data_dir) {
    std::lock_guard lock(g_log_mutex);

    // Create logs subdirectory
    auto logs_dir = app_data_dir + L"\\logs";
    CreateDirectoryW(app_data_dir.c_str(), nullptr);
    CreateDirectoryW(logs_dir.c_str(), nullptr);

    // Build log file path: app-YYYY-MM-DD.log
    auto ds = date_string();
    auto path = logs_dir + L"\\app-" + std::wstring(ds.begin(), ds.end()) + L".log";

    g_log_file.open(path, std::ios::app);
}

void log_shutdown() {
    std::lock_guard lock(g_log_mutex);
    if (g_log_file.is_open())
        g_log_file.close();
}

void log_write(LogLevel level, std::string_view message) {
    std::lock_guard lock(g_log_mutex);
    if (!g_log_file.is_open()) return;

    g_log_file << "[" << timestamp() << "] [" << level_str(level) << "] "
               << message << "\n";
    g_log_file.flush();
}

} // namespace micdup
