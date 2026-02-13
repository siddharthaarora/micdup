using System.Windows.Forms;
using Serilog;

namespace MicDup.Core;

/// <summary>
/// Custom application context for running the tray application
/// </summary>
public class MicDupApplicationContext : ApplicationContext
{
    private AppController? _appController;
    private readonly WhisperEngine _whisperEngine;
    private readonly SettingsManager _settingsManager;
    private readonly bool _justUpdated;

    public MicDupApplicationContext(WhisperEngine whisperEngine, SettingsManager settingsManager, bool justUpdated = false)
    {
        _whisperEngine = whisperEngine;
        _settingsManager = settingsManager;
        _justUpdated = justUpdated;
        InitializeAsync().ConfigureAwait(false);
    }

    private async Task InitializeAsync()
    {
        try
        {
            Log.Information("Initializing MicDup application context...");

            _appController = new AppController(_whisperEngine, _settingsManager);

            var initialized = await _appController.InitializeAsync();

            if (!initialized)
            {
                Log.Error("Failed to initialize application controller");
                MessageBox.Show(
                    "Failed to initialize MicDup. Please check that Python and Whisper are installed correctly.\n\n" +
                    "See logs in: " + Path.Combine(
                        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                        "MicDup", "logs"),
                    "Micd Up Error",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);

                Application.Exit();
                return;
            }

            if (_justUpdated)
            {
                _appController.ShowUpdateSuccessNotification();
            }

            Log.Information("MicDup application context initialized successfully");
        }
        catch (Exception ex)
        {
            Log.Fatal(ex, "Failed to initialize application context");
            MessageBox.Show(
                $"Fatal error during initialization: {ex.Message}\n\nSee logs for details.",
                "Micd Up Error",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);

            Application.Exit();
        }
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _appController?.Dispose();
            _appController = null;
        }

        base.Dispose(disposing);
    }

    protected override void ExitThreadCore()
    {
        Log.Information("Application exiting...");
        _appController?.Dispose();
        base.ExitThreadCore();
    }
}
