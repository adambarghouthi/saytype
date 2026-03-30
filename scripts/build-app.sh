#!/bin/bash
set -euo pipefail

VERSION="${1:-1.0.0}"
APP="dist/SayType.app"
BUILD_DIR=".build/release"

echo "=== Building SayType v${VERSION} ==="

# Build release binary
# Use Homebrew Swift toolchain if available (local workaround for broken CLT),
# otherwise fall back to system swift (CI runners)
if [ -n "${TOOLCHAINS:-}" ] && command -v /opt/homebrew/opt/swift/bin/swift &> /dev/null; then
    TOOLCHAINS="$TOOLCHAINS" /opt/homebrew/opt/swift/bin/swift build -c release 2>&1
else
    swift build -c release 2>&1
fi

BINARY="$BUILD_DIR/SayType"
if [ ! -f "$BINARY" ]; then
    echo "ERROR: Binary not found at $BINARY"
    exit 1
fi

# Create .app bundle
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

# Copy binary
cp "$BINARY" "$APP/Contents/MacOS/SayType"

# Copy app icon
cp Sources/SayType/Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Create Info.plist with version
cat > "$APP/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>SayType</string>
    <key>CFBundleDisplayName</key>
    <string>SayType</string>
    <key>CFBundleIdentifier</key>
    <string>com.saytype.app</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleExecutable</key>
    <string>SayType</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>SayType needs microphone access to transcribe your speech.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
PLIST

# Sign with hardened runtime
codesign --force --deep --options runtime --sign - \
    --entitlements Sources/SayType/Resources/SayType.entitlements \
    "$APP"

echo "=== Built $APP ($(du -sh "$APP" | cut -f1)) ==="
