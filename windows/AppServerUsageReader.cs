using System;
using System.Diagnostics;
using System.Text;
using System.Text.Json;

namespace CodexStatusBar.Windows;

internal sealed class AppServerUsageReader
{
    public async Task<UsageSnapshot> GetLatestSnapshotAsync()
    {
        using var process = startCodexAppServer();

        var initializeRequest = """
            {"id":1,"method":"initialize","params":{"clientInfo":{"name":"codex-status-bar","title":"Codex Status Bar","version":"0.1.0"},"capabilities":{"experimentalApi":true}}}
            
            """;
        var rateLimitsRequest = """
            {"method":"initialized"}
            {"id":2,"method":"account/rateLimits/read"}
            
            """;

        await process.StandardInput.WriteAsync(initializeRequest);
        await process.StandardInput.FlushAsync();
        await Task.Delay(200);
        await process.StandardInput.WriteAsync(rateLimitsRequest);
        await process.StandardInput.FlushAsync();
        await Task.Delay(2000);
        process.StandardInput.Close();

        var output = await process.StandardOutput.ReadToEndAsync();
        await process.WaitForExitAsync();

        var snapshot = TryReadSnapshot(output, DateTimeOffset.Now);
        if (snapshot is null)
        {
            throw new InvalidOperationException("Codex app-server did not return rate limits.");
        }

        return snapshot;
    }

    public static UsageSnapshot? TryReadSnapshot(string output, DateTimeOffset observedAt)
    {
        foreach (var line in output.Split('\n', StringSplitOptions.RemoveEmptyEntries))
        {
            using var document = JsonDocument.Parse(line);
            var root = document.RootElement;

            if (!root.TryGetProperty("id", out var id) || id.GetInt32() != 2)
            {
                continue;
            }

            if (!root.TryGetProperty("result", out var result))
            {
                continue;
            }

            if (!result.TryGetProperty("rateLimits", out var rateLimits))
            {
                continue;
            }

            var primary = readWindow(rateLimits, "primary");
            var secondary = readWindow(rateLimits, "secondary");

            if (primary is null || secondary is null)
            {
                return null;
            }

            return new UsageSnapshot(primary, secondary, observedAt);
        }

        return null;
    }

    private static Process startCodexAppServer()
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = "codex",
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        startInfo.ArgumentList.Add("app-server");
        startInfo.ArgumentList.Add("--stdio");

        return Process.Start(startInfo)
            ?? throw new InvalidOperationException("Could not start Codex app-server.");
    }

    private static UsageWindow? readWindow(JsonElement rateLimits, string name)
    {
        if (!rateLimits.TryGetProperty(name, out var window))
        {
            return null;
        }

        if (!window.TryGetProperty("usedPercent", out var usedPercent))
        {
            return null;
        }

        if (!window.TryGetProperty("resetsAt", out var resetsAt))
        {
            return null;
        }

        return new UsageWindow(
            usedPercent.GetInt32(),
            DateTimeOffset.FromUnixTimeSeconds(resetsAt.GetInt64())
        );
    }
}
