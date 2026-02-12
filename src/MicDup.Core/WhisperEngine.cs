using Serilog;
using Whisper.net;
using Whisper.net.Ggml;

namespace MicDup.Core;

/// <summary>
/// In-process Whisper transcription engine using Whisper.net (whisper.cpp wrapper).
/// Auto-downloads the GGML model on first use.
/// </summary>
public class WhisperEngine : IDisposable
{
    private static readonly string ModelsDir = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "MicDup", "Models");

    private readonly string _modelName;
    private readonly string? _language;
    private WhisperFactory? _factory;
    private bool _initialized;

    public WhisperEngine(string modelName = "base", string? language = null)
    {
        _modelName = modelName;
        _language = language;
        Log.Information("WhisperEngine created with model: {Model}, language: {Language}",
            _modelName, _language ?? "auto-detect");
    }

    /// <summary>
    /// Ensures the model is downloaded and the factory is ready
    /// </summary>
    public async Task<bool> CheckAvailabilityAsync()
    {
        try
        {
            var modelPath = await EnsureModelDownloadedAsync();
            _factory = WhisperFactory.FromPath(modelPath);
            _initialized = true;
            Log.Information("Whisper model loaded successfully from {Path}", modelPath);
            return true;
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Failed to initialize Whisper engine");
            return false;
        }
    }

    /// <summary>
    /// Transcribes an audio file (16kHz mono 16-bit WAV)
    /// </summary>
    public async Task<string> TranscribeAsync(string audioFilePath)
    {
        if (!_initialized || _factory == null)
            throw new InvalidOperationException("WhisperEngine not initialized. Call CheckAvailabilityAsync first.");

        if (!File.Exists(audioFilePath))
            throw new FileNotFoundException($"Audio file not found: {audioFilePath}");

        try
        {
            Log.Information("Starting transcription of: {AudioFile}", audioFilePath);

            var builder = _factory.CreateBuilder()
                .WithTemperature(0f);

            if (!string.IsNullOrEmpty(_language))
                builder.WithLanguage(_language);
            else
                builder.WithLanguageDetection();

            using var processor = builder.Build();
            using var fileStream = File.OpenRead(audioFilePath);

            var segments = new List<string>();
            await foreach (var segment in processor.ProcessAsync(fileStream))
            {
                segments.Add(segment.Text);
            }

            var transcription = string.Join(" ", segments).Trim();

            if (string.IsNullOrWhiteSpace(transcription))
            {
                Log.Warning("Transcription returned empty result");
                return string.Empty;
            }

            Log.Information("Transcription completed: {Length} characters", transcription.Length);
            return transcription;
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Error during transcription");
            throw;
        }
    }

    private async Task<string> EnsureModelDownloadedAsync()
    {
        Directory.CreateDirectory(ModelsDir);

        var ggmlType = ParseGgmlType(_modelName);
        var modelFileName = $"ggml-{_modelName}.bin";
        var modelPath = Path.Combine(ModelsDir, modelFileName);

        if (File.Exists(modelPath))
        {
            Log.Information("Model already downloaded: {Path}", modelPath);
            return modelPath;
        }

        Log.Information("Downloading Whisper model '{Model}' to {Path}...", _modelName, modelPath);

        using var modelStream = await WhisperGgmlDownloader.Default.GetGgmlModelAsync(ggmlType);
        using var fileWriter = File.Create(modelPath);
        await modelStream.CopyToAsync(fileWriter);

        Log.Information("Model download complete: {Path}", modelPath);
        return modelPath;
    }

    private static GgmlType ParseGgmlType(string modelName) => modelName.ToLowerInvariant() switch
    {
        "tiny" => GgmlType.Tiny,
        "base" => GgmlType.Base,
        "small" => GgmlType.Small,
        "medium" => GgmlType.Medium,
        "large" => GgmlType.LargeV3Turbo,
        _ => GgmlType.Base
    };

    public void Dispose()
    {
        _factory?.Dispose();
        _factory = null;
    }
}
