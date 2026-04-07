#import <Foundation/Foundation.h>
#include "model_downloader.h"
#include "settings.h"
#include "log.h"

#include <filesystem>
#include <string>

namespace micdup {

std::string model_url(const std::string& model_name) {
    return "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-"
           + model_name + ".bin";
}

// Download a file synchronously using NSURLSession.
static bool download_file(const std::string& url, const std::string& output_path,
                          std::function<void(int64_t)> progress_cb) {
    @autoreleasepool {
        NSURL* nsurl = [NSURL URLWithString:[NSString stringWithUTF8String:url.c_str()]];
        if (!nsurl) {
            log_error("Invalid URL: {}", url);
            return false;
        }

        __block bool success = false;
        __block bool done = false;
        __block NSError* downloadError = nil;
        __block int64_t totalBytes = 0;

        dispatch_semaphore_t sem = dispatch_semaphore_create(0);

        NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForResource = 3600; // 1 hour for large models

        // Use a delegate-free approach with a download task
        NSURLSession* session = [NSURLSession sessionWithConfiguration:config];

        if (progress_cb) progress_cb(0);

        NSURLSessionDownloadTask* task = [session downloadTaskWithURL:nsurl
            completionHandler:^(NSURL* location, NSURLResponse* response, NSError* error) {
                if (error) {
                    downloadError = error;
                    done = true;
                    dispatch_semaphore_signal(sem);
                    return;
                }

                NSHTTPURLResponse* httpResp = (NSHTTPURLResponse*)response;
                if (httpResp.statusCode != 200) {
                    log_error("HTTP download returned status {}", (int)httpResp.statusCode);
                    done = true;
                    dispatch_semaphore_signal(sem);
                    return;
                }

                // Move downloaded file to output path
                NSFileManager* fm = [NSFileManager defaultManager];
                NSString* dest = [NSString stringWithUTF8String:output_path.c_str()];
                [fm removeItemAtPath:dest error:nil]; // remove if exists

                NSError* moveError = nil;
                if ([fm moveItemAtURL:location toURL:[NSURL fileURLWithPath:dest]
                        error:&moveError]) {
                    success = true;
                } else {
                    downloadError = moveError;
                }

                done = true;
                dispatch_semaphore_signal(sem);
            }];

        [task resume];

        // Poll progress while waiting
        while (!done) {
            if (dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC)) == 0) {
                break; // done
            }
            // Report progress
            int64_t received = task.countOfBytesReceived;
            if (received > totalBytes && progress_cb) {
                totalBytes = received;
                progress_cb(totalBytes);
            }
        }

        [session invalidateAndCancel];

        if (progress_cb) progress_cb(-1); // done signal

        if (downloadError) {
            log_error("Download failed: {}", [[downloadError localizedDescription] UTF8String]);
            return false;
        }

        return success;
    }
}

std::string ensure_model(const std::string& model_name,
                         std::function<void(int64_t)> progress_cb) {
    auto models_dir = get_models_dir();
    auto filename   = "ggml-" + model_name + ".bin";
    auto full_path  = models_dir + "/" + filename;

    // Already downloaded?
    if (std::filesystem::exists(full_path)) {
        log_info("Model already present: {}", filename);
        return full_path;
    }

    auto url_str = model_url(model_name);
    log_info("Downloading model '{}' from {}", model_name, url_str);

    // Download to a temp file first, then rename
    auto tmp_path = full_path + ".tmp";
    if (!download_file(url_str, tmp_path, progress_cb)) {
        log_error("Model download failed");
        std::filesystem::remove(tmp_path);
        return {};
    }

    std::error_code ec;
    std::filesystem::rename(tmp_path, full_path, ec);
    if (ec) {
        log_error("Failed to rename model file: {}", ec.message());
        return {};
    }

    log_info("Model downloaded: {}", filename);
    return full_path;
}

} // namespace micdup
