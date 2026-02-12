using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;

namespace MicDup.Core;

/// <summary>
/// Generates system tray icons for different application states.
/// Draws microphone at 256x256 directly in target color, then scales to 16x16.
/// </summary>
public static class IconGenerator
{
    private const int DrawSize = 256;
    private const int IconSize = 16;

    private static Icon DrawMicrophoneIcon(Color color)
    {
        using var bitmap = new Bitmap(DrawSize, DrawSize, PixelFormat.Format32bppPArgb);
        using var g = Graphics.FromImage(bitmap);
        g.SmoothingMode = SmoothingMode.HighQuality;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        g.Clear(Color.Transparent);

        using var brush = new SolidBrush(color);
        using var pen = new Pen(color, 20f);
        pen.StartCap = LineCap.Round;
        pen.EndCap = LineCap.Round;

        // Mic head (capsule/pill shape) - centered, bold
        using var path = new GraphicsPath();
        int headX = 80, headY = 16, headW = 96, headH = 120;
        int r = headW / 2;
        path.AddArc(headX, headY, headW, headW, 180, 180);
        path.AddLine(headX + headW, headY + r, headX + headW, headY + headH - r);
        path.AddArc(headX, headY + headH - headW, headW, headW, 0, 180);
        path.AddLine(headX, headY + headH - r, headX, headY + r);
        path.CloseFigure();
        g.FillPath(brush, path);

        // Cradle arc (U-shape)
        g.DrawArc(pen, 48, 88, 160, 104, 0, 180);

        // Vertical stem
        g.DrawLine(pen, 128, 192, 128, 220);

        // Horizontal base
        g.DrawLine(pen, 80, 220, 176, 220);

        // Scale down to 16x16
        using var icon16 = new Bitmap(IconSize, IconSize, PixelFormat.Format32bppPArgb);
        using var g16 = Graphics.FromImage(icon16);
        g16.InterpolationMode = InterpolationMode.HighQualityBicubic;
        g16.CompositingQuality = CompositingQuality.HighQuality;
        g16.PixelOffsetMode = PixelOffsetMode.HighQuality;
        g16.DrawImage(bitmap, 0, 0, IconSize, IconSize);

        var hIcon = icon16.GetHicon();
        return Icon.FromHandle(hIcon);
    }

    /// <summary>
    /// Idle state: light gray microphone
    /// </summary>
    public static Icon CreateIdleIcon()
        => DrawMicrophoneIcon(Color.FromArgb(180, 180, 180));

    /// <summary>
    /// Recording state: red microphone
    /// </summary>
    public static Icon CreateRecordingIcon()
        => DrawMicrophoneIcon(Color.FromArgb(220, 50, 50));

    /// <summary>
    /// Processing state: animated rotating arc
    /// </summary>
    public static Icon CreateProcessingIcon(int frame = 0)
    {
        using var bitmap = new Bitmap(IconSize, IconSize, PixelFormat.Format32bppPArgb);
        using var g = Graphics.FromImage(bitmap);
        g.SmoothingMode = SmoothingMode.HighQuality;
        g.Clear(Color.Transparent);

        using var pen = new Pen(Color.FromArgb(100, 100, 255), 2f);
        var rect = new Rectangle(2, 2, 12, 12);
        var startAngle = (frame * 30) % 360;
        g.DrawArc(pen, rect, startAngle, 270);

        var hIcon = bitmap.GetHicon();
        return Icon.FromHandle(hIcon);
    }

    /// <summary>
    /// Success state: green checkmark
    /// </summary>
    public static Icon CreateSuccessIcon()
    {
        using var bitmap = new Bitmap(IconSize, IconSize, PixelFormat.Format32bppPArgb);
        using var g = Graphics.FromImage(bitmap);
        g.SmoothingMode = SmoothingMode.HighQuality;
        g.Clear(Color.Transparent);

        using var pen = new Pen(Color.FromArgb(40, 180, 40), 2f);
        var points = new Point[]
        {
            new Point(4, 8),
            new Point(7, 11),
            new Point(12, 4)
        };
        g.DrawLines(pen, points);

        var hIcon = bitmap.GetHicon();
        return Icon.FromHandle(hIcon);
    }

    /// <summary>
    /// Error state: red X
    /// </summary>
    public static Icon CreateErrorIcon()
    {
        using var bitmap = new Bitmap(IconSize, IconSize, PixelFormat.Format32bppPArgb);
        using var g = Graphics.FromImage(bitmap);
        g.SmoothingMode = SmoothingMode.HighQuality;
        g.Clear(Color.Transparent);

        using var pen = new Pen(Color.FromArgb(220, 50, 50), 2f);
        g.DrawLine(pen, 4, 4, 12, 12);
        g.DrawLine(pen, 12, 4, 4, 12);

        var hIcon = bitmap.GetHicon();
        return Icon.FromHandle(hIcon);
    }
}
