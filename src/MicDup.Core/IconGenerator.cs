using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;

namespace MicDup.Core;

/// <summary>
/// Generates system tray icons for different application states
/// </summary>
public static class IconGenerator
{
    private const int IconSize = 16;

    [DllImport("shell32.dll", CharSet = CharSet.Auto)]
    private static extern IntPtr ExtractIcon(IntPtr hInst, string lpszExeFileName, int nIconIndex);

    private static Icon? _baseMicrophoneIcon;

    /// <summary>
    /// Loads the Windows system microphone icon
    /// </summary>
    private static Icon GetSystemMicrophoneIcon()
    {
        if (_baseMicrophoneIcon != null)
            return _baseMicrophoneIcon;

        // Try multiple sources for microphone icon
        var iconSources = new[]
        {
            (Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "SndVolSSO.dll"), 25),
            (Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "SndVolSSO.dll"), 24),
            (Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "mmres.dll"), 3001),
            (Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "mmres.dll"), 3003),
            (Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "shell32.dll"), 164), // Sound icon
        };

        foreach (var (dllPath, iconIndex) in iconSources)
        {
            try
            {
                if (!File.Exists(dllPath))
                    continue;

                IntPtr hIcon = ExtractIcon(IntPtr.Zero, dllPath, iconIndex);

                if (hIcon != IntPtr.Zero && hIcon != (IntPtr)1) // 1 means no icon found
                {
                    _baseMicrophoneIcon = Icon.FromHandle(hIcon);
                    Serilog.Log.Information($"Loaded microphone icon from {Path.GetFileName(dllPath)} index {iconIndex}");
                    return _baseMicrophoneIcon;
                }
            }
            catch (Exception ex)
            {
                Serilog.Log.Debug(ex, $"Failed to extract icon from {dllPath}");
            }
        }

        // If we can't get the system icon, create a simple one
        Serilog.Log.Warning("Could not extract Windows microphone icon, using fallback");
        _baseMicrophoneIcon = CreateSimpleMicrophoneIcon(Color.Gray);
        return _baseMicrophoneIcon;
    }

    /// <summary>
    /// Creates a simple microphone icon as fallback
    /// </summary>
    private static Icon CreateSimpleMicrophoneIcon(Color color)
    {
        using var bitmap = new Bitmap(IconSize, IconSize);
        using var graphics = Graphics.FromImage(bitmap);

        graphics.SmoothingMode = SmoothingMode.AntiAlias;
        graphics.Clear(Color.Transparent);

        using var pen = new Pen(color, 1.5f);
        using var brush = new SolidBrush(color);

        // Draw simple microphone shape
        graphics.FillEllipse(brush, 6, 3, 4, 6);
        graphics.DrawArc(pen, 4, 8, 8, 6, 0, 180);
        graphics.DrawLine(pen, 8, 14, 8, 15);
        graphics.DrawLine(pen, 6, 15, 10, 15);

        var hIcon = bitmap.GetHicon();
        return Icon.FromHandle(hIcon);
    }

    /// <summary>
    /// Creates a colorized version of the microphone icon by replacing pixel colors
    /// </summary>
    private static Icon ColorizeIcon(Icon baseIcon, Color targetColor)
    {
        using var sourceBitmap = baseIcon.ToBitmap();
        var bitmap = new Bitmap(IconSize, IconSize);

        // Recolor each pixel
        for (int y = 0; y < IconSize; y++)
        {
            for (int x = 0; x < IconSize; x++)
            {
                var pixel = sourceBitmap.GetPixel(x, y);

                // If pixel is not fully transparent, recolor it
                if (pixel.A > 0)
                {
                    // Calculate brightness/intensity from original pixel
                    float brightness = (pixel.R + pixel.G + pixel.B) / (3f * 255f);

                    // Apply the brightness to the target color, preserving alpha
                    int newR = (int)(targetColor.R * brightness);
                    int newG = (int)(targetColor.G * brightness);
                    int newB = (int)(targetColor.B * brightness);

                    bitmap.SetPixel(x, y, Color.FromArgb(pixel.A, newR, newG, newB));
                }
                else
                {
                    bitmap.SetPixel(x, y, Color.Transparent);
                }
            }
        }

        var hIcon = bitmap.GetHicon();
        return Icon.FromHandle(hIcon);
    }

    /// <summary>
    /// Creates an idle microphone icon (gray)
    /// </summary>
    public static Icon CreateIdleIcon()
    {
        var baseIcon = GetSystemMicrophoneIcon();
        return ColorizeIcon(baseIcon, Color.Gray);
    }

    /// <summary>
    /// Creates a recording microphone icon (brownish orange)
    /// </summary>
    public static Icon CreateRecordingIcon()
    {
        var baseIcon = GetSystemMicrophoneIcon();
        return ColorizeIcon(baseIcon, Color.FromArgb(205, 92, 35));
    }

    /// <summary>
    /// Creates a processing icon (rotating circle)
    /// </summary>
    public static Icon CreateProcessingIcon(int frame = 0)
    {
        using var bitmap = new Bitmap(IconSize, IconSize);
        using var graphics = Graphics.FromImage(bitmap);

        graphics.SmoothingMode = SmoothingMode.AntiAlias;
        graphics.Clear(Color.Transparent);

        using var pen = new Pen(Color.FromArgb(100, 100, 255), 2f);

        // Draw rotating arc
        var rect = new Rectangle(2, 2, 12, 12);
        var startAngle = (frame * 30) % 360; // Rotate 30 degrees per frame
        graphics.DrawArc(pen, rect, startAngle, 270);

        var hIcon = bitmap.GetHicon();
        return Icon.FromHandle(hIcon);
    }

    /// <summary>
    /// Creates a success icon (green checkmark)
    /// </summary>
    public static Icon CreateSuccessIcon()
    {
        using var bitmap = new Bitmap(IconSize, IconSize);
        using var graphics = Graphics.FromImage(bitmap);

        graphics.SmoothingMode = SmoothingMode.AntiAlias;
        graphics.Clear(Color.Transparent);

        using var pen = new Pen(Color.FromArgb(40, 180, 40), 2f);

        // Draw checkmark
        var points = new Point[]
        {
            new Point(4, 8),
            new Point(7, 11),
            new Point(12, 4)
        };
        graphics.DrawLines(pen, points);

        var hIcon = bitmap.GetHicon();
        return Icon.FromHandle(hIcon);
    }

    /// <summary>
    /// Creates an error icon (red X)
    /// </summary>
    public static Icon CreateErrorIcon()
    {
        using var bitmap = new Bitmap(IconSize, IconSize);
        using var graphics = Graphics.FromImage(bitmap);

        graphics.SmoothingMode = SmoothingMode.AntiAlias;
        graphics.Clear(Color.Transparent);

        using var pen = new Pen(Color.FromArgb(220, 50, 50), 2f);

        // Draw X
        graphics.DrawLine(pen, 4, 4, 12, 12);
        graphics.DrawLine(pen, 12, 4, 4, 12);

        var hIcon = bitmap.GetHicon();
        return Icon.FromHandle(hIcon);
    }
}
