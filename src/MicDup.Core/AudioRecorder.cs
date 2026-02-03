using NAudio.Wave;
using Serilog;

namespace MicDup.Core;

/// <summary>
/// Records audio from the default microphone to a WAV file
/// Optimized for Whisper (16kHz, mono, 16-bit)
/// </summary>
public class AudioRecorder : IDisposable
{
    private WaveInEvent? _waveIn;
    private WaveFileWriter? _writer;
    private string? _outputPath;
    private bool _isRecording;

    public bool IsRecording => _isRecording;

    /// <summary>
    /// Starts recording audio to the specified file path
    /// </summary>
    /// <param name="outputPath">Path where the WAV file will be saved</param>
    public void StartRecording(string outputPath)
    {
        if (_isRecording)
        {
            Log.Warning("Recording already in progress");
            return;
        }

        try
        {
            _outputPath = outputPath;

            // Create directory if it doesn't exist
            var directory = Path.GetDirectoryName(outputPath);
            if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
            {
                Directory.CreateDirectory(directory);
            }

            // Configure for Whisper optimal settings: 16kHz, mono, 16-bit
            _waveIn = new WaveInEvent
            {
                WaveFormat = new WaveFormat(16000, 1) // 16kHz, mono
            };

            _writer = new WaveFileWriter(outputPath, _waveIn.WaveFormat);

            // Wire up data available event
            _waveIn.DataAvailable += OnDataAvailable;
            _waveIn.RecordingStopped += OnRecordingStopped;

            _waveIn.StartRecording();
            _isRecording = true;

            Log.Information("Recording started: {OutputPath}", outputPath);
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Failed to start recording");
            Cleanup();
            throw;
        }
    }

    /// <summary>
    /// Stops recording and returns the path to the recorded file
    /// </summary>
    /// <returns>Path to the recorded WAV file</returns>
    public string StopRecording()
    {
        if (!_isRecording)
        {
            Log.Warning("No recording in progress");
            return string.Empty;
        }

        try
        {
            _waveIn?.StopRecording();
            _isRecording = false;

            // Give it a moment to finish writing
            System.Threading.Thread.Sleep(100);

            Log.Information("Recording stopped: {OutputPath}", _outputPath);
            return _outputPath ?? string.Empty;
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Error stopping recording");
            throw;
        }
    }

    private void OnDataAvailable(object? sender, WaveInEventArgs e)
    {
        if (_writer != null)
        {
            _writer.Write(e.Buffer, 0, e.BytesRecorded);
        }
    }

    private void OnRecordingStopped(object? sender, StoppedEventArgs e)
    {
        if (e.Exception != null)
        {
            Log.Error(e.Exception, "Recording stopped due to error");
        }

        Cleanup();
    }

    private void Cleanup()
    {
        _writer?.Dispose();
        _writer = null;

        if (_waveIn != null)
        {
            _waveIn.DataAvailable -= OnDataAvailable;
            _waveIn.RecordingStopped -= OnRecordingStopped;
            _waveIn.Dispose();
            _waveIn = null;
        }
    }

    public void Dispose()
    {
        if (_isRecording)
        {
            StopRecording();
        }

        Cleanup();
    }

    /// <summary>
    /// Gets a list of available recording devices
    /// </summary>
    public static List<string> GetAvailableDevices()
    {
        var devices = new List<string>();
        for (int i = 0; i < WaveInEvent.DeviceCount; i++)
        {
            var caps = WaveInEvent.GetCapabilities(i);
            devices.Add($"{i}: {caps.ProductName}");
        }
        return devices;
    }
}
