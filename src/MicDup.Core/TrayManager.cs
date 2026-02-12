using System.Drawing;
using System.Windows.Forms;
using Serilog;

namespace MicDup.Core;

/// <summary>
/// Manages the system tray icon and context menu
/// </summary>
public class TrayManager : IDisposable
{
    private NotifyIcon? _notifyIcon;
    private ContextMenuStrip? _contextMenu;
    private ToolStripMenuItem? _statusItem;
    private ToolStripMenuItem? _startStopItem;
    private ToolStripMenuItem? _exitItem;
    private System.Windows.Forms.Timer? _animationTimer;
    private int _animationFrame = 0;
    private TrayState _currentState = TrayState.Idle;

    public event EventHandler? StartStopClicked;
    public event EventHandler? SettingsClicked;
    public event EventHandler? ExitClicked;

    public void Initialize()
    {
        try
        {
            // Create context menu
            _contextMenu = new ContextMenuStrip();

            _statusItem = new ToolStripMenuItem("Status: Ready")
            {
                Enabled = false
            };

            _startStopItem = new ToolStripMenuItem("Start Recording");
            _startStopItem.Click += (s, e) => StartStopClicked?.Invoke(this, EventArgs.Empty);

            var settingsItem = new ToolStripMenuItem("Settings...");
            settingsItem.Click += (s, e) => SettingsClicked?.Invoke(this, EventArgs.Empty);

            _exitItem = new ToolStripMenuItem("Exit");
            _exitItem.Click += (s, e) => ExitClicked?.Invoke(this, EventArgs.Empty);

            _contextMenu.Items.AddRange(new ToolStripItem[]
            {
                _statusItem,
                new ToolStripSeparator(),
                _startStopItem,
                new ToolStripSeparator(),
                settingsItem,
                new ToolStripSeparator(),
                _exitItem
            });

            // Create notify icon with idle microphone icon
            _notifyIcon = new NotifyIcon
            {
                Icon = IconGenerator.CreateIdleIcon(),
                ContextMenuStrip = _contextMenu,
                Text = "Micd Up - Speech to Text",
                Visible = true
            };

            // Handle double-click to start/stop
            _notifyIcon.DoubleClick += (s, e) => StartStopClicked?.Invoke(this, EventArgs.Empty);

            // Create animation timer for processing state
            _animationTimer = new System.Windows.Forms.Timer();
            _animationTimer.Interval = 100; // Update every 100ms
            _animationTimer.Tick += OnAnimationTick;

            Log.Information("System tray icon initialized");
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Failed to initialize system tray");
            throw;
        }
    }

    /// <summary>
    /// Sets the current state and updates the icon/menu
    /// </summary>
    public void SetState(TrayState state)
    {
        if (_notifyIcon == null || _statusItem == null || _startStopItem == null)
            return;

        _currentState = state;

        switch (state)
        {
            case TrayState.Idle:
                _animationTimer?.Stop();
                _statusItem.Text = "Status: Ready";
                _startStopItem.Text = "Start Recording";
                _startStopItem.Enabled = true;
                _notifyIcon.Text = "Micd Up - Ready";
                _notifyIcon.Icon = IconGenerator.CreateIdleIcon();
                break;

            case TrayState.Recording:
                _animationTimer?.Stop();
                _statusItem.Text = "Status: Recording...";
                _startStopItem.Text = "Stop Recording";
                _startStopItem.Enabled = true;
                _notifyIcon.Text = "Micd Up - Recording";
                _notifyIcon.Icon = IconGenerator.CreateRecordingIcon();
                break;

            case TrayState.Processing:
                _statusItem.Text = "Status: Transcribing...";
                _startStopItem.Enabled = false;
                _notifyIcon.Text = "Micd Up - Processing";
                _animationFrame = 0;
                _animationTimer?.Start(); // Start animation
                break;

            case TrayState.Success:
                _animationTimer?.Stop();
                _statusItem.Text = "Status: Text copied!";
                _startStopItem.Text = "Start Recording";
                _startStopItem.Enabled = true;
                _notifyIcon.Text = "Micd Up - Success";
                _notifyIcon.Icon = IconGenerator.CreateSuccessIcon();

                // Reset to idle after 2 seconds
                Task.Delay(2000).ContinueWith(_ => SetState(TrayState.Idle));
                break;

            case TrayState.Error:
                _animationTimer?.Stop();
                _statusItem.Text = "Status: Error occurred";
                _startStopItem.Text = "Start Recording";
                _startStopItem.Enabled = true;
                _notifyIcon.Text = "Micd Up - Error";
                _notifyIcon.Icon = IconGenerator.CreateErrorIcon();

                // Reset to idle after 3 seconds
                Task.Delay(3000).ContinueWith(_ => SetState(TrayState.Idle));
                break;
        }

        Log.Debug("Tray state changed to: {State}", state);
    }

    private void OnAnimationTick(object? sender, EventArgs e)
    {
        if (_notifyIcon == null || _currentState != TrayState.Processing)
        {
            _animationTimer?.Stop();
            return;
        }

        _animationFrame++;
        _notifyIcon.Icon = IconGenerator.CreateProcessingIcon(_animationFrame);
    }

    /// <summary>
    /// Shows a balloon notification using the current tray icon
    /// </summary>
    public void ShowNotification(string title, string message, ToolTipIcon icon = ToolTipIcon.None)
    {
        if (_notifyIcon == null)
            return;

        try
        {
            // Use ToolTipIcon.None to display the custom tray icon instead of system icons
            _notifyIcon.ShowBalloonTip(2000, title, message, ToolTipIcon.None);
        }
        catch (Exception ex)
        {
            Log.Warning(ex, "Failed to show notification");
        }
    }

    public void Dispose()
    {
        _animationTimer?.Stop();
        _animationTimer?.Dispose();
        _animationTimer = null;

        if (_notifyIcon != null)
        {
            _notifyIcon.Visible = false;
            _notifyIcon.Dispose();
            _notifyIcon = null;
        }

        _contextMenu?.Dispose();
        _contextMenu = null;

        Log.Information("System tray icon disposed");
    }
}

/// <summary>
/// Represents the current state of the application
/// </summary>
public enum TrayState
{
    Idle,
    Recording,
    Processing,
    Success,
    Error
}
