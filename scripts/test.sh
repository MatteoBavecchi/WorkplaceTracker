#!/bin/bash
# Runs `swift test`. With only the Command Line Tools (no Xcode) SwiftPM cannot find
# the swift-testing framework on its own, so point it there explicitly.
set -euo pipefail
cd "$(dirname "$0")/.."

DEV="$(xcode-select -p)/Library/Developer"
if [[ "$(xcode-select -p)" == *CommandLineTools* ]]; then
    exec swift test \
        -Xswiftc -F -Xswiftc "$DEV/Frameworks" \
        -Xlinker -rpath -Xlinker "$DEV/Frameworks" \
        -Xlinker -rpath -Xlinker "$DEV/usr/lib" "$@"
fi
exec swift test "$@"
