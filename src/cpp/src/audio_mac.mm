#import <AVFoundation/AVFoundation.h>
#include "audio.h"
#include "log.h"

#include <mutex>
#include <fstream>
#include <cstring>

namespace micdup {

// WAV recording parameters optimised for Whisper
static constexpr uint16_t CHANNELS    = 1;       // mono
static constexpr uint32_t SAMPLE_RATE = 16000;   // 16 kHz
static constexpr uint16_t BITS        = 16;      // 16-bit PCM

// ── State ───────────────────────────────────────────────────────────────

static AVAudioEngine*    g_engine    = nil;
static std::ofstream     g_file;
static std::string       g_path;
static std::mutex        g_mutex;
static bool              g_recording = false;
static uint32_t          g_data_bytes = 0;

// ── WAV header ──────────────────────────────────────────────────────────

#pragma pack(push, 1)
struct WavHeader {
    char     riff[4]         = {'R','I','F','F'};
    uint32_t file_size       = 0;
    char     wave[4]         = {'W','A','V','E'};
    char     fmt_chunk[4]    = {'f','m','t',' '};
    uint32_t fmt_size        = 16;
    uint16_t audio_format    = 1; // PCM
    uint16_t num_channels    = CHANNELS;
    uint32_t sample_rate     = SAMPLE_RATE;
    uint32_t byte_rate       = SAMPLE_RATE * CHANNELS * (BITS / 8);
    uint16_t block_align     = CHANNELS * (BITS / 8);
    uint16_t bits_per_sample = BITS;
    char     data_chunk[4]   = {'d','a','t','a'};
    uint32_t data_size       = 0;
};
#pragma pack(pop)

// ── Public API ──────────────────────────────────────────────────────────

bool audio_start_recording(const std::string& output_path) {
    @autoreleasepool {
        std::lock_guard lock(g_mutex);
        if (g_recording) {
            log_warn("Already recording");
            return false;
        }

        // Request microphone permission if needed
        switch ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio]) {
            case AVAuthorizationStatusNotDetermined: {
                __block bool granted = false;
                dispatch_semaphore_t sem = dispatch_semaphore_create(0);
                [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL g) {
                    granted = g;
                    dispatch_semaphore_signal(sem);
                }];
                dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
                if (!granted) {
                    log_error("Microphone permission denied");
                    return false;
                }
                break;
            }
            case AVAuthorizationStatusDenied:
            case AVAuthorizationStatusRestricted:
                log_error("Microphone permission denied");
                return false;
            case AVAuthorizationStatusAuthorized:
                break;
        }

        // Open output file and write placeholder WAV header
        g_file.open(output_path, std::ios::binary);
        if (!g_file.is_open()) {
            log_error("Cannot open audio file for writing");
            return false;
        }
        g_path = output_path;
        g_data_bytes = 0;
        WavHeader hdr{};
        g_file.write(reinterpret_cast<char*>(&hdr), sizeof(hdr));

        // Set up AVAudioEngine
        g_engine = [[AVAudioEngine alloc] init];
        AVAudioInputNode* inputNode = [g_engine inputNode];

        // Create format: 16 kHz, mono, 16-bit integer PCM
        AVAudioFormat* recordFormat = [[AVAudioFormat alloc]
            initWithCommonFormat:AVAudioPCMFormatInt16
            sampleRate:SAMPLE_RATE
            channels:CHANNELS
            interleaved:YES];

        // Install tap on the input node
        [inputNode installTapOnBus:0
            bufferSize:4096
            format:recordFormat
            block:^(AVAudioPCMBuffer* buffer, AVAudioTime* when) {
                std::lock_guard tapLock(g_mutex);
                if (!g_recording || !g_file.is_open()) return;

                auto* data = buffer.int16ChannelData;
                if (!data) return;

                uint32_t bytes = buffer.frameLength * sizeof(int16_t);
                g_file.write(reinterpret_cast<const char*>(data[0]), bytes);
                g_data_bytes += bytes;
            }];

        NSError* error = nil;
        if (![g_engine startAndReturnError:&error]) {
            log_error("Failed to start audio engine: {}",
                      [[error localizedDescription] UTF8String]);
            g_file.close();
            g_engine = nil;
            return false;
        }

        g_recording = true;
        log_info("Recording started: {}", output_path);
        return true;
    }
}

std::string audio_stop_recording() {
    @autoreleasepool {
        {
            std::lock_guard lock(g_mutex);
            if (!g_recording) return {};
            g_recording = false;
        }

        // Stop the engine and remove the tap
        if (g_engine) {
            [[g_engine inputNode] removeTapOnBus:0];
            [g_engine stop];
            g_engine = nil;
        }

        // Fix up the WAV header with actual data size
        g_file.seekp(0);
        WavHeader hdr{};
        hdr.data_size = g_data_bytes;
        hdr.file_size = static_cast<uint32_t>(sizeof(WavHeader) - 8 + g_data_bytes);
        g_file.write(reinterpret_cast<char*>(&hdr), sizeof(hdr));
        g_file.close();

        log_info("Recording stopped, {} bytes written", g_data_bytes);
        return g_path;
    }
}

bool audio_is_recording() {
    return g_recording;
}

} // namespace micdup
