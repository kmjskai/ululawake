#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate
xcodebuild -project UlulaWake.xcodeproj -scheme UlulaWake \
  -configuration Release -derivedDataPath build -destination 'generic/platform=macOS' \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build
APP=build/Build/Products/Release/UlulaWake.app
plutil -lint "$APP/Contents/Info.plist"
lipo "$APP/Contents/MacOS/UlulaWake" -verify_arch arm64 x86_64
test ! -d "$APP/Contents/PlugIns"
test -f "$APP/Contents/Resources/AppIcon.icns"
