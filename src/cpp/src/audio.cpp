#include "audio.h"
#include "log.h"

#include <windows.h>
#include <mmsystem.h>
#include <mutex>
#include <fstream>

#pragma comment(lib, "winmm.lib")

namespace micdup {

static std::string wstr_to_utf8(const std::wstring& wstr) {
    if (wstr.empty()) return {};
    int size = WideCharToMultiByte(CP_UTF8, 0, wstr.data(), (int)wstr.size(), nullptr, 0, nullptr, nullptr);
    std::string result(size, '\0');
    WideCharToMultiByte(CP_UTF8, 0, wstr.data(), (int)wstr.size(), result.data(), size, nullptr, nullptr);
    return result;
}

// WAV recording parameters optimised for Whisper
static constexpr WORD  CHANNELS    = 1;       // mono
static constexpr DWORD SAMPLE_RATE = 16000;   // 16 kHz
static constexpr WORD  BITS        = 16;      // 16-bit PCM
static constexpr int   NUM_BUFFERS = 4;
static constexpr DWORD BUF_SIZE    = SAMPLE_RATE * (BITS / 8) * CHANNELS / 4; // 0.25 s

// ── State ───────────────────────────────────────────────────────────────

static HWAVEIN        g_hWaveIn = nullptr;
static WAVEHDR        g_headers[NUM_BUFFERS]{};
static char           g_buffers[NUM_BUFFERS][BUF_SIZE];
static std::ofstream  g_file;
static std::wstring   g_path;
static std::mutex     g_mutex;
static bool           g_recording = false;
static DWORD          g_data_bytes = 0;

// ── WAV header helpers ──────────────────────────────────────────────────

#pragma pack(push, 1)
struct WavHeader {
    char     riff[4]        = {'R','I','F','F'};
    uint32_t file_size      = 0;  // filled on stop
    char     wave[4]        = {'W','A','V','E'};
    char     fmt_chunk[4]   = {'f','m','t',' '};
    uint32_t fmt_size       = 16;
    uint16_t audio_format   = 1; // PCM
    uint16_t num_channels   = CHANNELS;
    uint32_t sample_rate    = SAMPLE_RATE;
    uint32_t byte_rate      = SAMPLE_RATE * CHANNELS * (BITS / 8);
    uint16_t block_align    = CHANNELS * (BITS / 8);
    uint16_t bits_per_sample = BITS;
    char     data_chunk[4]  = {'d','a','t','a'};
    uint32_t data_size      = 0;  // filled on stop
};
#pragma pack(pop)

// ── Callback ────────────────────────────────────────────────────────────

static void CALLBACK wave_callback(HWAVEIN hwi, UINT uMsg, DWORD_PTR, DWORD_PTR dw1, DWORD_PTR) {
    if (uMsg != WIM_DATA) return;

    auto* hdr = reinterpret_cast<WAVEHDR*>(dw1);
    if (!hdr || hdr->dwBytesRecorded == 0) return;

    std::lock_guard lock(g_mutex);
    if (g_recording && g_file.is_open()) {
        g_file.write(hdr->lpData, hdr->dwBytesRecorded);
        g_data_bytes += hdr->dwBytesRecorded;
    }

    // Re-queue the buffer
    if (g_recording) {
        hdr->dwBytesRecorded = 0;
        hdr->dwFlags = 0;
        waveInPrepareHeader(hwi, hdr, sizeof(WAVEHDR));
        waveInAddBuffer(hwi, hdr, sizeof(WAVEHDR));
    }
}

// ── Public API ──────────────────────────────────────────────────────────

bool audio_start_recording(const std::wstring& output_path) {
    std::lock_guard lock(g_mutex);
    if (g_recording) {
        log_warn("Already recording");
        return false;
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

    // Configure waveform input
    WAVEFORMATEX wfx{};
    wfx.wFormatTag      = WAVE_FORMAT_PCM;
    wfx.nChannels       = CHANNELS;
    wfx.nSamplesPerSec  = SAMPLE_RATE;
    wfx.wBitsPerSample  = BITS;
    wfx.nBlockAlign     = wfx.nChannels * wfx.wBitsPerSample / 8;
    wfx.nAvgBytesPerSec = wfx.nSamplesPerSec * wfx.nBlockAlign;

    auto res = waveInOpen(&g_hWaveIn, WAVE_MAPPER, &wfx,
                          reinterpret_cast<DWORD_PTR>(wave_callback), 0,
                          CALLBACK_FUNCTION);
    if (res != MMSYSERR_NOERROR) {
        log_error("waveInOpen failed: {}", static_cast<int>(res));
        g_file.close();
        return false;
    }

    // Prepare and queue buffers
    for (int i = 0; i < NUM_BUFFERS; i++) {
        auto& h = g_headers[i];
        ZeroMemory(&h, sizeof(WAVEHDR));
        h.lpData         = g_buffers[i];
        h.dwBufferLength = BUF_SIZE;
        waveInPrepareHeader(g_hWaveIn, &h, sizeof(WAVEHDR));
        waveInAddBuffer(g_hWaveIn, &h, sizeof(WAVEHDR));
    }

    g_recording = true;
    waveInStart(g_hWaveIn);
    log_info("Recording started: {}", wstr_to_utf8(output_path));
    return true;
}

std::wstring audio_stop_recording() {
    {
        std::lock_guard lock(g_mutex);
        if (!g_recording) return {};
        g_recording = false;
    }

    // Stop and close the device
    waveInStop(g_hWaveIn);
    waveInReset(g_hWaveIn);
    for (auto& h : g_headers)
        waveInUnprepareHeader(g_hWaveIn, &h, sizeof(WAVEHDR));
    waveInClose(g_hWaveIn);
    g_hWaveIn = nullptr;

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

bool audio_is_recording() {
    return g_recording;
}

} // namespace micdup
