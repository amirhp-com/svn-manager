#!/usr/bin/env bash
# Builds SVN Manager.app, generates the icon, and packages a DMG installer.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

APP_NAME="SVN Manager"
EXEC_NAME="SVNManager"
BUNDLE_ID="com.amirhp.svnmanager"
VERSION="1.1.0"
BUILD_NUMBER="2"

BUILD_DIR="build"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
DMG_PATH="${BUILD_DIR}/${APP_NAME// /-}-${VERSION}.dmg"

echo "==> Cleaning"
rm -rf "${BUILD_DIR}/${APP_NAME}.app" "${BUILD_DIR}/AppIcon.iconset" \
       "${BUILD_DIR}/AppIcon.icns" "${BUILD_DIR}/dmg-staging" "${DMG_PATH}"
mkdir -p "${BUILD_DIR}"

echo "==> Generating app icon"
swift tools/make_icon.swift

echo "==> Compiling release binary"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/${EXEC_NAME}"
if [[ ! -f "${BIN_PATH}" ]]; then
  echo "Binary not found at ${BIN_PATH}" >&2
  exit 1
fi

echo "==> Assembling .app bundle"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${BIN_PATH}"               "${APP_DIR}/Contents/MacOS/${EXEC_NAME}"
cp "${BUILD_DIR}/AppIcon.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"

cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>            <string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key>     <string>${APP_NAME}</string>
  <key>CFBundleExecutable</key>      <string>${EXEC_NAME}</string>
  <key>CFBundleIdentifier</key>      <string>${BUNDLE_ID}</string>
  <key>CFBundleIconFile</key>        <string>AppIcon</string>
  <key>CFBundleVersion</key>         <string>${BUILD_NUMBER}</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundlePackageType</key>     <string>APPL</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>LSMinimumSystemVersion</key>  <string>13.0</string>
  <key>NSHighResolutionCapable</key> <true/>
  <key>NSPrincipalClass</key>        <string>NSApplication</string>
  <key>NSHumanReadableCopyright</key><string>© 2026- amirhp.com</string>
</dict>
</plist>
PLIST

chmod +x "${APP_DIR}/Contents/MacOS/${EXEC_NAME}"

echo "==> Creating DMG installer"
STAGE="${BUILD_DIR}/dmg-staging"
mkdir -p "${STAGE}"
cp -R "${APP_DIR}" "${STAGE}/"
ln -s /Applications "${STAGE}/Applications"

hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${STAGE}" \
  -ov -format UDZO \
  "${DMG_PATH}" >/dev/null

rm -rf "${STAGE}"

echo ""
echo "✓ App:       ${APP_DIR}"
echo "✓ Installer: ${DMG_PATH}"
