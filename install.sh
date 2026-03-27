#!/bin/bash
set -e

echo "Installing TermHub..."
echo ""

# Check for Xcode command line tools
if ! xcode-select -p &>/dev/null; then
    echo "Error: Xcode Command Line Tools are required."
    echo "Install them with: xcode-select --install"
    exit 1
fi

# Check for Swift
if ! command -v swift &>/dev/null; then
    echo "Error: Swift is not installed."
    echo "Install Xcode Command Line Tools: xcode-select --install"
    exit 1
fi

# Clone or update
REPO_URL="https://github.com/VictorGothensten/TermHub.git"
BUILD_DIR=$(mktemp -d)
INSTALL_DIR="/usr/local/bin"
APP_DIR="/Applications"

echo "Cloning TermHub..."
git clone --depth 1 "$REPO_URL" "$BUILD_DIR/TermHub"
cd "$BUILD_DIR/TermHub"

echo "Building (this may take a minute on first run)..."
swift build -c release 2>&1 | tail -5

# Create app bundle
echo "Creating app bundle..."
APP_BUNDLE="$APP_DIR/TermHub.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp .build/release/TermHub "$APP_BUNDLE/Contents/MacOS/TermHub"

# Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>TermHub</string>
    <key>CFBundleIdentifier</key>
    <string>com.victorgothensten.termhub</string>
    <key>CFBundleName</key>
    <string>TermHub</string>
    <key>CFBundleDisplayName</key>
    <string>TermHub</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <false/>
</dict>
</plist>
PLIST

# Also install CLI binary
if [ -w "$INSTALL_DIR" ]; then
    cp .build/release/TermHub "$INSTALL_DIR/termhub"
else
    sudo cp .build/release/TermHub "$INSTALL_DIR/termhub"
fi

# Cleanup
rm -rf "$BUILD_DIR"

echo ""
echo "TermHub installed successfully!"
echo ""
echo "  App:  $APP_BUNDLE (open from Spotlight or Finder)"
echo "  CLI:  termhub (run from any terminal)"
echo ""
echo "To uninstall:"
echo "  rm -rf /Applications/TermHub.app /usr/local/bin/termhub"
echo ""
