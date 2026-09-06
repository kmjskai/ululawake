#!/bin/sh
# UlulaWake 一键构建
set -e
cd "$(dirname "$0")"

echo "==> xcodegen generate"
xcodegen generate

echo "==> xcodebuild"
xcodebuild \
  -project UlulaWake.xcodeproj \
  -scheme UlulaWake \
  -configuration Debug \
  -derivedDataPath build \
  -allowProvisioningUpdates \
  build

echo "✅ 构建完成: build/Build/Products/Debug/UlulaWake.app"
