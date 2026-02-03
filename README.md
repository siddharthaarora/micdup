# MicDup

**Quick speech-to-text transcription for Windows using OpenAI Whisper**

MicDup is a lightweight, always-available Windows application that lets you transcribe speech to text with a simple hotkey. Press the hotkey, speak, press again—your words are instantly in your clipboard (and optionally pasted where you're typing).

---

## Features

- **Global Hotkey**: Press CTRL+SHIFT+SPACE (configurable) to start/stop recording
- **System Tray**: Unobtrusive background operation with visual status
- **Local Transcription**: Uses OpenAI's Whisper model—no internet required, privacy-first
- **Auto-Paste**: Automatically pastes transcribed text into focused text fields
- **Clipboard Integration**: Text always available in clipboard for manual pasting
- **Multiple Model Sizes**: Choose between speed (tiny) and accuracy (medium/large)

---

## Quick Start

### For Users
1. Download the latest installer from [Releases]
2. Run `MicDup-Setup.exe`
3. Press CTRL+SHIFT+SPACE to start recording
4. Speak clearly
5. Press CTRL+SHIFT+SPACE again
6. Your text is in the clipboard (and auto-pasted if enabled)

### For Developers
See [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) for detailed development instructions.

---

## System Requirements

- **OS**: Windows 10 (1809+) or Windows 11
- **RAM**: 2GB minimum (4GB recommended for larger models)
- **Disk**: 500MB for application + 150MB-3GB for Whisper models
- **Microphone**: Any audio input device

---

## Documentation

- [DESIGN.md](DESIGN.md) - Complete design document covering architecture, components, and technical specifications
- [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) - Detailed implementation plan with tasks, timelines, and development guidelines
- [USER_GUIDE.md](docs/USER_GUIDE.md) - User documentation (coming soon)

---

## Architecture

### Technology Stack
- **C# (.NET 8)**: Core application, system integration, UI
- **Python 3.10+**: Whisper model integration
- **NAudio**: Audio recording
- **OpenAI Whisper**: Speech recognition model

### Key Components
```
┌─────────────────────────────────────────┐
│         System Tray Application         │
├─────────────────────────────────────────┤
│  HotkeyManager │ AudioRecorder │ Tray   │
├─────────────────────────────────────────┤
│         WhisperEngine (Python)          │
├─────────────────────────────────────────┤
│  Clipboard Manager │ Auto-Paster        │
└─────────────────────────────────────────┘
```

---

## Configuration

Settings are stored in `%APPDATA%\MicDup\appsettings.json`:

```json
{
  "hotkey": {
    "modifiers": "Control+Shift",
    "key": "Space"
  },
  "whisper": {
    "model": "base",
    "language": "en"
  },
  "behavior": {
    "autoPaste": true,
    "showNotifications": true
  }
}
```

Edit via Settings UI (right-click tray icon → Settings)

---

## Hotkey Customization

Default: **CTRL+SHIFT+SPACE**

### Why not WIN+SPACE?
Windows uses WIN+SPACE for input method switching. We use CTRL+SHIFT+SPACE by default to avoid conflicts.

### Want to use WIN+SPACE anyway?
See [docs/HOTKEY_OVERRIDE.md](docs/HOTKEY_OVERRIDE.md) for instructions on disabling Windows' hotkey (advanced users only).

### Changing the Hotkey
Right-click tray icon → Settings → Hotkey tab

---

## Whisper Models

Choose the right balance of speed vs accuracy:

| Model | Size | Speed | Accuracy | Best For |
|-------|------|-------|----------|----------|
| `tiny` | 39MB | ~1s | Good | Quick notes, commands |
| `base` | 74MB | ~2s | Better | **Recommended** |
| `small` | 244MB | ~5s | Great | Dictation, articles |
| `medium` | 769MB | ~15s | Excellent | Professional transcription |
| `large` | 1550MB | ~30s | Best | Highest accuracy needs |

Change model: Right-click tray icon → Settings → Whisper Model

---

## Privacy & Security

- **Local Processing**: Audio never leaves your machine (when using local models)
- **No Telemetry**: We don't collect any data about your usage
- **No Account Required**: Install and use immediately
- **Open Source**: Audit the code yourself

---

## Troubleshooting

### Hotkey doesn't work
- Check for conflicts with other applications
- Try changing the hotkey in Settings
- Run as Administrator (some apps require elevated permissions)

### No transcription / blank clipboard
- Ensure you speak clearly and close to microphone
- Check microphone is selected in Windows sound settings
- Verify Python and Whisper model installed correctly

### Application won't start
- Check logs in `%APPDATA%\MicDup\logs\app.log`
- Ensure .NET 8 Runtime is installed
- Try reinstalling the application

### Transcription is slow
- Try a smaller model (Settings → Whisper Model → `tiny`)
- Check CPU usage during transcription
- Consider using OpenAI API mode (requires API key)

---

## Development Status

**Current Phase**: Design & Planning ✅
**Next Phase**: Phase 1 - Core Functionality (MVP)

See [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) for roadmap and progress.

---

## Contributing

We welcome contributions! Areas where we need help:

- Testing on different Windows versions
- Icon design and UI improvements
- Documentation and tutorials
- Bug reports and feature requests

Please open an issue before starting major work.

---

## Roadmap

### MVP (Phase 1-2)
- [x] Design and architecture
- [ ] Audio recording
- [ ] Whisper integration
- [ ] Clipboard copy
- [ ] System tray icon
- [ ] Global hotkey
- [ ] Auto-paste

### Post-MVP (Phase 3-5)
- [ ] Settings UI
- [ ] Multiple languages
- [ ] Custom vocabulary
- [ ] Transcription history
- [ ] Auto-update mechanism
- [ ] Punctuation commands ("period", "comma")

### Future
- [ ] OpenAI API integration option
- [ ] Real-time transcription (streaming)
- [ ] Text formatting options
- [ ] Plugin system
- [ ] Mobile companion app

---

## License

[MIT License](LICENSE) - See LICENSE file for details

---

## Acknowledgments

- [OpenAI Whisper](https://github.com/openai/whisper) - Speech recognition model
- [NAudio](https://github.com/naudio/NAudio) - Audio library for .NET
- [Hardcodet.NotifyIcon.Wpf](https://github.com/hardcodet/wpf-notifyicon) - System tray icon

---

## Support

- **Documentation**: See [docs/](docs/) folder
- **Issues**: [GitHub Issues](https://github.com/yourusername/micdup/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/micdup/discussions)

---

## Changelog

### v0.1.0 (Planned) - MVP Release
- Initial release with core functionality
- System tray application
- Global hotkey recording
- Whisper transcription
- Clipboard integration
- Auto-paste feature

---

**Made with ❤️ for productivity enthusiasts**