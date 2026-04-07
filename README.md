# MicDup

**Think it. Say it. Ship it. Voice-to-text for Windows and macOS that keeps your data yours.**

MicDup is a lightweight application that transcribes your speech to text using [OpenAI's Whisper](https://github.com/openai/whisper) model running entirely on your machine. Press a hotkey, speak, press again — your words are in your clipboard and optionally pasted where you're typing. No audio ever leaves your computer.

> Inspired by [Mic'd Up](https://github.com/micd-up/micd-up), a fantastic macOS menu bar app by [@micd-up](https://github.com/micd-up).

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
- **Single app** — One ~2MB binary. No installer, no runtime dependencies.
- **Open source** — Read every line of code. Build it yourself if you want.

Your voice stays on your machine. Period.

---

## Quick Start

### Windows

1. Download `MicDup-vX.X.X-win-x64-cpu.zip` from [Releases](https://github.com/siddharthaarora/micdup/releases)
2. Extract `MicDup.exe` anywhere
3. Run it — Windows may show a **"Windows protected your PC"** SmartScreen warning since the app is not code-signed:
   - Click **"More info"**
   - Click **"Run anyway"**
4. A microphone icon appears in your system tray
5. Press **Ctrl+Shift+Space** to start recording
6. Speak
7. Press **Ctrl+Shift+Space** again
8. Your text is in the clipboard (and auto-pasted if a text field is focused)

### macOS

1. Download `MicDup-vX.X.X-mac-arm64.zip` (Apple Silicon) or `MicDup-vX.X.X-mac-x64.zip` (Intel) from [Releases](https://github.com/siddharthaarora/micdup/releases)
2. Extract `MicDup.app` and move it to Applications
3. **Remove the quarantine flag** (required because the app is not notarized):
   ```bash
   xattr -cr /Applications/MicDup.app
   ```
4. Run it — macOS will ask for **microphone permission**, click Allow
5. A microphone icon appears in your menu bar
6. Press **Cmd+Shift+Space** to start recording
7. Speak
8. Press **Cmd+Shift+Space** again
9. Your text is in the clipboard (and auto-pasted if a text field is focused)

First run downloads the Whisper model (~150MB for "base"). After that, no internet is needed.

---

## Features

- **Global Hotkey** — Ctrl+Shift+Space on Windows, Cmd+Shift+Space on macOS (configurable)
- **System Tray / Menu Bar** — Unobtrusive background operation with visual status indicators
- **Local Transcription** — OpenAI Whisper via [whisper.cpp](https://github.com/ggerganov/whisper.cpp), running natively
- **Auto-Paste** — Automatically pastes transcribed text into the focused window
- **Clipboard Integration** — Text always copied to clipboard
- **GPU Acceleration** — Vulkan on Windows, Metal on macOS
- **Multiple Model Sizes** — Choose between speed (tiny) and accuracy (large)
- **Auto-Update** — Checks GitHub releases and updates in-place
- **Zero Dependencies** — Single static binary, no runtime needed

---

## Downloads

| Platform | Build | GPU Support |
|----------|-------|-------------|
| **[Windows CPU](https://github.com/siddharthaarora/micdup/releases/latest)** | Works everywhere | CPU only |
| **[Windows Vulkan](https://github.com/siddharthaarora/micdup/releases/latest)** | Faster transcription | AMD, NVIDIA, Intel GPUs |
| **[macOS Apple Silicon](https://github.com/siddharthaarora/micdup/releases/latest)** | M1/M2/M3/M4 Macs | Metal GPU |
| **[macOS Intel](https://github.com/siddharthaarora/micdup/releases/latest)** | Older Macs | Metal GPU |

---

## Whisper Models

Models are auto-downloaded on first use.

- **Windows**: stored in `%LOCALAPPDATA%\MicDup\Models\`
- **macOS**: stored in `~/Library/Application Support/MicDup/Models/`

| Model | Download | Speed | Accuracy | Best For |
|-------|----------|-------|----------|----------|
| `tiny` | ~75 MB | ~1s | Good | Quick notes, commands |
| `base` | ~150 MB | ~2s | Better | **Recommended for daily use** |
| `small` | ~500 MB | ~5s | Great | Dictation, longer text |
| `medium` | ~1.5 GB | ~15s | Excellent | Professional transcription |
| `large` | ~3 GB | ~30s | Best | Maximum accuracy |

Change model: right-click tray/menu bar icon > Settings > Whisper Model.

---

## Configuration

Settings are editable via the Settings dialog (right-click tray/menu bar icon > Settings):

- **Hotkey** — any modifier+key combination
- **Whisper model** — tiny, base, small, medium, large
- **Auto-paste** — toggle automatic paste into focused window

Settings file location:
- **Windows**: `%APPDATA%\MicDup\settings.json`
- **macOS**: `~/Library/Application Support/MicDup/settings.json`

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

### Windows

Requires: Visual Studio 2022 (or Build Tools) with C++ workload.

```bash
# CPU-only build
cmake -S src/cpp -B build -G "Visual Studio 17 2022" -A x64 -DMICDUP_VULKAN=OFF
cmake --build build --config Release

# Vulkan GPU build (requires Vulkan SDK)
cmake -S src/cpp -B build -G "Visual Studio 17 2022" -A x64 -DMICDUP_VULKAN=ON
cmake --build build --config Release
```

Output: `build/Release/MicDup.exe`

### macOS

Requires: Xcode Command Line Tools.

```bash
# Build with Metal GPU support
cmake -S src/cpp -B build -DCMAKE_BUILD_TYPE=Release -DMICDUP_METAL=ON
cmake --build build --config Release --parallel
```

Output: `build/MicDup.app`

### Presets

```bash
# Windows
cmake --preset release-cpu && cmake --build --preset release-cpu
cmake --preset release-vulkan && cmake --build --preset release-vulkan

# macOS
cmake --preset release-mac && cmake --build --preset release-mac
```

### Architecture

MicDup is written in C++20 with zero external dependencies beyond whisper.cpp (fetched at build time). Platform-specific code uses native APIs:

**Windows:**
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

**macOS:**
```
MicDup.app (~2MB app bundle)
├── whisper.cpp          — speech recognition (statically linked, Metal GPU)
├── AVAudioEngine        — microphone audio capture (16kHz mono PCM)
├── NSStatusItem         — menu bar icon and context menu
├── Carbon hotkeys       — global hotkey registration
├── NSURLSession         — model download and update checks
├── NSBezierPath         — dynamic menu bar icon rendering
└── AppKit               — settings UI
```

---

## System Requirements

### Windows
- **OS**: Windows 10 (1809+) or Windows 11
- **RAM**: 2 GB minimum (4 GB+ recommended for larger models)
- **GPU** (optional): Vulkan-capable GPU for the Vulkan build

### macOS
- **OS**: macOS 12 (Monterey) or later
- **Architecture**: Apple Silicon (M1+) or Intel x86_64
- **RAM**: 2 GB minimum (4 GB+ recommended for larger models)
- **Permissions**: Microphone access (prompted on first run)

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Hotkey doesn't work | Check for conflicts with other apps; change hotkey in Settings |
| No transcription | Ensure microphone is working in system settings |
| Transcription is slow | Use a smaller model (tiny/base) or try GPU build |
| App won't start | Check logs in settings directory |
| macOS: "can't be opened" | Right-click > Open, or allow in System Settings > Privacy |
| macOS: no auto-paste | Grant Accessibility permission in System Settings > Privacy > Accessibility |

---

## Acknowledgments

- **[Mic'd Up](https://github.com/micd-up/micd-up)** — the original macOS voice-to-text app that inspired this project
- **[whisper.cpp](https://github.com/ggerganov/whisper.cpp)** — high-performance C++ implementation of OpenAI's Whisper model
- **[OpenAI Whisper](https://github.com/openai/whisper)** — the speech recognition model that makes this all possible

---

## License

[MIT License](LICENSE)
