using System;
using System.Drawing;
using System.Windows.Forms;

namespace CodexStatusBar.Windows;

internal sealed class TrayApplicationContext : ApplicationContext
{
    private readonly AppServerUsageReader appServerReader = new();
    private readonly JsonlUsageReader jsonlReader = new();
    private readonly NotifyIcon notifyIcon;
    private readonly System.Windows.Forms.Timer refreshTimer;
    private readonly System.Windows.Forms.Timer resetTimer;
    private ToolStripMenuItem? statusMenuItem;

    private UsageSnapshot? snapshot;

    public TrayApplicationContext()
    {
        notifyIcon = new NotifyIcon
        {
            ContextMenuStrip = createMenu(),
            Text = "Codex Status Bar",
            Visible = true
        };

        refreshTimer = new System.Windows.Forms.Timer
        {
            Interval = 5 * 60 * 1000
        };
        refreshTimer.Tick += async (_, _) => await refreshAsync();

        resetTimer = new System.Windows.Forms.Timer();
        resetTimer.Tick += (_, _) => publish();

        _ = refreshAsync();
        refreshTimer.Start();
    }

    private ContextMenuStrip createMenu()
    {
        var menu = new ContextMenuStrip();
        statusMenuItem = new ToolStripMenuItem("No usage snapshot yet")
        {
            Enabled = false
        };
        menu.Items.Add(statusMenuItem);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Refresh", null, async (_, _) => await refreshAsync());
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Quit Codex Status Bar", null, (_, _) => exit());
        return menu;
    }

    private async Task refreshAsync()
    {
        try
        {
            snapshot = await appServerReader.GetLatestSnapshotAsync();
        }
        catch
        {
            snapshot = jsonlReader.GetLatestSnapshot();
        }

        publish();
        scheduleResetTimer();
    }

    private void publish()
    {
        var now = DateTimeOffset.Now;
        var fiveHour = snapshot?.FiveHour.RemainingPercent(now);
        var weekly = snapshot?.Weekly.RemainingPercent(now);

        notifyIcon.Text = makeCompactTooltip(now);
        if (statusMenuItem is not null)
        {
            statusMenuItem.Text = makeStatusText(now);
        }

        var nextIcon = TrayIconRenderer.Render(fiveHour, weekly);
        var previousIcon = notifyIcon.Icon;
        notifyIcon.Icon = nextIcon;
        previousIcon?.Dispose();
    }

    private string makeCompactTooltip(DateTimeOffset now)
    {
        if (snapshot is null)
        {
            return "Codex: no usage snapshot yet";
        }

        var fiveHour = snapshot.FiveHour.RemainingPercent(now);
        var weekly = snapshot.Weekly.RemainingPercent(now);

        return $"5h {fiveHour}% {snapshot.FiveHour.ResetAt.LocalDateTime:HH:mm} | W {weekly}% {snapshot.Weekly.ResetAt.LocalDateTime:dd/MM}";
    }

    private string makeStatusText(DateTimeOffset now)
    {
        if (snapshot is null)
        {
            return "No usage snapshot yet";
        }

        var fiveHour = snapshot.FiveHour.RemainingPercent(now);
        var weekly = snapshot.Weekly.RemainingPercent(now);
        var observed = snapshot.ObservedAt.LocalDateTime.ToShortTimeString();

        return $"5h {fiveHour}% resets {snapshot.FiveHour.ResetAt.LocalDateTime:HH:mm}; Week {weekly}% resets {snapshot.Weekly.ResetAt.LocalDateTime:dd/MM}; Updated {observed}";
    }

    private void scheduleResetTimer()
    {
        resetTimer.Stop();

        if (snapshot is null)
        {
            return;
        }

        var now = DateTimeOffset.Now;
        var nextReset = snapshot.NextResetAfter(now);

        if (nextReset is null)
        {
            return;
        }

        var delay = nextReset.Value - now;
        resetTimer.Interval = Math.Max(1000, (int)Math.Min(delay.TotalMilliseconds, int.MaxValue));
        resetTimer.Start();
    }

    private void exit()
    {
        notifyIcon.Visible = false;
        notifyIcon.Dispose();
        refreshTimer.Dispose();
        resetTimer.Dispose();
        Application.Exit();
    }
}
