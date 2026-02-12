using System.Windows.Forms;
using Serilog;

namespace MicDup.Core;

class Program
{
    [STAThread]
    static void Main(string[] args)
    {
        // Set up logging
        var appDataPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "MicDup");

        Directory.CreateDirectory(appDataPath);
        Directory.CreateDirectory(Path.Combine(appDataPath, "logs"));

        Log.Logger = new LoggerConfiguration()
            .MinimumLevel.Information()
            .WriteTo.File(
                Path.Combine(appDataPath, "logs", "app-.log"),
                rollingInterval: RollingInterval.Day)
            .CreateLogger();

        try
        {
            Log.Information("MicDup starting (Windows Application)...");
            Log.Information("App data path: {AppDataPath}", appDataPath);

            // Enable visual styles for Windows Forms
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            // Load settings
            var settingsManager = new SettingsManager();
            settingsManager.Load();

            // Initialize Whisper engine from settings
            var settings = settingsManager.Settings;
            var whisperEngine = new WhisperEngine(
                modelName: settings.Whisper.Model,
                language: settings.Whisper.Language
            );

            // Create application context and run message loop
            using var appContext = new MicDupApplicationContext(whisperEngine, settingsManager);
            Application.Run(appContext);

            Log.Information("Application shutting down...");
        }
        catch (Exception ex)
        {
            Log.Fatal(ex, "Application terminated unexpectedly");
            MessageBox.Show(
                $"Fatal error: {ex.Message}\n\nSee logs for details.",
                "Micd Up Error",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
        }
        finally
        {
            Log.CloseAndFlush();
        }
    }
}
