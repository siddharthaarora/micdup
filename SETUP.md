# MicDup Development Setup Guide

## Prerequisites

You need the following installed on your Windows machine:

1. **.NET 8 SDK** - https://dotnet.microsoft.com/download/dotnet/8.0
2. **Python 3.10+** (you have Python 3.11.6 ✓)
3. **Visual Studio 2022** (recommended) or **VS Code**

---

## Setup Steps

### 1. Install Python Dependencies

Open PowerShell or Command Prompt and navigate to the whisper service directory:

```bash
cd src/whisper_service
pip install -r requirements.txt
```

This will install:
- `openai-whisper` - The Whisper speech recognition model
- `torch` - PyTorch (deep learning framework)
- `torchaudio` - Audio processing for PyTorch

**Note**: First time you run Whisper, it will download the model file (~74MB for base model). This is a one-time download.

### 2. Restore .NET Packages

Navigate back to the project root:

```bash
cd ../..
dotnet restore
```

This will download all NuGet packages (NAudio, Serilog, etc.).

### 3. Build the Project

```bash
dotnet build
```

Or if you prefer, open `MicDup.sln` in Visual Studio and build from there (Ctrl+Shift+B).

### 4. Run the Application

```bash
cd src/MicDup.Core
dotnet run
```

Or press F5 in Visual Studio to run with debugging.

---

## Testing the MVP

When you run the application, you should see:

```
=== MicDup MVP Console ===

Available microphones:
  0: Microphone (Your Device Name)

Checking Whisper availability...
✓ Whisper is ready!

Press ENTER to start recording (or type 'exit' to quit)...
```

### Test Flow:

1. **Press ENTER** to start recording
2. **Speak clearly** into your microphone (e.g., "This is a test")
3. **Press ENTER** to stop recording
4. Wait for transcription (~2-5 seconds)
5. See the transcribed text and verify it's in your clipboard
6. Paste (Ctrl+V) somewhere to verify

---

## Troubleshooting

### "Whisper is not available"

**Problem**: Python dependencies not installed or Python not found

**Solutions**:
1. Verify Python is installed: `python --version`
2. Install dependencies: `pip install -r src/whisper_service/requirements.txt`
3. If using a virtual environment, activate it first

### "Audio file too small / No audio detected"

**Problem**: Microphone not working or not selected

**Solutions**:
1. Check Windows Sound Settings → Input → make sure correct mic is selected
2. Test your mic in Windows (speak and watch the volume bar)
3. Grant microphone permissions to the terminal/app
4. Try a different microphone (if available)

### "dotnet: command not found"

**Problem**: .NET SDK not installed or not in PATH

**Solutions**:
1. Download and install .NET 8 SDK from Microsoft
2. Restart your terminal after installation
3. Verify: `dotnet --version` should show 8.x.x

### Build Errors

**Problem**: Missing packages or dependencies

**Solutions**:
1. Run `dotnet restore` in the project root
2. Clean and rebuild: `dotnet clean && dotnet build`
3. Check that all .csproj files reference correct package versions

### Python Process Times Out

**Problem**: Transcription takes too long (>60 seconds)

**Solutions**:
1. Use a smaller model: Change `base` to `tiny` in Program.cs
2. Check CPU usage - might be running on CPU instead of GPU
3. Reduce recording length (speak less)

---

## Project Structure

```
micdup/
├── src/
│   ├── MicDup.Core/              # C# application
│   │   ├── Program.cs            # Entry point & console test
│   │   ├── AudioRecorder.cs      # Records audio with NAudio
│   │   ├── WhisperEngine.cs      # Python subprocess interface
│   │   ├── ClipboardManager.cs   # Clipboard operations
│   │   ├── MicDup.Core.csproj    # Project file
│   │   └── appsettings.json      # Configuration
│   └── whisper_service/          # Python service
│       ├── whisper_service.py    # Transcription script
│       └── requirements.txt      # Python dependencies
├── logs/                         # Application logs (created on first run)
├── MicDup.sln                    # Visual Studio solution
├── DESIGN.md                     # Design document
├── IMPLEMENTATION_PLAN.md        # Implementation plan
└── SETUP.md                      # This file
```

---

## Next Steps

Now that you have the MVP console version working, you can proceed with Phase 2:

- [ ] Add system tray icon
- [ ] Implement global hotkey (CTRL+SHIFT+SPACE)
- [ ] Add auto-paste functionality
- [ ] Remove console window (make it a Windows app)

See [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) for detailed next steps.

---

## Development Tips

### Logging

Logs are written to `logs/app-{date}.log`. Check these if something goes wrong.

### Configuration

Edit `src/MicDup.Core/appsettings.json` to change:
- Whisper model size (tiny/base/small/medium)
- Language (en/es/fr/etc.)
- Audio settings (sample rate, channels)
- Enable/disable auto-paste

### Testing Different Models

In `Program.cs`, change:
```csharp
var whisperEngine = new WhisperEngine(
    pythonPath: "python",
    modelName: "tiny",  // Try: tiny, base, small, medium
    language: "en"
);
```

**Model Performance**:
- `tiny`: ~1s, less accurate
- `base`: ~2-3s, good accuracy ← Default
- `small`: ~5s, better accuracy
- `medium`: ~15s, excellent accuracy

### Debugging

In Visual Studio:
1. Set breakpoints in the code
2. Press F5 to start debugging
3. Step through the code (F10/F11)
4. Inspect variables in the watch window

---

## Common Commands

```bash
# Build
dotnet build

# Run
dotnet run --project src/MicDup.Core

# Clean
dotnet clean

# Restore packages
dotnet restore

# Run tests (when we add them)
dotnet test

# Publish for distribution
dotnet publish -c Release -r win-x64 --self-contained
```

---

## Need Help?

- Check logs in `logs/` directory
- Review [DESIGN.md](DESIGN.md) for architecture details
- See [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) for development roadmap
- Open an issue on GitHub (if applicable)

