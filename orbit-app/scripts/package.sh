#!/bin/bash
# Builds a Release Orbit.app and packages it as dist/Orbit.dmg.
#
# Release (signed with Developer ID and notarized, opens without warnings):
#   DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" \
#   NOTARY_PROFILE=orbit-notary scripts/package.sh
#
# Without DEVELOPER_ID the app is signed for development only, and recipients
# must approve it once in System Settings › Privacy & Security.
set -euo pipefail

cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

BUILD_DIR=build
DIST_DIR=dist
APP="$BUILD_DIR/Build/Products/Release/Orbit.app"
DMG="$DIST_DIR/Orbit.dmg"

signing_args=()
if [[ -n "${DEVELOPER_ID:-}" ]]; then
    # The team ID is the parenthesized part of the identity name.
    team_id="${DEVELOPER_ID##*(}"
    team_id="${team_id%)}"
    signing_args=(
        CODE_SIGN_STYLE=Manual
        "CODE_SIGN_IDENTITY=$DEVELOPER_ID"
        "DEVELOPMENT_TEAM=$team_id"
        OTHER_CODE_SIGN_FLAGS=--timestamp
        # Xcode adds the debugging-only get-task-allow entitlement to plain
        # builds, and notarization rejects it.
        CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO
    )
elif [[ -n "${NOTARY_PROFILE:-}" ]]; then
    echo "NOTARY_PROFILE needs DEVELOPER_ID: only Developer ID builds can be notarized." >&2
    exit 1
fi

# The bundled mkcert is arm64-only, so the app is built for Apple silicon.
echo "Building Orbit.app…"
xcodebuild -project Orbit.xcodeproj -scheme Orbit -configuration Release \
    -derivedDataPath "$BUILD_DIR" ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
    ${signing_args[@]+"${signing_args[@]}"} clean build | grep -E "error:|BUILD" || true
[[ -d "$APP" ]] || { echo "Build failed." >&2; exit 1; }
codesign --verify --deep --strict "$APP"

echo "Creating disk image…"
staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
cp -R "$APP" "$staging/"
ln -s /Applications "$staging/Applications"
mkdir -p "$DIST_DIR"
rm -f "$DMG"
hdiutil create -quiet -volname Orbit -srcfolder "$staging" -fs HFS+ -format UDZO "$DMG"

if [[ -n "${DEVELOPER_ID:-}" ]]; then
    codesign --sign "$DEVELOPER_ID" --timestamp "$DMG"
fi

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    echo "Notarizing (usually a few minutes)…"
    result=$(xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json)
    status=$(plutil -extract status raw - <<< "$result")
    if [[ "$status" != "Accepted" ]]; then
        echo "Notarization failed ($status):" >&2
        xcrun notarytool log "$(plutil -extract id raw - <<< "$result")" --keychain-profile "$NOTARY_PROFILE" >&2
        exit 1
    fi
    xcrun stapler staple "$DMG"
    spctl --assess --type open --context context:primary-signature -vv "$DMG"
fi

echo "Packaged $DMG ($(du -h "$DMG" | cut -f1))"
