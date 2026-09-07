#!/usr/bin/env bash
# Builds Note.app as a universal (Apple silicon + Intel) menu bar app and zips it
# the way the release expects. Usage: scripts/build-app.sh [version]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Note"
BUNDLE_ID="com.jmsldrn.note"

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  VERSION="$(git -C "$ROOT" describe --tags --abbrev=0 2>/dev/null || echo "0.0.0")"
fi
VERSION="${VERSION#v}"

DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"
ZIP="$DIST/$APP_NAME-$VERSION-macos-universal.zip"

echo "==> Building $APP_NAME $VERSION (universal)"
swift build --package-path "$ROOT" -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build --package-path "$ROOT" -c release --arch arm64 --arch x86_64 --show-bin-path)"

echo "==> Assembling bundle"
rm -rf "$APP" "$ZIP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
chmod +x "$APP/Contents/MacOS/$APP_NAME"
sed "s/__VERSION__/$VERSION/g" "$ROOT/Resources/Info.plist" > "$APP/Contents/Info.plist"

# Ad-hoc signature. The app is not notarised, so first launch still needs the
# right-click > Open dance documented in the README - but a stable signature keeps
# the Accessibility permission from being revoked on every rebuild.
echo "==> Signing (ad-hoc)"
codesign --force --sign - --identifier "$BUNDLE_ID" --timestamp=none "$APP"
codesign --verify --strict "$APP"

echo "==> Packaging"
ditto -c -k --keepParent "$APP" "$ZIP"

echo
echo "App: $APP"
echo "Zip: $ZIP"
echo "SHA-256: $(shasum -a 256 "$ZIP" | awk '{print $1}')"
