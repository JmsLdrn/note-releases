#!/usr/bin/env bash
# Builds Note.app as a menu bar app and zips it the way the release expects.
# Usage: scripts/build-app.sh [version]
#
# Prefers a universal (Apple silicon + Intel) binary, which SwiftPM builds through
# xcbuild - and xcbuild ships only with full Xcode. With just the Command Line Tools
# installed it falls back to a native-architecture build, which is all you need to
# run Note on the machine doing the building.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Note"
BUNDLE_ID="com.jmsldrn.note"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found. Install the Xcode command line tools with: xcode-select --install" >&2
  exit 1
fi

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  VERSION="$(git -C "$ROOT" describe --tags --abbrev=0 2>/dev/null || echo "0.0.0")"
fi
VERSION="${VERSION#v}"

DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"
LOG="$DIST/build.log"
mkdir -p "$DIST"

BUILD_ARGS=(--package-path "$ROOT" -c release)
UNIVERSAL_ARGS=(--arch arm64 --arch x86_64)

echo "==> Building $APP_NAME $VERSION"
if swift build "${BUILD_ARGS[@]}" "${UNIVERSAL_ARGS[@]}" 2>&1 | tee "$LOG"; then
  ARCH_LABEL="universal"
  BIN_DIR="$(swift build "${BUILD_ARGS[@]}" "${UNIVERSAL_ARGS[@]}" --show-bin-path)"
elif grep -q "xcbuild" "$LOG"; then
  # Command Line Tools only - no xcbuild, so no universal binary. Build for this Mac.
  ARCH_LABEL="$(uname -m)"
  echo
  echo "==> Universal build needs full Xcode; building for $ARCH_LABEL only"
  swift build "${BUILD_ARGS[@]}"
  BIN_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
else
  echo "error: build failed - full output in $LOG" >&2
  exit 1
fi

ZIP="$DIST/$APP_NAME-$VERSION-macos-$ARCH_LABEL.zip"

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
echo "Arch: $(lipo -archs "$APP/Contents/MacOS/$APP_NAME" 2>/dev/null || echo "$ARCH_LABEL")"
echo "SHA-256: $(shasum -a 256 "$ZIP" | awk '{print $1}')"
