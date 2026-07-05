using System;
using System.Collections.Generic;
using System.Linq;

namespace CodexStatusBar.Windows;

internal sealed record UsageSnapshot(
    UsageWindow FiveHour,
    UsageWindow Weekly,
    DateTimeOffset ObservedAt
)
{
    public DateTimeOffset? NextResetAfter(DateTimeOffset now)
    {
        var resetDates = new List<DateTimeOffset>
        {
            FiveHour.ResetAt,
            Weekly.ResetAt
        };

        return resetDates
            .Where(resetAt => resetAt > now)
            .Order()
            .FirstOrDefault();
    }
}

internal sealed record UsageWindow(int UsedPercent, DateTimeOffset ResetAt)
{
    public int RemainingPercent(DateTimeOffset now)
    {
        if (now >= ResetAt)
        {
            return 100;
        }

        return Math.Clamp(100 - UsedPercent, 0, 100);
    }
}
