using System.Runtime.CompilerServices;
using System.Runtime.Loader;
using System.Windows.Forms;
using Serilog;

namespace MicDup.Core;

class Program
{
    [STAThread]
    static void Main(string[] args)
    {
        // Register assembly resolver BEFORE any dependency assemblies are loaded.
        // Managed dependency DLLs live in the lib/ subfolder.
        var libPath = Path.Combine(AppContext.BaseDirectory, "lib");
        AssemblyLoadContext.Default.Resolving += (context, assemblyName) =>
        {
            var dllPath = Path.Combine(libPath, $"{assemblyName.Name}.dll");
            return File.Exists(dllPath) ? context.LoadFromAssemblyPath(dllPath) : null;
        };

        RunApp(args);
    }

    [MethodImpl(MethodImplOptions.NoInlining)]
    static void RunApp(string[] args)
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
            var version = UpdateChecker.GetCurrentVersion();
            Log.Information("MicDup v{Version} starting...", version);
            Log.Information("App data path: {AppDataPath}", appDataPath);

            // Show update success notification if we just updated
            var justUpdated = args.Contains("--updated");

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
            using var appContext = new MicDupApplicationContext(whisperEngine, settingsManager, justUpdated);
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
