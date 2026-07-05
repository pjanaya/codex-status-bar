$ErrorActionPreference = "Stop"

$root = Resolve-Path "$PSScriptRoot\.."
dotnet publish "$root\CodexStatusBar.Windows.csproj" `
    -c Release `
    -r win-x64 `
    --self-contained false `
    -o "$root\publish"

Write-Host "Built $root\publish\CodexStatusBar.exe"
