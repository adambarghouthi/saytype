#!/bin/bash
set -euo pipefail

VERSION="${1:-0.1.0}"
APP_NAME="SayType"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"

echo "=== Building ${DMG_NAME} ==="

# Check PyInstaller output exists
if [ ! -d "dist/${APP_NAME}.app" ]; then
    echo "ERROR: dist/${APP_NAME}.app not found. Run PyInstaller first."
    exit 1
fi

# Create DMG staging area
rm -rf dmg-staging
mkdir -p dmg-staging
cp -R "dist/${APP_NAME}.app" dmg-staging/
ln -s /Applications dmg-staging/Applications

# Create DMG
rm -f "${DMG_NAME}"
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder dmg-staging \
    -ov \
    -format UDZO \
    "${DMG_NAME}"

rm -rf dmg-staging
echo "=== Created ${DMG_NAME} ==="
