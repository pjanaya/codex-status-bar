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

## Install for a Windows coworker

The installer is per Windows user. It copies the published app into the
user's local application directory and registers it to launch automatically
when that user signs in after a reboot.

1. Install the prerequisites above and make sure Codex works in PowerShell:

   ```powershell
   codex --version
   ```

2. Clone the repository and enter it:

   ```powershell
   git clone https://github.com/pjanaya/codex-status-bar.git
   cd codex-status-bar
   ```

3. Build and install the Windows app:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\windows\scripts\build.ps1
   powershell -ExecutionPolicy Bypass -File .\windows\scripts\install.ps1
   ```

The app starts immediately after installation. It does not open a normal
window; look in the notification area's hidden-icons menu for the tray icon.
The startup registration applies at sign-in, so repeat the installation for
each Windows account that should run the indicator.

To confirm the startup entry:

```powershell
Get-ItemProperty `
  -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
  -Name "Codex Status Bar"
```

## Install manually

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

- Reads live limits from `codex app-server`.
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
