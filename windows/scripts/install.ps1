$ErrorActionPreference = "Stop"

$root = Resolve-Path "$PSScriptRoot\.."
$publishDir = Join-Path $root "publish"
$sourceExe = Join-Path $publishDir "CodexStatusBar.exe"
$installDir = Join-Path $env:LOCALAPPDATA "CodexStatusBar"
$installExe = Join-Path $installDir "CodexStatusBar.exe"
$runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"

if (-not (Test-Path $sourceExe)) {
    throw "Build the app first with windows\scripts\build.ps1"
}

Get-Process CodexStatusBar -ErrorAction SilentlyContinue | Stop-Process -Force

New-Item -ItemType Directory -Force -Path $installDir | Out-Null
Copy-Item -Recurse -Force "$publishDir\*" $installDir
Set-ItemProperty -Path $runKey -Name "Codex Status Bar" -Value "`"$installExe`""
Start-Process $installExe

Write-Host "Installed $installExe"
Write-Host "Enabled launch at login"
