# Codex Status Bar

A tiny, local-only macOS menu-bar indicator for Codex usage limits:

```text
95% 14:25
62% 07/06
```

- First line: five-hour allowance remaining and its reset time.
- Second line: weekly allowance remaining and its reset date.

The percentages switch to `100%` when their recorded reset times pass, even if
Codex is closed.

## Requirements

- macOS 13 or newer.
- Xcode Command Line Tools or Xcode.
- Codex installed and used at least once.

Install the command-line tools if needed:

```sh
xcode-select --install
```

## Build

Clone the repository and enter its directory:

```sh
git clone https://github.com/pjanaya/codex-status-bar.git
cd codex-status-bar
```

Run the tests and build the release app:

```sh
swift test
./scripts/build-app.sh
```

The build script creates and ad hoc signs:

```text
build/Codex Status Bar.app
```

## Install

Copy the built app into your personal Applications folder:

```sh
./scripts/install.sh
```

Using `~/Applications` avoids requiring administrator access. You can instead
drag the app into the system `/Applications` folder in Finder, but the install
script also configures the `~/Applications` copy to launch automatically when
you log in.

If macOS blocks the first launch, open **System Settings > Privacy & Security**
and choose **Open Anyway** for Codex Status Bar. The app is locally ad-hoc
signed, not notarized for public distribution.

## Update

Pull the latest changes, rebuild, quit the running app, and replace it:

```sh
git pull
swift test
./scripts/build-app.sh
./scripts/install.sh
```

## Uninstall

Quit the app from its menu, remove it from Login Items if enabled, then delete
the bundle:

```sh
launchctl bootout "gui/$(id -u)/com.pjanaya.codex-status-bar" || true
rm -f "$HOME/Library/LaunchAgents/com.pjanaya.codex-status-bar.plist"
rm -rf "$HOME/Applications/Codex Status Bar.app"
```

## Behavior

- Refreshes once per minute and when **Refresh** is selected.
- Reads only the tail of recently modified JSONL files.
- Selects the newest embedded rate-limit event across concurrent Codex sessions.
- Switches a window to `100%` when its recorded reset time passes.
- Shows `--` until a valid snapshot is found.
- Runs without a Dock icon or application window.

## Privacy

The app has no networking code and does not read Codex credentials. It reads
rate-limit snapshots from JSONL files in:

```text
~/.codex/sessions
```

The JSONL format is an internal Codex detail and could change in a future Codex
release.
