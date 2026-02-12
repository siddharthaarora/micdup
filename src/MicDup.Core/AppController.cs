using Serilog;
using System.Windows.Forms;

namespace MicDup.Core;

/// <summary>
/// Main application controller that orchestrates all components
/// </summary>
public class AppController : IDisposable
{
    private readonly TrayManager _trayManager;
    private readonly HotkeyManager _hotkeyManager;
    private readonly WhisperEngine _whisperEngine;
    private readonly SettingsManager _settingsManager;
    private AudioRecorder? _audioRecorder;
    private string? _currentRecordingPath;
    private AppState _state = AppState.Idle;
    private bool _autoPasteEnabled;

    public AppController(WhisperEngine whisperEngine, SettingsManager settingsManager)
    {
        _whisperEngine = whisperEngine;
        _settingsManager = settingsManager;
        _autoPasteEnabled = settingsManager.Settings.Behavior.AutoPaste;
        _trayManager = new TrayManager();
        _hotkeyManager = new HotkeyManager();
    }

    /// <summary>
    /// Initializes and starts the application
    /// </summary>
    public async Task<bool> InitializeAsync()
    {
        try
        {
            Log.Information("Initializing AppController...");

            // Initialize system tray
            _trayManager.Initialize();
            _trayManager.StartStopClicked += OnStartStopClicked;
            _trayManager.SettingsClicked += OnSettingsClicked;
            _trayManager.ExitClicked += OnExitClicked;
            _trayManager.SetState(TrayState.Idle);

            // Check Whisper availability
            var whisperAvailable = await _whisperEngine.CheckAvailabilityAsync();
            if (!whisperAvailable)
            {
                Log.Error("Whisper is not available");
                return false;
            }

            // Register global hotkey from settings
            var hotkeySettings = _settingsManager.Settings.Hotkey;
            var modifiers = SettingsManager.ParseModifiers(hotkeySettings.Modifiers);
            var key = SettingsManager.ParseKey(hotkeySettings.Key);
            var hotkeyRegistered = _hotkeyManager.RegisterHotkey(modifiers, key);

            if (!hotkeyRegistered)
            {
                Log.Warning("Failed to register hotkey CTRL+SHIFT+SPACE");
            }

            _hotkeyManager.HotkeyPressed += OnHotkeyPressed;

            Log.Information("AppController initialized successfully");

            return true;
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Failed to initialize AppController");
            return false;
        }
    }

    private void OnHotkeyPressed(object? sender, EventArgs e)
    {
        Log.Debug("Hotkey pressed, current state: {State}", _state);
        ToggleRecording();
    }

    private void OnStartStopClicked(object? sender, EventArgs e)
    {
        Log.Debug("Start/Stop clicked, current state: {State}", _state);
        ToggleRecording();
    }

    private void OnSettingsClicked(object? sender, EventArgs e)
    {
        Log.Information("Settings requested");
        using var form = new SettingsForm(_settingsManager);
        if (form.ShowDialog() == DialogResult.OK)
        {
            // Re-register hotkey with new settings
            var hotkeySettings = _settingsManager.Settings.Hotkey;
            var modifiers = SettingsManager.ParseModifiers(hotkeySettings.Modifiers);
            var key = SettingsManager.ParseKey(hotkeySettings.Key);
            _hotkeyManager.ReregisterHotkey(modifiers, key);

            // Update behavior
            _autoPasteEnabled = _settingsManager.Settings.Behavior.AutoPaste;

            Log.Information("Settings applied");
        }
    }

    private void OnExitClicked(object? sender, EventArgs e)
    {
        Log.Information("Exit requested");
        Application.Exit();
    }

    private void ToggleRecording()
    {
        switch (_state)
        {
            case AppState.Idle:
                StartRecording();
                break;

            case AppState.Recording:
                _ = StopRecordingAndTranscribeAsync();
                break;

            case AppState.Processing:
                // Ignore input while processing
                Log.Debug("Ignoring input - currently processing");
                break;
        }
    }

    private void StartRecording()
    {
        try
        {
            if (_state != AppState.Idle)
            {
                Log.Warning("Cannot start recording - not in idle state");
                return;
            }

            _state = AppState.Recording;
            _trayManager.SetState(TrayState.Recording);

            _audioRecorder = new AudioRecorder();
            _currentRecordingPath = Path.Combine(
                Path.GetTempPath(),
                $"micdup_{Guid.NewGuid()}.wav");

            _audioRecorder.StartRecording(_currentRecordingPath);

            Log.Information("Recording started");
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Error starting recording");
            _state = AppState.Idle;
            _trayManager.SetState(TrayState.Error);
        }
    }

    private async Task StopRecordingAndTranscribeAsync()
    {
        try
        {
            if (_state != AppState.Recording)
            {
                Log.Warning("Cannot stop recording - not currently recording");
                return;
            }

            _state = AppState.Processing;
            _trayManager.SetState(TrayState.Processing);

            // Stop recording
            var audioFile = _audioRecorder?.StopRecording() ?? string.Empty;
            _audioRecorder?.Dispose();
            _audioRecorder = null;

            Log.Information("Recording stopped: {AudioFile}", audioFile);

            // Check file size
            var fileInfo = new FileInfo(audioFile);
            if (fileInfo.Length < 1000)
            {
                Log.Warning("Audio file too small ({Size} bytes) - no speech detected", fileInfo.Length);
                _state = AppState.Idle;
                _trayManager.SetState(TrayState.Error);

                CleanupAudioFile(audioFile);
                return;
            }

            // Transcribe
            Log.Information("Starting transcription...");
            var transcription = await _whisperEngine.TranscribeAsync(audioFile);

            // Clean up audio file
            CleanupAudioFile(audioFile);

            if (string.IsNullOrWhiteSpace(transcription))
            {
                Log.Warning("Transcription returned empty result");
                _state = AppState.Idle;
                _trayManager.SetState(TrayState.Error);
                return;
            }

            Log.Information("Transcription successful: {Length} characters", transcription.Length);

            // Copy to clipboard
            await ClipboardManager.CopyToClipboardAsync(transcription);

            // Auto-paste if enabled and text field is focused
            if (_autoPasteEnabled && AutoPaster.IsFocusedWindowTextInput())
            {
                await AutoPaster.PasteFromClipboardAsync();
                Log.Information("Auto-pasted transcription");
            }

            _state = AppState.Idle;
            _trayManager.SetState(TrayState.Success);
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Error during transcription");
            _state = AppState.Idle;
            _trayManager.SetState(TrayState.Error);

            if (!string.IsNullOrEmpty(_currentRecordingPath))
            {
                CleanupAudioFile(_currentRecordingPath);
            }
        }
    }

    private void CleanupAudioFile(string filePath)
    {
        try
        {
            if (File.Exists(filePath))
            {
                File.Delete(filePath);
                Log.Debug("Cleaned up audio file: {FilePath}", filePath);
            }
        }
        catch (Exception ex)
        {
            Log.Warning(ex, "Failed to delete audio file: {FilePath}", filePath);
        }
    }

    public void Dispose()
    {
        _audioRecorder?.Dispose();
        _hotkeyManager?.Dispose();
        _trayManager?.Dispose();
        _whisperEngine?.Dispose();
        Log.Information("AppController disposed");
    }
}

/// <summary>
/// Application state machine
/// </summary>
internal enum AppState
{
    Idle,
    Recording,
    Processing
}
