#import <AVFoundation/AVFoundation.h>
#include "audio.h"
#include "log.h"

#include <mutex>
#include <fstream>
#include <cstring>
#include <vector>
#include <cmath>

namespace micdup {

// WAV recording parameters optimised for Whisper
static constexpr uint16_t CHANNELS    = 1;       // mono
static constexpr uint32_t SAMPLE_RATE = 16000;   // 16 kHz
static constexpr uint16_t BITS        = 16;      // 16-bit PCM

// ── State ───────────────────────────────────────────────────────────────

static AVAudioEngine*     g_engine    = nil;
static std::ofstream      g_file;
static std::string        g_path;
static std::mutex         g_mutex;
static bool               g_recording = false;
static uint32_t           g_data_bytes = 0;

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

        // Use the input node's native output format for the tap
        AVAudioFormat* inputFormat = [inputNode outputFormatForBus:0];
        double inputRate = inputFormat.sampleRate;
        uint32_t inputChannels = (uint32_t)inputFormat.channelCount;
        log_info("Input format: {} Hz, {} channels", (int)inputRate, inputChannels);

        // Install tap using the input node's native format
        // We'll downsample and convert to mono int16 manually
        [inputNode installTapOnBus:0
            bufferSize:4096
            format:inputFormat
            block:^(AVAudioPCMBuffer* buffer, AVAudioTime* when) {
                @autoreleasepool {
                    std::lock_guard tapLock(g_mutex);
                    if (!g_recording || !g_file.is_open()) return;

                    const float* const* floatData = buffer.floatChannelData;
                    if (!floatData) return;

                    AVAudioFrameCount frameCount = buffer.frameLength;
                    double ratio = inputRate / (double)SAMPLE_RATE;

                    // Downsample: pick every ratio-th sample, mix to mono
                    AVAudioFrameCount outFrames = (AVAudioFrameCount)(frameCount / ratio);
                    if (outFrames == 0) return;

                    std::vector<int16_t> samples(outFrames);
                    for (AVAudioFrameCount i = 0; i < outFrames; i++) {
                        double srcIdx = i * ratio;
                        AVAudioFrameCount idx = (AVAudioFrameCount)srcIdx;
                        if (idx >= frameCount) idx = frameCount - 1;

                        // Mix all channels to mono
                        float sample = 0.0f;
                        for (uint32_t ch = 0; ch < inputChannels; ch++) {
                            sample += floatData[ch][idx];
                        }
                        sample /= (float)inputChannels;

                        // Clamp and convert to int16
                        if (sample > 1.0f) sample = 1.0f;
                        if (sample < -1.0f) sample = -1.0f;
                        samples[i] = (int16_t)(sample * 32767.0f);
                    }

                    uint32_t bytes = outFrames * sizeof(int16_t);
                    g_file.write(reinterpret_cast<const char*>(samples.data()), bytes);
                    g_data_bytes += bytes;
                }
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
