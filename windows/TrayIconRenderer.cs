using System;
using System.Drawing;
using System.Runtime.InteropServices;

namespace CodexStatusBar.Windows;

internal static class TrayIconRenderer
{
    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool DestroyIcon(IntPtr handle);

    public static Icon Render(int? fiveHourPercent, int? weeklyPercent)
    {
        using var bitmap = new Bitmap(32, 32);
        using var graphics = Graphics.FromImage(bitmap);
        using var font = new Font(FontFamily.GenericSansSerif, 9, FontStyle.Bold, GraphicsUnit.Pixel);

        graphics.Clear(Color.Transparent);
        graphics.TextRenderingHint = System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;

        drawCenteredText(graphics, font, fiveHourPercent, 0);
        drawCenteredText(graphics, font, weeklyPercent, 15);

        var handle = bitmap.GetHicon();

        try
        {
            return (Icon)Icon.FromHandle(handle).Clone();
        }
        finally
        {
            DestroyIcon(handle);
        }
    }

    private static void drawCenteredText(Graphics graphics, Font font, int? percent, int y)
    {
        var text = percent?.ToString() ?? "--";
        var color = colorFor(percent);

        using var brush = new SolidBrush(color);
        using var format = new StringFormat
        {
            Alignment = StringAlignment.Center,
            LineAlignment = StringAlignment.Center
        };

        graphics.DrawString(text, font, brush, new RectangleF(0, y, 32, 14), format);
    }

    private static Color colorFor(int? percent)
    {
        if (percent is null)
        {
            return Color.White;
        }

        if (percent < 5)
        {
            return Color.Red;
        }

        if (percent < 15)
        {
            return Color.Gold;
        }

        return Color.White;
    }
}
