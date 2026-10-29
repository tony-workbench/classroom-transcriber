#!/bin/bash
set -e
cd "$(dirname "$0")"
printf '\nPreparing local classroom transcription. This downloads Python packages.\n'
if [[ "$(uname -m)" != arm64 ]]; then echo 'Apple Silicon is required.'; exit 1; fi
PYTHON="$(command -v python3.12 || command -v python3)"
"$PYTHON" -c 'import sys; assert (3,10) <= sys.version_info[:2] <= (3,13), "Python 3.10–3.13 required"'
"$PYTHON" -m venv .venv
.venv/bin/python -m pip install -r requirements-lock.txt
mkdir -p '课堂转写.app/Contents/MacOS'
swiftc -swift-version 5 -O ClassroomApp.swift -o '课堂转写.app/Contents/MacOS/ClassroomApp'
cp Info.plist '课堂转写.app/Contents/Info.plist'
printf '\nApp built. Next follow README to download the models.\n'
read -r -p 'Press Return to close. ' _
