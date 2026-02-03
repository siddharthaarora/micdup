using System.Diagnostics;
using System.Text;
using Serilog;

namespace MicDup.Core;

/// <summary>
/// Interfaces with Python Whisper service to transcribe audio files
/// </summary>
public class WhisperEngine
{
    private readonly string _pythonPath;
    private readonly string _scriptPath;
    private readonly string _modelName;
    private readonly string? _language;
    private readonly int _timeoutSeconds;

    public WhisperEngine(
        string pythonPath = "python",
        string? scriptPath = null,
        string modelName = "base",
        string? language = null,
        int timeoutSeconds = 60)
    {
        _pythonPath = pythonPath;
        _scriptPath = scriptPath ?? Path.Combine(
            AppDomain.CurrentDomain.BaseDirectory,
            "..", "..", "whisper_service", "whisper_service.py");
        _modelName = modelName;
        _language = language;
        _timeoutSeconds = timeoutSeconds;

        Log.Information("WhisperEngine initialized with model: {Model}, language: {Language}",
            _modelName, _language ?? "auto-detect");
    }

    /// <summary>
    /// Transcribes an audio file using Whisper
    /// </summary>
    /// <param name="audioFilePath">Path to the audio file (WAV, MP3, etc.)</param>
    /// <returns>Transcribed text</returns>
    public async Task<string> TranscribeAsync(string audioFilePath)
    {
        if (!File.Exists(audioFilePath))
        {
            throw new FileNotFoundException($"Audio file not found: {audioFilePath}");
        }

        try
        {
            Log.Information("Starting transcription of: {AudioFile}", audioFilePath);

            var startInfo = new ProcessStartInfo
            {
                FileName = _pythonPath,
                Arguments = BuildArguments(audioFilePath),
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true,
                StandardOutputEncoding = Encoding.UTF8,
                StandardErrorEncoding = Encoding.UTF8
            };

            using var process = new Process { StartInfo = startInfo };

            var outputBuilder = new StringBuilder();
            var errorBuilder = new StringBuilder();

            process.OutputDataReceived += (sender, e) =>
            {
                if (!string.IsNullOrEmpty(e.Data))
                {
                    outputBuilder.AppendLine(e.Data);
                }
            };

            process.ErrorDataReceived += (sender, e) =>
            {
                if (!string.IsNullOrEmpty(e.Data))
                {
                    errorBuilder.AppendLine(e.Data);
                    Log.Debug("Whisper stderr: {Message}", e.Data);
                }
            };

            process.Start();
            process.BeginOutputReadLine();
            process.BeginErrorReadLine();

            var completed = await Task.Run(() =>
                process.WaitForExit(_timeoutSeconds * 1000));

            if (!completed)
            {
                process.Kill();
                throw new TimeoutException(
                    $"Transcription timed out after {_timeoutSeconds} seconds");
            }

            if (process.ExitCode != 0)
            {
                var error = errorBuilder.ToString();
                Log.Error("Whisper process failed with exit code {ExitCode}: {Error}",
                    process.ExitCode, error);
                throw new Exception(
                    $"Whisper transcription failed (exit code {process.ExitCode}): {error}");
            }

            var transcription = outputBuilder.ToString().Trim();

            if (string.IsNullOrWhiteSpace(transcription))
            {
                Log.Warning("Transcription returned empty result");
                return string.Empty;
            }

            Log.Information("Transcription completed successfully: {Length} characters",
                transcription.Length);

            return transcription;
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Error during transcription");
            throw;
        }
    }

    private string BuildArguments(string audioFilePath)
    {
        var args = new StringBuilder();

        // Script path (quote if it contains spaces)
        args.Append($"\"{_scriptPath}\" ");

        // Audio file path (quote if it contains spaces)
        args.Append($"\"{audioFilePath}\" ");

        // Model
        args.Append($"--model {_modelName} ");

        // Language (optional)
        if (!string.IsNullOrEmpty(_language))
        {
            args.Append($"--language {_language}");
        }

        return args.ToString().Trim();
    }

    /// <summary>
    /// Checks if Python and Whisper are available
    /// </summary>
    public async Task<bool> CheckAvailabilityAsync()
    {
        try
        {
            // Check Python
            var pythonCheck = new ProcessStartInfo
            {
                FileName = _pythonPath,
                Arguments = "--version",
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            using var pythonProcess = Process.Start(pythonCheck);
            if (pythonProcess == null)
            {
                Log.Error("Failed to start Python process");
                return false;
            }

            await pythonProcess.WaitForExitAsync();

            if (pythonProcess.ExitCode != 0)
            {
                Log.Error("Python check failed with exit code {ExitCode}",
                    pythonProcess.ExitCode);
                return false;
            }

            var pythonVersion = await pythonProcess.StandardOutput.ReadToEndAsync();
            Log.Information("Python found: {Version}", pythonVersion.Trim());

            // Check if script exists
            if (!File.Exists(_scriptPath))
            {
                Log.Error("Whisper service script not found: {ScriptPath}", _scriptPath);
                return false;
            }

            Log.Information("Whisper service availability check passed");
            return true;
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Error checking Whisper availability");
            return false;
        }
    }
}
