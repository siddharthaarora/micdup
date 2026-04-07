#import <Foundation/Foundation.h>
#include "updater.h"
#include "log.h"

#include <filesystem>
#include <fstream>
#include <cstdlib>
#include <cstring>
#include <sys/stat.h>

namespace micdup {

const char* app_version() {
    return MICDUP_VERSION;
}

// ── Tiny JSON helpers ───────────────────────────────────────────────────

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
    sscanf(clean.c_str(), "%d.%d.%d", &v.major, &v.minor, &v.patch);
    return v;
}

static bool is_newer(const SemVer& remote, const SemVer& local) {
    if (remote.major != local.major) return remote.major > local.major;
    if (remote.minor != local.minor) return remote.minor > local.minor;
    return remote.patch > local.patch;
}

// ── HTTP GET using NSURLSession ─────────────────────────────────────────

static std::string http_get(const std::string& url) {
    @autoreleasepool {
        NSURL* nsurl = [NSURL URLWithString:[NSString stringWithUTF8String:url.c_str()]];
        if (!nsurl) return {};

        __block std::string result;
        dispatch_semaphore_t sem = dispatch_semaphore_create(0);

        NSURLSessionDataTask* task = [[NSURLSession sharedSession]
            dataTaskWithURL:nsurl
            completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
                if (!error && data) {
                    result = std::string((const char*)[data bytes], [data length]);
                }
                dispatch_semaphore_signal(sem);
            }];
        [task resume];
        dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC));
        return result;
    }
}

// ── Download file ───────────────────────────────────────────────────────

static bool download_file(const std::string& url, const std::string& output) {
    @autoreleasepool {
        NSURL* nsurl = [NSURL URLWithString:[NSString stringWithUTF8String:url.c_str()]];
        if (!nsurl) return false;

        __block bool success = false;
        dispatch_semaphore_t sem = dispatch_semaphore_create(0);

        NSURLSessionDownloadTask* task = [[NSURLSession sharedSession]
            downloadTaskWithURL:nsurl
            completionHandler:^(NSURL* location, NSURLResponse* response, NSError* error) {
                if (error || !location) {
                    dispatch_semaphore_signal(sem);
                    return;
                }

                NSString* dest = [NSString stringWithUTF8String:output.c_str()];
                [[NSFileManager defaultManager] removeItemAtPath:dest error:nil];
                NSError* moveErr = nil;
                success = [[NSFileManager defaultManager]
                    moveItemAtURL:location toURL:[NSURL fileURLWithPath:dest] error:&moveErr];
                dispatch_semaphore_signal(sem);
            }];
        [task resume];
        dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 600 * NSEC_PER_SEC));
        return success;
    }
}

// ── Public API ──────────────────────────────────────────────────────────

std::optional<ReleaseInfo> check_for_update() {
    try {
        auto json = http_get("https://api.github.com/repos/siddharthaarora/micdup/releases/latest");
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

        // Find the macOS asset
        ReleaseInfo info;
        info.tag  = tag;
        info.name = json_str(json, "name");

        // Determine current architecture
#if defined(__aarch64__) || defined(__arm64__)
        const char* arch_tag = "mac-arm64";
#else
        const char* arch_tag = "mac-x64";
#endif

        std::string search = "browser_download_url";
        size_t pos = 0;
        while ((pos = json.find(search, pos)) != std::string::npos) {
            auto q1 = json.find('"', pos + search.size() + 2);
            auto q2 = json.find('"', q1 + 1);
            if (q1 != std::string::npos && q2 != std::string::npos) {
                auto url = json.substr(q1 + 1, q2 - q1 - 1);
                if (url.find(arch_tag) != std::string::npos &&
                    url.find(".zip") != std::string::npos) {
                    info.download_url = url;
                    break;
                }
            }
            pos = q2;
        }

        if (info.download_url.empty()) {
            log_warn("No {} asset found in release {}", arch_tag, tag);
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
        @autoreleasepool {
            NSString* tmpDir = NSTemporaryDirectory();
            std::string tmp = [tmpDir UTF8String];

            auto zip_path = tmp + "micdup-update.zip";

            log_info("Downloading update from {}", release.download_url);
            if (!download_file(release.download_url, zip_path)) {
                log_error("Update download failed");
                return false;
            }

            // Get current executable path
            auto exe_path = std::string([[[NSBundle mainBundle] executablePath] UTF8String]);
            auto bundle_path = std::string([[[NSBundle mainBundle] bundlePath] UTF8String]);
            auto current_dir = std::filesystem::path(bundle_path).parent_path().string();
            pid_t pid = getpid();

            // Write a shell script that replaces the app after we exit
            auto script_path = tmp + "micdup-update.sh";
            std::ofstream script(script_path);
            script << "#!/bin/bash\n"
                   << "echo 'Waiting for MicDup to exit...'\n"
                   << "while kill -0 " << pid << " 2>/dev/null; do sleep 1; done\n"
                   << "sleep 1\n"
                   << "echo 'Extracting update...'\n"
                   << "cd \"" << current_dir << "\"\n"
                   << "unzip -o \"" << zip_path << "\"\n"
                   << "echo 'Starting updated MicDup...'\n"
                   << "open \"" << bundle_path << "\" --args --updated\n"
                   << "rm -f \"" << zip_path << "\"\n"
                   << "rm -f \"" << script_path << "\"\n";
            script.close();

            // Make script executable and launch it
            chmod(script_path.c_str(), 0755);

            NSTask* task = [[NSTask alloc] init];
            task.executableURL = [NSURL fileURLWithPath:@"/bin/bash"];
            task.arguments = @[[NSString stringWithUTF8String:script_path.c_str()]];
            task.standardOutput = [NSFileHandle fileHandleWithNullDevice];
            task.standardError = [NSFileHandle fileHandleWithNullDevice];

            NSError* error = nil;
            [task launchAndReturnError:&error];
            if (error) {
                log_error("Failed to launch update script: {}",
                          [[error localizedDescription] UTF8String]);
                return false;
            }

            log_info("Update script launched, shutting down...");
            return true;
        }
    } catch (...) {
        log_error("Failed to apply update");
        return false;
    }
}

} // namespace micdup
