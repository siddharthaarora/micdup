using System.Drawing;
using System.Windows.Forms;
using Serilog;

namespace MicDup.Core;

public class SettingsForm : Form
{
    private readonly SettingsManager _settingsManager;
    private MicDup.Core.ModifierKeys _capturedModifiers;
    private Keys _capturedKey;
    private readonly Label _hotkeyDisplay;
    private readonly ComboBox _modelCombo;
    private readonly CheckBox _autoPasteCheck;
    private bool _capturingHotkey;

    public SettingsForm(SettingsManager settingsManager)
    {
        _settingsManager = settingsManager;
        var settings = settingsManager.Settings;

        // Parse current hotkey
        _capturedModifiers = SettingsManager.ParseModifiers(settings.Hotkey.Modifiers);
        _capturedKey = SettingsManager.ParseKey(settings.Hotkey.Key);

        // Form setup
        Text = "MicDup Settings";
        Size = new Size(420, 300);
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        MinimizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        KeyPreview = true;

        var y = 20;

        // -- Hotkey section --
        var hotkeyLabel = new Label
        {
            Text = "Hotkey:",
            Location = new Point(20, y),
            AutoSize = true
        };
        Controls.Add(hotkeyLabel);

        _hotkeyDisplay = new Label
        {
            Text = FormatHotkey(_capturedModifiers, _capturedKey),
            Location = new Point(140, y),
            AutoSize = true,
            Font = new Font(Font, FontStyle.Bold)
        };
        Controls.Add(_hotkeyDisplay);

        y += 35;

        var changeHotkeyBtn = new Button
        {
            Text = "Press to change hotkey...",
            Location = new Point(140, y),
            Width = 200,
            Height = 30
        };
        changeHotkeyBtn.Click += OnChangeHotkeyClick;
        Controls.Add(changeHotkeyBtn);

        y += 50;

        // -- Model section --
        var modelLabel = new Label
        {
            Text = "Whisper Model:",
            Location = new Point(20, y + 3),
            AutoSize = true
        };
        Controls.Add(modelLabel);

        _modelCombo = new ComboBox
        {
            Location = new Point(140, y),
            Width = 200,
            DropDownStyle = ComboBoxStyle.DropDownList
        };
        _modelCombo.Items.AddRange(new object[] { "tiny", "base", "small", "medium", "large" });
        _modelCombo.SelectedItem = settings.Whisper.Model;
        if (_modelCombo.SelectedIndex < 0) _modelCombo.SelectedIndex = 1;
        Controls.Add(_modelCombo);

        y += 40;

        // -- Behavior section --
        _autoPasteCheck = new CheckBox
        {
            Text = "Auto-paste transcription",
            Location = new Point(140, y),
            AutoSize = true,
            Checked = settings.Behavior.AutoPaste
        };
        Controls.Add(_autoPasteCheck);

        y += 50;

        // -- Buttons --
        var saveBtn = new Button
        {
            Text = "Save",
            Location = new Point(200, y),
            Width = 80,
            Height = 30,
            DialogResult = DialogResult.OK
        };
        saveBtn.Click += OnSaveClick;
        Controls.Add(saveBtn);

        var cancelBtn = new Button
        {
            Text = "Cancel",
            Location = new Point(290, y),
            Width = 80,
            Height = 30,
            DialogResult = DialogResult.Cancel
        };
        Controls.Add(cancelBtn);

        AcceptButton = saveBtn;
        CancelButton = cancelBtn;
    }

    private void OnChangeHotkeyClick(object? sender, EventArgs e)
    {
        _capturingHotkey = true;
        _hotkeyDisplay.Text = "Press a key combination...";
        if (sender is Button btn)
            btn.Text = "Listening...";
    }

    protected override void OnKeyDown(KeyEventArgs e)
    {
        if (_capturingHotkey)
        {
            e.SuppressKeyPress = true;

            // Ignore standalone modifier presses
            if (e.KeyCode is Keys.ControlKey or Keys.ShiftKey or Keys.Menu or Keys.LWin or Keys.RWin)
            {
                base.OnKeyDown(e);
                return;
            }

            _capturedModifiers = MicDup.Core.ModifierKeys.None;
            if (e.Control) _capturedModifiers |= MicDup.Core.ModifierKeys.Control;
            if (e.Shift) _capturedModifiers |= MicDup.Core.ModifierKeys.Shift;
            if (e.Alt) _capturedModifiers |= MicDup.Core.ModifierKeys.Alt;

            _capturedKey = e.KeyCode;
            _hotkeyDisplay.Text = FormatHotkey(_capturedModifiers, _capturedKey);
            _capturingHotkey = false;

            // Reset button text
            foreach (Control c in Controls)
            {
                if (c is Button btn && btn.Text == "Listening...")
                    btn.Text = "Press to change hotkey...";
            }
        }

        base.OnKeyDown(e);
    }

    private void OnSaveClick(object? sender, EventArgs e)
    {
        var settings = _settingsManager.Settings;

        settings.Hotkey.Modifiers = SettingsManager.FormatModifiers(_capturedModifiers);
        settings.Hotkey.Key = _capturedKey.ToString();
        settings.Whisper.Model = _modelCombo.SelectedItem?.ToString() ?? "base";
        settings.Behavior.AutoPaste = _autoPasteCheck.Checked;

        _settingsManager.Save();
        Log.Information("Settings saved from form");
    }

    private static string FormatHotkey(MicDup.Core.ModifierKeys modifiers, Keys key)
    {
        var parts = new List<string>();
        if (modifiers.HasFlag(MicDup.Core.ModifierKeys.Control)) parts.Add("Ctrl");
        if (modifiers.HasFlag(MicDup.Core.ModifierKeys.Shift)) parts.Add("Shift");
        if (modifiers.HasFlag(MicDup.Core.ModifierKeys.Alt)) parts.Add("Alt");
        if (modifiers.HasFlag(MicDup.Core.ModifierKeys.Win)) parts.Add("Win");
        parts.Add(key.ToString());
        return string.Join(" + ", parts);
    }
}
