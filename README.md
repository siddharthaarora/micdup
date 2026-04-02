# MicDup

**Think it. Say it. Ship it. Voice-to-text for Windows that keeps your data yours.**

MicDup is a single-file Windows application that transcribes your speech to text using [OpenAI's Whisper](https://github.com/openai/whisper) model running entirely on your machine. Press a hotkey, speak, press again — your words are in your clipboard and optionally pasted where you're typing. No audio ever leaves your computer.

> Inspired by [Mic'd Up](https://github.com/micd-up/micd-up), a fantastic macOS menu bar app by [@micd-up](https://github.com/micd-up). A colleague built that for Mac — I built MicDup to bring the same experience to Windows.

---

## Why MicDup?

### Talk to your AI, don't type at it

We live in the age of AI-assisted development. Tools like Claude, Copilot, and ChatGPT are writing code alongside us. But there's an irony: while AI makes us faster at coding, we're still bottlenecked by *typing our prompts*. Ideas move at the speed of thought — typing moves at 80 words per minute.

MicDup removes that bottleneck. Speak your idea, your prompt, your instruction — and it flows directly into whatever you're working in. No context switching. No slowing down to type. Just think, speak, and ship. The result isn't just faster — it's more creative. When you're not wrestling with a keyboard, your ideas come out more naturally, more completely, and with less friction.

### Your voice, your machine, your data

Every major voice-to-text tool sends your audio to the cloud. Your meetings, your brainstorming sessions, your private thoughts — all processed on someone else's server.

MicDup is different:

- **100% local** — Whisper runs on your CPU/GPU. No internet needed after initial model download.
- **Zero data collection** — No telemetry, no analytics, no accounts, no sign-ups.
- **Single executable** — One ~2MB file. Copy it anywhere. No installer, no runtime dependencies.
- **Open source** — Read every line of code. Build it yourself if you want.

Your voice stays on your machine. Period.

---

## Quick Start

1. Download `MicDup-vX.X.X-win-x64-cpu.zip` from [Releases](https://github.com/siddharthaarora/micdup/releases)
2. Extract `MicDup.exe` anywhere
3. Run it — a microphone icon appears in your system tray
4. Press **Ctrl+Shift+Space** to start recording
5. Speak
6. Press **Ctrl+Shift+Space** again
7. Your text is in the clipboard (and auto-pasted if a text field is focused)

First run downloads the Whisper model (~150MB for "base"). After that, no internet is needed.

---

## Features

- **Global Hotkey** — Ctrl+Shift+Space (configurable) to start/stop recording
- **System Tray** — Unobtrusive background operation with visual status indicators
- **Local Transcription** — OpenAI Whisper via [whisper.cpp](https://github.com/ggerganov/whisper.cpp), running natively
- **Auto-Paste** — Automatically pastes transcribed text into the focused window
- **Clipboard Integration** — Text always copied to clipboard
- **GPU Acceleration** — Vulkan build available for faster transcription on AMD/NVIDIA/Intel GPUs
- **Multiple Model Sizes** — Choose between speed (tiny) and accuracy (large)
- **Auto-Update** — Checks GitHub releases and updates in-place
- **Zero Dependencies** — Single static executable, no runtime needed

---

## Downloads

| Build | Best For | GPU Support |
|-------|----------|-------------|
| **[CPU](https://github.com/siddharthaarora/micdup/releases/latest)** | Works everywhere | CPU only |
| **[Vulkan](https://github.com/siddharthaarora/micdup/releases/latest)** | Faster transcription | AMD, NVIDIA, Intel GPUs |

Both are a single `MicDup.exe` file. No installer needed.

---

## Whisper Models

Models are auto-downloaded on first use and stored in `%LOCALAPPDATA%\MicDup\Models\`.

| Model | Download | Speed | Accuracy | Best For |
|-------|----------|-------|----------|----------|
| `tiny` | ~75 MB | ~1s | Good | Quick notes, commands |
| `base` | ~150 MB | ~2s | Better | **Recommended for daily use** |
| `small` | ~500 MB | ~5s | Great | Dictation, longer text |
| `medium` | ~1.5 GB | ~15s | Excellent | Professional transcription |
| `large` | ~3 GB | ~30s | Best | Maximum accuracy |

Change model: right-click tray icon > Settings > Whisper Model.

---

## Configuration

Settings are stored in `%APPDATA%\MicDup\settings.json` and editable via the Settings dialog (right-click tray icon > Settings):

- **Hotkey** — any modifier+key combination
- **Whisper model** — tiny, base, small, medium, large
- **Auto-paste** — toggle automatic Ctrl+V into focused window

---

## Privacy & Security

This is the core principle behind MicDup:

- **All processing happens locally** — audio is transcribed by Whisper running on your machine
- **Audio files are temporary** — recorded WAV is deleted immediately after transcription
- **No network calls** — after the one-time model download, MicDup never phones home (except optional update checks to GitHub)
- **No telemetry** — zero data collection of any kind
- **No account required** — download, run, done
- **Fully open source** — audit the code, build from source, verify everything

---

## Building from Source

Requires: Visual Studio 2022 (or Build Tools) with C++ workload.

```bash
# CPU-only build
cmake -S src/cpp -B build -G "Visual Studio 17 2022" -A x64 -DMICDUP_VULKAN=OFF
cmake --build build --config Release

# Vulkan GPU build (requires Vulkan SDK)
cmake -S src/cpp -B build -G "Visual Studio 17 2022" -A x64 -DMICDUP_VULKAN=ON
cmake --build build --config Release
```

Or use presets:

```bash
cmake --preset release-cpu
cmake --build --preset release-cpu
```

Output: `build/Release/MicDup.exe`

### Architecture

MicDup is written in C++20 with zero external dependencies beyond whisper.cpp (fetched at build time). Everything uses native Win32 APIs:

```
MicDup.exe (~2MB single static binary)
├── whisper.cpp          — speech recognition (statically linked)
├── Win32 waveIn         — microphone audio capture (16kHz mono PCM)
├── Shell_NotifyIcon     — system tray icon and context menu
├── RegisterHotKey       — global hotkey registration
├── WinHTTP              — model download and update checks
├── GDI                  — dynamic tray icon rendering
└── Win32 dialogs        — settings UI
```

Static CRT linkage (`/MT`) — no DLL dependencies at all.

---

## System Requirements

- **OS**: Windows 10 (1809+) or Windows 11
- **RAM**: 2 GB minimum (4 GB+ recommended for larger models)
- **Disk**: ~2 MB for the app + 75 MB–3 GB for the chosen Whisper model
- **Microphone**: Any audio input device
- **GPU** (optional): Vulkan-capable GPU for the Vulkan build

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Hotkey doesn't work | Check for conflicts with other apps; change hotkey in Settings |
| No transcription | Ensure microphone is working in Windows sound settings |
| Transcription is slow | Use a smaller model (tiny/base) or try the Vulkan GPU build |
| App won't start | Check logs in `%APPDATA%\MicDup\logs\` |

---

## Acknowledgments

- **[Mic'd Up](https://github.com/micd-up/micd-up)** — the original macOS voice-to-text app that inspired this project. MicDup brings the same experience to Windows.
- **[whisper.cpp](https://github.com/ggerganov/whisper.cpp)** — high-performance C++ implementation of OpenAI's Whisper model
- **[OpenAI Whisper](https://github.com/openai/whisper)** — the speech recognition model that makes this all possible

---

## License

[MIT License](LICENSE)
