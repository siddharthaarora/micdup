using Newtonsoft.Json;
using Serilog;
using System.Windows.Forms;

namespace MicDup.Core;

public class SettingsManager
{
    private static readonly string SettingsDir = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "MicDup");
    private static readonly string SettingsPath = Path.Combine(SettingsDir, "settings.json");

    public AppSettings Settings { get; private set; } = new();

    public void Load()
    {
        try
        {
            if (!File.Exists(SettingsPath))
            {
                Log.Information("No settings file found at {Path}, using defaults", SettingsPath);
                return;
            }

            var json = File.ReadAllText(SettingsPath);
            Settings = JsonConvert.DeserializeObject<AppSettings>(json) ?? new AppSettings();
            Log.Information("Settings loaded from {Path}", SettingsPath);
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Failed to load settings, using defaults");
            Settings = new AppSettings();
        }
    }

    public void Save()
    {
        try
        {
            Directory.CreateDirectory(SettingsDir);
            var json = JsonConvert.SerializeObject(Settings, Formatting.Indented);
            File.WriteAllText(SettingsPath, json);
            Log.Information("Settings saved to {Path}", SettingsPath);
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Failed to save settings");
        }
    }

    public static ModifierKeys ParseModifiers(string modifiersStr)
    {
        var result = ModifierKeys.None;
        foreach (var part in modifiersStr.Split('+', StringSplitOptions.TrimEntries))
        {
            if (Enum.TryParse<ModifierKeys>(part, true, out var mod))
                result |= mod;
        }
        return result;
    }

    public static Keys ParseKey(string keyStr)
    {
        if (Enum.TryParse<Keys>(keyStr.Trim(), true, out var key))
            return key;
        return Keys.Space;
    }

    public static string FormatModifiers(ModifierKeys modifiers)
    {
        var parts = new List<string>();
        if (modifiers.HasFlag(ModifierKeys.Control)) parts.Add("Control");
        if (modifiers.HasFlag(ModifierKeys.Shift)) parts.Add("Shift");
        if (modifiers.HasFlag(ModifierKeys.Alt)) parts.Add("Alt");
        if (modifiers.HasFlag(ModifierKeys.Win)) parts.Add("Win");
        return string.Join("+", parts);
    }
}
