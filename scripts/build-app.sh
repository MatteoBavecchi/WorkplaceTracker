#!/bin/bash
# Builds build/WorkplaceTracker.app. With --install, copies it to ~/Applications and launches it.
set -euo pipefail
cd "$(dirname "$0")/.."

NAME=WorkplaceTracker
APP="build/$NAME.app"

swift build -c release --product "$NAME"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/$NAME" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
# Ad-hoc signature: enough for Location Services on your own Mac.
codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
    # Per-user Applications folder: no admin rights needed.
    DEST="$HOME/Applications/$NAME.app"
    pkill -x "$NAME" || true
    mkdir -p "$(dirname "$DEST")"
    rm -rf "$DEST"
    cp -R "$APP" "$DEST"
    open "$DEST"
    echo "Installed $DEST"
fi
