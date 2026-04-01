#pragma once

#include <string>
#include <string_view>
#include <format>

namespace micdup {

enum class LogLevel { Debug, Info, Warning, Error, Fatal };

/// Initialise file logging to %APPDATA%\MicDup\logs\app-YYYY-MM-DD.log
void log_init(const std::wstring& app_data_dir);

/// Flush and close the log file.
void log_shutdown();

/// Write a single log line.
void log_write(LogLevel level, std::string_view message);

/// Convenience wrappers
template<typename... Args>
void log_info(std::format_string<Args...> fmt, Args&&... args) {
    log_write(LogLevel::Info, std::format(fmt, std::forward<Args>(args)...));
}
template<typename... Args>
void log_warn(std::format_string<Args...> fmt, Args&&... args) {
    log_write(LogLevel::Warning, std::format(fmt, std::forward<Args>(args)...));
}
template<typename... Args>
void log_error(std::format_string<Args...> fmt, Args&&... args) {
    log_write(LogLevel::Error, std::format(fmt, std::forward<Args>(args)...));
}
template<typename... Args>
void log_debug(std::format_string<Args...> fmt, Args&&... args) {
    log_write(LogLevel::Debug, std::format(fmt, std::forward<Args>(args)...));
}

} // namespace micdup
