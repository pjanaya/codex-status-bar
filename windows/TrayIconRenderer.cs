using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;

namespace CodexStatusBar.Windows;

internal static class TrayIconRenderer
{
    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool DestroyIcon(IntPtr handle);

    public static Icon Render(int? percent)
    {
        using var bitmap = new Bitmap(32, 32);
        using var graphics = Graphics.FromImage(bitmap);

        graphics.Clear(Color.Transparent);
        graphics.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAliasGridFit;

        drawCenteredText(graphics, percent);

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

    private static void drawCenteredText(Graphics graphics, int? percent)
    {
        var text = percent?.ToString() ?? "--";
        var color = colorFor(percent);
        using var font = makeReadableFont(graphics, text);
        using var format = new StringFormat
        {
            Alignment = StringAlignment.Center,
            LineAlignment = StringAlignment.Center,
            FormatFlags = StringFormatFlags.NoWrap,
            Trimming = StringTrimming.None
        };

        var measured = graphics.MeasureString(text, font, new PointF(0, 0), format);
        var layerWidth = Math.Max(1, (int)Math.Ceiling(measured.Width) + 8);

        using var textLayer = new Bitmap(layerWidth, 32);
        using (var layerGraphics = Graphics.FromImage(textLayer))
        {
            layerGraphics.Clear(Color.Transparent);
            layerGraphics.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAliasGridFit;

            var layout = new RectangleF(3, 0, layerWidth - 6, 32);
            using var shadowBrush = new SolidBrush(Color.FromArgb(220, Color.Black));
            using var brush = new SolidBrush(color);
            layerGraphics.DrawString(text, font, shadowBrush, new RectangleF(4, 1, layerWidth - 6, 32), format);
            layerGraphics.DrawString(text, font, brush, layout, format);
        }

        graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
        graphics.DrawImage(
            textLayer,
            new Rectangle(1, 0, 30, 32),
            0,
            0,
            textLayer.Width,
            textLayer.Height,
            GraphicsUnit.Pixel
        );
    }

    private static Font makeReadableFont(Graphics graphics, string text)
    {
        var fontSize = text.Length >= 3 ? 24f : 30f;

        while (fontSize > 8)
        {
            var font = new Font(
                FontFamily.GenericSansSerif,
                fontSize,
                FontStyle.Bold,
                GraphicsUnit.Pixel
            );

            if (graphics.MeasureString(text, font).Height <= 29)
            {
                return font;
            }

            font.Dispose();
            fontSize -= 1;
        }

        return new Font(
            FontFamily.GenericSansSerif,
            8,
            FontStyle.Bold,
            GraphicsUnit.Pixel
        );
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
