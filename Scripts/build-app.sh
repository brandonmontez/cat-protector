#!/usr/bin/env bash
# Builds Cat Protector.app into ./build using Swift Package Manager.
#
# Usage:
#   Scripts/build-app.sh            # release build for this Mac's architecture
#   UNIVERSAL=1 Scripts/build-app.sh  # universal (Apple silicon + Intel) build
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Cat Protector"
EXECUTABLE="CatProtector"
BUNDLE_ID="com.catprotector.CatProtector"
BUILD_DIR="build"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"

echo "==> Compiling (release)..."
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  swift build -c release --arch arm64 --arch x86_64
  BIN_DIR=".build/apple/Products/Release"
else
  swift build -c release
  BIN_DIR=".build/release"
fi

echo "==> Assembling ${APP_DIR}..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
cp "${BIN_DIR}/${EXECUTABLE}" "${APP_DIR}/Contents/MacOS/${EXECUTABLE}"
cp Resources/Info.plist "${APP_DIR}/Contents/Info.plist"
printf 'APPL????' > "${APP_DIR}/Contents/PkgInfo"

if [[ -f Resources/AppIcon.icns ]]; then
  cp Resources/AppIcon.icns "${APP_DIR}/Contents/Resources/AppIcon.icns"
else
  echo "  (no Resources/AppIcon.icns found; run 'make icon' to generate one)"
fi

# Ad-hoc signing gives the app a stable identity so macOS remembers the
# Accessibility permission across rebuilds.
echo "==> Signing (ad hoc)..."
codesign --force --sign - --identifier "${BUNDLE_ID}" "${APP_DIR}"

echo "==> Built ${APP_DIR}"
