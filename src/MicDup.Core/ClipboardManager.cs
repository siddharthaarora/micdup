using System.Runtime.InteropServices;
using System.Threading;
using Serilog;
using TextCopy;

namespace MicDup.Core;

/// <summary>
/// Manages clipboard operations for copying transcribed text
/// </summary>
public static class ClipboardManager
{
    /// <summary>
    /// Copies text to the system clipboard
    /// </summary>
    /// <param name="text">Text to copy</param>
    /// <returns>True if successful, false otherwise</returns>
    public static async Task<bool> CopyToClipboardAsync(string text)
    {
        if (string.IsNullOrEmpty(text))
        {
            Log.Warning("Attempted to copy empty text to clipboard");
            return false;
        }

        try
        {
            // TextCopy library handles cross-platform clipboard access
            await ClipboardService.SetTextAsync(text);

            Log.Information("Copied {Length} characters to clipboard", text.Length);
            return true;
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Failed to copy text to clipboard");
            return false;
        }
    }

    /// <summary>
    /// Gets text from the system clipboard
    /// </summary>
    /// <returns>Clipboard text or empty string if unavailable</returns>
    public static async Task<string> GetClipboardTextAsync()
    {
        try
        {
            var text = await ClipboardService.GetTextAsync();
            return text ?? string.Empty;
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Failed to get text from clipboard");
            return string.Empty;
        }
    }

    /// <summary>
    /// Clears the clipboard
    /// </summary>
    public static async Task ClearClipboardAsync()
    {
        try
        {
            await ClipboardService.SetTextAsync(string.Empty);
            Log.Information("Clipboard cleared");
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Failed to clear clipboard");
        }
    }
}
