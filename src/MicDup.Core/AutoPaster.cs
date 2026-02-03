using System.Runtime.InteropServices;
using Serilog;

namespace MicDup.Core;

/// <summary>
/// Handles automatic pasting of transcribed text into the active window
/// </summary>
public static class AutoPaster
{
    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    private static extern int GetWindowThreadProcessId(IntPtr hWnd, out int lpdwProcessId);

    [DllImport("user32.dll")]
    private static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

    private const byte VK_CONTROL = 0x11;
    private const byte VK_V = 0x56;
    private const uint KEYEVENTF_KEYDOWN = 0x0000;
    private const uint KEYEVENTF_KEYUP = 0x0002;

    /// <summary>
    /// Checks if the foreground window is likely a text input
    /// This is a best-effort check - returns true if any window has focus
    /// </summary>
    public static bool IsFocusedWindowTextInput()
    {
        try
        {
            var foregroundWindow = GetForegroundWindow();

            // If there's a foreground window, assume it might accept text
            // More sophisticated checks could be added here
            return foregroundWindow != IntPtr.Zero;
        }
        catch (Exception ex)
        {
            Log.Warning(ex, "Error checking foreground window");
            return false;
        }
    }

    /// <summary>
    /// Simulates Ctrl+V keypress to paste from clipboard
    /// </summary>
    public static async Task PasteFromClipboardAsync()
    {
        try
        {
            // Small delay to ensure clipboard is ready
            await Task.Delay(100);

            // Press Ctrl
            keybd_event(VK_CONTROL, 0, KEYEVENTF_KEYDOWN, UIntPtr.Zero);

            // Small delay
            await Task.Delay(10);

            // Press V
            keybd_event(VK_V, 0, KEYEVENTF_KEYDOWN, UIntPtr.Zero);

            // Release V
            keybd_event(VK_V, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);

            // Small delay
            await Task.Delay(10);

            // Release Ctrl
            keybd_event(VK_CONTROL, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);

            Log.Information("Auto-paste executed (Ctrl+V simulated)");
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Error during auto-paste");
            throw;
        }
    }

    /// <summary>
    /// Gets the process ID of the foreground window
    /// </summary>
    public static int GetForegroundWindowProcessId()
    {
        try
        {
            var foregroundWindow = GetForegroundWindow();
            GetWindowThreadProcessId(foregroundWindow, out int processId);
            return processId;
        }
        catch (Exception ex)
        {
            Log.Warning(ex, "Error getting foreground window process ID");
            return 0;
        }
    }
}
