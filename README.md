# Codex Status Bar

A tiny, local-only macOS menu-bar indicator for Codex usage limits.

```text
95% 14:25
62% 07/06
```

The first line shows the remaining allowance and reset time for the five-hour
window. The second shows the remaining weekly allowance and reset date.

## Privacy

The app has no networking code and does not read Codex credentials. It reads
rate-limit snapshots from JSONL files in `~/.codex/sessions`.

## Behavior

- Scans session file metadata once per minute.
- Reads only the tail of recently modified JSONL files.
- Switches a window to `100%` when its recorded reset time passes.
- Shows `--` until a valid snapshot is found.
- Runs without a Dock icon or application window.

## Build

```sh
swift test
./scripts/build-app.sh
open "build/Codex Status Bar.app"
```

The build script creates an ad-hoc signed app at:

```text
build/Codex Status Bar.app
```
