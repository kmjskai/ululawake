#!/bin/bash
# Adapted from FloralMD by Yingkai Sun for UlulaWake.
# Build the one-way Developer ID -> notarized app -> final DMG byte chain.
#
# Secrets are accepted only through environment variables. This script never
# enables shell tracing and never prints certificate, account, or key values.

set -euo pipefail

REQUIRED_SECRETS=(
    MACOS_CERTIFICATE_P12_BASE64
    MACOS_CERTIFICATE_PASSWORD
    APPLE_NOTARY_KEY_P8_BASE64
    APPLE_NOTARY_KEY_ID
    APPLE_NOTARY_ISSUER_ID
)

check_secrets() {
    local missing=0
    local name
    for name in "${REQUIRED_SECRETS[@]}"; do
        if [ -z "${!name:-}" ]; then
            echo "Error: required release secret ${name} is missing." >&2
            missing=1
        fi
    done
    [ "$missing" -eq 0 ]
}

if [ "${1:-}" = "--check-secrets" ]; then
    check_secrets
    exit
fi

if [ "$#" -ne 2 ]; then
    echo "usage: $0 <UlulaWake.app> <output.dmg>" >&2
    exit 2
fi

check_secrets
APP="$1"
DMG="$2"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${APP}/Contents/Info.plist")"
ASSET_NAME="UlulaWake-${VERSION}.dmg"
[ "$(basename "$DMG")" = "$ASSET_NAME" ] || {
    echo "Error: output DMG must be named ${ASSET_NAME}." >&2
    exit 1
}

WORK="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/ululawake-signing.XXXXXX")"
KEYCHAIN="${WORK}/release.keychain-db"
KEYCHAIN_PASSWORD="$(openssl rand -hex 32)"
P12="${WORK}/developer-id.p12"
NOTARY_KEY="${WORK}/AuthKey.p8"

# codesign needs the imported identity in the user keychain search list as well
# as an explicit --keychain path. Restore the original state on every exit.
ORIGINAL_KEYCHAINS=()
while IFS= read -r path; do
    ORIGINAL_KEYCHAINS+=("$path")
done < <(security list-keychains -d user | python3 -c 'import shlex,sys; print("\n".join(shlex.split(sys.stdin.read())))')
ORIGINAL_DEFAULT="$(security default-keychain -d user | python3 -c 'import shlex,sys; print(shlex.split(sys.stdin.read())[0])')"

cleanup() {
    security default-keychain -d user -s "$ORIGINAL_DEFAULT" >/dev/null 2>&1 || true
    security list-keychains -d user -s "${ORIGINAL_KEYCHAINS[@]}" >/dev/null 2>&1 || true
    security delete-keychain "$KEYCHAIN" >/dev/null 2>&1 || true
    rm -rf "$WORK"
}
trap cleanup EXIT

printf '%s' "$MACOS_CERTIFICATE_P12_BASE64" | base64 -D >"$P12"
printf '%s' "$APPLE_NOTARY_KEY_P8_BASE64" | base64 -D >"$NOTARY_KEY"
chmod 600 "$P12" "$NOTARY_KEY"

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security list-keychains -d user -s "$KEYCHAIN" "${ORIGINAL_KEYCHAINS[@]}"
security default-keychain -d user -s "$KEYCHAIN"
security import "$P12" \
    -k "$KEYCHAIN" \
    -P "$MACOS_CERTIFICATE_PASSWORD" \
    -T /usr/bin/codesign >/dev/null
security set-key-partition-list \
    -S apple-tool:,apple: \
    -s \
    -k "$KEYCHAIN_PASSWORD" \
    "$KEYCHAIN" >/dev/null

IDENTITIES="$(
    security find-identity -v -p codesigning "$KEYCHAIN" |
        awk '/Developer ID Application:/{print $2}'
)"
IDENTITY_COUNT="$(printf '%s\n' "$IDENTITIES" | awk 'NF{count++} END{print count+0}')"
[ "$IDENTITY_COUNT" -eq 1 ] || {
    echo "Error: imported archive must contain exactly one Developer ID Application identity." >&2
    exit 1
}
IDENTITY="$(printf '%s\n' "$IDENTITIES" | awk 'NF{print; exit}')"

# The current app has no embedded extensions or third-party frameworks.
# Fail closed if a future release adds nested code that needs its own signing order.
[ ! -d "$APP/Contents/PlugIns" ] || { echo "Unexpected embedded extensions" >&2; exit 1; }
if [ -d "$APP/Contents/Frameworks" ]; then
    while IFS= read -r -d '' dylib; do
        codesign --force --sign "$IDENTITY" --keychain "$KEYCHAIN" --options runtime --timestamp "$dylib"
    done < <(find "$APP/Contents/Frameworks" -type f -name '*.dylib' -print0)
    if find "$APP/Contents/Frameworks" -type d -name '*.framework' | grep -q .; then
        echo "Unexpected embedded framework: add explicit nested signing before release." >&2
        exit 1
    fi
fi
codesign --force --sign "$IDENTITY" --keychain "$KEYCHAIN" --options runtime --timestamp \
    --entitlements UlulaWake/UlulaWake.entitlements "$APP"
./scripts/verify-release-artifact.sh signed-app "$APP"

notarize() {
    local artifact="$1"
    local label="$2"
    local submission="${WORK}/${label}-submission.json"
    local log="${WORK}/${label}-notary-log.json"
    local submission_id

    xcrun notarytool submit "$artifact" \
        --key "$NOTARY_KEY" \
        --key-id "$APPLE_NOTARY_KEY_ID" \
        --issuer "$APPLE_NOTARY_ISSUER_ID" \
        --wait --timeout 20m \
        --output-format json >"$submission"
    submission_id="$(
        python3 scripts/validate-developer-id-release.py \
            --submission "$submission" \
            --log <(printf '{"issues": []}') \
            --print-id
    )"
    xcrun notarytool log "$submission_id" \
        --key "$NOTARY_KEY" \
        --key-id "$APPLE_NOTARY_KEY_ID" \
        --issuer "$APPLE_NOTARY_ISSUER_ID" \
        "$log" >/dev/null
    SUMMARY="$(
        python3 scripts/validate-developer-id-release.py \
            --submission "$submission" \
            --log "$log"
    )"
    echo "${label} notarization: ${SUMMARY}"
    if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
        echo "- ${label} notarization: ${SUMMARY}" >>"$GITHUB_STEP_SUMMARY"
    fi
}

APP_ZIP="${WORK}/UlulaWake.zip"
ditto -c -k --keepParent "$APP" "$APP_ZIP"
notarize "$APP_ZIP" app
xcrun stapler staple "$APP" >/dev/null
./scripts/verify-release-artifact.sh notarized-app "$APP"

./scripts/create-release-dmg.sh "$APP" "$DMG"
codesign --force --sign "$IDENTITY" --keychain "$KEYCHAIN" --timestamp "$DMG"
notarize "$DMG" dmg
xcrun stapler staple "$DMG" >/dev/null

CHECKSUM="$(dirname "$DMG")/UlulaWake-${VERSION}.sha256"
(
    cd "$(dirname "$DMG")"
    shasum -a 256 "$(basename "$DMG")" >"$(basename "$CHECKSUM")"
)
./scripts/verify-release-artifact.sh final-dmg "$DMG" "$CHECKSUM"

echo "Developer ID release artifacts are ready."
