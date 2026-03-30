#!/bin/bash
set -euo pipefail

VERSION="${1:-1.0.0}"
APP_NAME="SayType"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Ensure Homebrew binaries are in PATH (CI runners may not have it)
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

echo "=== Building ${DMG_NAME} ==="

if [ ! -d "dist/${APP_NAME}.app" ]; then
    echo "ERROR: dist/${APP_NAME}.app not found. Run build-app.sh first."
    exit 1
fi

rm -f "${DMG_NAME}"

if command -v create-dmg &> /dev/null; then
    echo "Using create-dmg with background image"
    create-dmg \
        --volname "${APP_NAME}" \
        --background "${SCRIPT_DIR}/dmg-background.tiff" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "${APP_NAME}.app" 150 200 \
        --app-drop-link 450 200 \
        --no-internet-enable \
        "${DMG_NAME}" \
        "dist/${APP_NAME}.app"
else
    echo "WARN: create-dmg not found, using basic hdiutil (install with: brew install create-dmg)"
    rm -rf dmg-staging
    mkdir -p dmg-staging
    cp -R "dist/${APP_NAME}.app" dmg-staging/
    ln -s /Applications dmg-staging/Applications

    hdiutil create \
        -volname "${APP_NAME}" \
        -srcfolder dmg-staging \
        -ov \
        -format UDZO \
        "${DMG_NAME}"

    rm -rf dmg-staging
fi

echo "=== Created ${DMG_NAME} ==="
