namespace MicDup.Core;

public class AppSettings
{
    public HotkeySettings Hotkey { get; set; } = new();
    public WhisperSettings Whisper { get; set; } = new();
    public BehaviorSettings Behavior { get; set; } = new();
}

public class HotkeySettings
{
    public string Modifiers { get; set; } = "Control+Shift";
    public string Key { get; set; } = "Space";
    public bool Enabled { get; set; } = true;
}

public class WhisperSettings
{
    public string Model { get; set; } = "base";
    public string Language { get; set; } = "en";
}

public class BehaviorSettings
{
    public bool AutoPaste { get; set; } = true;
    public bool ShowNotifications { get; set; } = true;
}
