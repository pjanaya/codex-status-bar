#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP_NAME="Codex Status Bar.app"
SOURCE_APP="$ROOT_DIR/build/$APP_NAME"
INSTALL_DIR="$HOME/Applications"
INSTALLED_APP="$INSTALL_DIR/$APP_NAME"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
LAUNCH_AGENT="$LAUNCH_AGENTS_DIR/com.pjanaya.codex-status-bar.plist"
LAUNCH_DOMAIN="gui/$(id -u)"
LAUNCH_LABEL="com.pjanaya.codex-status-bar"

if [ ! -d "$SOURCE_APP" ]; then
    printf 'Build the app first with ./scripts/build-app.sh\n' >&2
    exit 1
fi

launchctl bootout "$LAUNCH_DOMAIN/$LAUNCH_LABEL" 2>/dev/null || true
pkill -x CodexStatusBar 2>/dev/null || true
sleep 1

mkdir -p "$INSTALL_DIR" "$LAUNCH_AGENTS_DIR"
rm -rf "$INSTALLED_APP"
cp -R "$SOURCE_APP" "$INSTALLED_APP"

sed "s|HOME_PLACEHOLDER|$HOME|g" \
    "$ROOT_DIR/Support/com.pjanaya.codex-status-bar.plist" \
    > "$LAUNCH_AGENT"

launchctl bootstrap "$LAUNCH_DOMAIN" "$LAUNCH_AGENT"
launchctl enable "$LAUNCH_DOMAIN/$LAUNCH_LABEL"
launchctl kickstart "$LAUNCH_DOMAIN/$LAUNCH_LABEL"

printf 'Installed %s\n' "$INSTALLED_APP"
printf 'Enabled launch at login with %s\n' "$LAUNCH_AGENT"
