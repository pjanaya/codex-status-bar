# Codex Status Bar for Windows

A Windows notification-area version of Codex Status Bar.

Windows does not support a persistent two-line text label in the system tray the
way macOS does. This version renders the two remaining percentages into the tray
icon and shows reset details in the tooltip.

## Requirements

- Windows 10 or newer.
- [.NET 8 SDK](https://dotnet.microsoft.com/download) to build from source.
- Codex CLI available on `PATH`.
- Codex installed and used at least once.

## Build

From the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\scripts\build.ps1
```

The app is published to:

```text
windows\publish\CodexStatusBar.exe
```

## Install

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\scripts\install.ps1
```

The installer copies the published app to:

```text
%LOCALAPPDATA%\CodexStatusBar
```

It also adds a per-user startup entry under:

```text
HKCU\Software\Microsoft\Windows\CurrentVersion\Run
```

## Behavior

- Reads live limits from `codex app-server --stdio`.
- Refreshes live limits every five minutes.
- Uses `%USERPROFILE%\.codex\sessions` JSONL snapshots as a fallback.
- Shows the reset times in the notification tooltip.
- Turns percentage text yellow below `15%` and red below `5%`.

## Uninstall

Quit the tray app, then run:

```powershell
Remove-ItemProperty `
  -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
  -Name "Codex Status Bar" `
  -ErrorAction SilentlyContinue

Remove-Item "$env:LOCALAPPDATA\CodexStatusBar" -Recurse -Force
```
