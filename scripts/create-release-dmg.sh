#!/bin/bash
# Adapted from FloralMD by Yingkai Sun for UlulaWake.
# Create the DMG once from the already-signed and stapled app.

set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "usage: $0 <UlulaWake.app> <output.dmg>" >&2
    exit 2
fi

APP="$1"
DMG="$2"
[ -d "$APP" ] || { echo "Error: app bundle does not exist." >&2; exit 1; }

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/ululawake-dmg.XXXXXX")"
cleanup() {
    rm -rf "$STAGE"
}
trap cleanup EXIT

ditto "$APP" "${STAGE}/UlulaWake.app"
ln -s /Applications "${STAGE}/Applications"
mkdir -p "$(dirname "$DMG")"
rm -f "$DMG"
hdiutil create \
    -volname UlulaWake \
    -srcfolder "$STAGE" \
    -ov \
    -format UDZO \
    "$DMG" >/dev/null
