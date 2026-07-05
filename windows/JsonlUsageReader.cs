using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;

namespace CodexStatusBar.Windows;

internal sealed class JsonlUsageReader
{
    private const int MaxTailBytes = 512 * 1024;

    public UsageSnapshot? GetLatestSnapshot()
    {
        var sessionsDirectory = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
            ".codex",
            "sessions"
        );

        if (!Directory.Exists(sessionsDirectory))
        {
            return null;
        }

        return Directory
            .EnumerateFiles(sessionsDirectory, "*.jsonl", SearchOption.AllDirectories)
            .Select(TryReadSnapshot)
            .Where(snapshot => snapshot is not null)
            .OrderByDescending(snapshot => snapshot!.ObservedAt)
            .FirstOrDefault();
    }

    private static UsageSnapshot? TryReadSnapshot(string path)
    {
        foreach (var line in readTailLines(path).Reverse())
        {
            var snapshot = tryReadSnapshotFromLine(line);
            if (snapshot is not null)
            {
                return snapshot;
            }
        }

        return null;
    }

    private static IEnumerable<string> readTailLines(string path)
    {
        using var stream = File.OpenRead(path);
        var bytesToRead = Math.Min(MaxTailBytes, (int)stream.Length);
        stream.Seek(-bytesToRead, SeekOrigin.End);

        using var reader = new StreamReader(stream);
        var text = reader.ReadToEnd();
        var lines = text.Split('\n', StringSplitOptions.RemoveEmptyEntries);

        if (stream.Length <= MaxTailBytes)
        {
            return lines;
        }

        return lines.Skip(1);
    }

    private static UsageSnapshot? tryReadSnapshotFromLine(string line)
    {
        var document = parseLine(line);
        if (document is null)
        {
            return null;
        }

        using (document)
        {
        var root = document.RootElement;

        if (!root.TryGetProperty("timestamp", out var timestamp))
        {
            return null;
        }

        if (!DateTimeOffset.TryParse(timestamp.GetString(), out var observedAt))
        {
            return null;
        }

        if (!tryFindRateLimits(root, out var rateLimits))
        {
            return null;
        }

        var primary = readJsonlWindow(rateLimits, "primary");
        var secondary = readJsonlWindow(rateLimits, "secondary");

        if (primary is null || secondary is null)
        {
            return null;
        }

        return new UsageSnapshot(primary, secondary, observedAt);
        }
    }

    private static JsonDocument? parseLine(string line)
    {
        try
        {
            return JsonDocument.Parse(line);
        }
        catch (JsonException)
        {
            return null;
        }
    }

    private static bool tryFindRateLimits(JsonElement value, out JsonElement rateLimits)
    {
        if (value.ValueKind == JsonValueKind.Object)
        {
            if (value.TryGetProperty("rate_limits", out rateLimits))
            {
                return true;
            }

            foreach (var property in value.EnumerateObject())
            {
                if (tryFindRateLimits(property.Value, out rateLimits))
                {
                    return true;
                }
            }
        }

        if (value.ValueKind == JsonValueKind.Array)
        {
            foreach (var item in value.EnumerateArray())
            {
                if (tryFindRateLimits(item, out rateLimits))
                {
                    return true;
                }
            }
        }

        rateLimits = default;
        return false;
    }

    private static UsageWindow? readJsonlWindow(JsonElement rateLimits, string name)
    {
        if (!rateLimits.TryGetProperty(name, out var window))
        {
            return null;
        }

        if (!window.TryGetProperty("used_percent", out var usedPercent))
        {
            return null;
        }

        if (!window.TryGetProperty("resets_at", out var resetsAt))
        {
            return null;
        }

        return new UsageWindow(
            (int)Math.Round(usedPercent.GetDouble()),
            DateTimeOffset.FromUnixTimeSeconds(resetsAt.GetInt64())
        );
    }
}
