using System.Runtime.InteropServices;
using System.Windows.Forms;
using Serilog;

namespace MicDup.Core;

/// <summary>
/// Manages global hotkey registration using Win32 API
/// </summary>
public class HotkeyManager : IDisposable
{
    private const int WM_HOTKEY = 0x0312;
    private const int HOTKEY_ID = 1;

    private HotkeyWindow? _window;
    private bool _isRegistered;

    public event EventHandler? HotkeyPressed;

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    /// <summary>
    /// Registers the global hotkey (CTRL+SHIFT+SPACE by default)
    /// </summary>
    public bool RegisterHotkey(ModifierKeys modifiers = ModifierKeys.Control | ModifierKeys.Shift,
                               Keys key = Keys.Space)
    {
        try
        {
            if (_isRegistered)
            {
                Log.Warning("Hotkey already registered");
                return true;
            }

            // Create a message-only window to receive hotkey messages
            _window = new HotkeyWindow();
            _window.HotkeyPressed += (s, e) => HotkeyPressed?.Invoke(this, EventArgs.Empty);

            var result = RegisterHotKey(
                _window.Handle,
                HOTKEY_ID,
                (uint)modifiers,
                (uint)key);

            if (result)
            {
                _isRegistered = true;
                Log.Information("Global hotkey registered: {Modifiers}+{Key}", modifiers, key);
            }
            else
            {
                var error = Marshal.GetLastWin32Error();
                Log.Error("Failed to register hotkey. Error code: {ErrorCode}", error);
            }

            return result;
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Exception while registering hotkey");
            return false;
        }
    }

    /// <summary>
    /// Unregisters the global hotkey
    /// </summary>
    public void UnregisterHotkey()
    {
        if (!_isRegistered || _window == null)
            return;

        try
        {
            UnregisterHotKey(_window.Handle, HOTKEY_ID);
            _isRegistered = false;
            Log.Information("Global hotkey unregistered");
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Error unregistering hotkey");
        }
    }

    /// <summary>
    /// Unregisters current hotkey and registers a new one
    /// </summary>
    public bool ReregisterHotkey(ModifierKeys modifiers, Keys key)
    {
        UnregisterHotkey();
        _window?.Dispose();
        _window = null;
        return RegisterHotkey(modifiers, key);
    }

    public void Dispose()
    {
        UnregisterHotkey();
        _window?.Dispose();
        _window = null;
    }

    /// <summary>
    /// Hidden window to receive hotkey messages
    /// </summary>
    private class HotkeyWindow : Form
    {
        public event EventHandler? HotkeyPressed;

        public HotkeyWindow()
        {
            // Create a message-only window (invisible)
            this.FormBorderStyle = FormBorderStyle.None;
            this.ShowInTaskbar = false;
            this.WindowState = FormWindowState.Minimized;
            this.Width = 0;
            this.Height = 0;
            this.Opacity = 0;
        }

        protected override void WndProc(ref Message m)
        {
            if (m.Msg == WM_HOTKEY)
            {
                HotkeyPressed?.Invoke(this, EventArgs.Empty);
            }

            base.WndProc(ref m);
        }

        protected override void SetVisibleCore(bool value)
        {
            // Keep the window hidden
            base.SetVisibleCore(false);
        }
    }
}

/// <summary>
/// Modifier keys for hotkey combinations
/// </summary>
[Flags]
public enum ModifierKeys : uint
{
    None = 0,
    Alt = 1,
    Control = 2,
    Shift = 4,
    Win = 8
}
