#!/bin/bash
# Builds a Release Orbit.app and packages it as dist/Orbit.dmg.
#
# Release (signed with Developer ID and notarized, opens without warnings):
#   DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" \
#   NOTARY_PROFILE=orbit-notary scripts/package.sh
#
# Without DEVELOPER_ID the app is signed for development only, and recipients
# must approve it once in System Settings › Privacy & Security. AD_HOC=1 signs
# ad hoc instead, for machines without a signing certificate (CI).
#
# APP_VERSION and BUILD_NUMBER override the version in the Xcode project.
# NOTARY_KEYCHAIN points notarytool at a keychain other than the login one
# (CI stores its credentials in a temporary keychain).
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
elif [[ -n "${AD_HOC:-}" ]]; then
    signing_args=(CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=)
fi

version_args=()
[[ -n "${APP_VERSION:-}" ]] && version_args+=("MARKETING_VERSION=$APP_VERSION")
[[ -n "${BUILD_NUMBER:-}" ]] && version_args+=("CURRENT_PROJECT_VERSION=$BUILD_NUMBER")

# The bundled mkcert is arm64-only, so the app is built for Apple silicon.
echo "Building Orbit.app…"
xcodebuild -project Orbit.xcodeproj -scheme Orbit -configuration Release \
    -derivedDataPath "$BUILD_DIR" ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
    ${signing_args[@]+"${signing_args[@]}"} ${version_args[@]+"${version_args[@]}"} clean build | grep -E "error:|BUILD" || true
[[ -d "$APP" ]] || { echo "Build failed." >&2; exit 1; }
codesign --verify --deep --strict "$APP"

echo "Creating disk image…"
staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
cp -R "$APP" "$staging/"
ln -s /Applications "$staging/Applications"
mkdir -p "$DIST_DIR"
rm -f "$DMG"
# hdiutil sometimes fails with "Resource busy" while macOS is still scanning
# the freshly built app (common on CI runners), so try a few times.
for attempt in 1 2 3 4 5; do
    if hdiutil create -volname Orbit -srcfolder "$staging" -fs HFS+ -format UDZO "$DMG" > /dev/null; then
        break
    fi
    if [[ $attempt == 5 ]]; then
        echo "Creating the disk image failed." >&2
        exit 1
    fi
    echo "hdiutil failed (attempt $attempt), retrying…" >&2
    rm -f "$DMG"
    sleep $((attempt * 5))
done

if [[ -n "${DEVELOPER_ID:-}" ]]; then
    codesign --sign "$DEVELOPER_ID" --timestamp "$DMG"
fi

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    notary_args=(--keychain-profile "$NOTARY_PROFILE")
    [[ -n "${NOTARY_KEYCHAIN:-}" ]] && notary_args+=(--keychain "$NOTARY_KEYCHAIN")

    echo "Notarizing (usually a few minutes)…"
    result=$(xcrun notarytool submit "$DMG" "${notary_args[@]}" --wait --output-format json)
    status=$(plutil -extract status raw - <<< "$result")
    if [[ "$status" != "Accepted" ]]; then
        echo "Notarization failed ($status):" >&2
        xcrun notarytool log "$(plutil -extract id raw - <<< "$result")" "${notary_args[@]}" >&2
        exit 1
    fi
    xcrun stapler staple "$DMG"
    spctl --assess --type open --context context:primary-signature -vv "$DMG"
fi

echo "Packaged $DMG ($(du -h "$DMG" | cut -f1))"
