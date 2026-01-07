#!/bin/bash

# Exit on error
set -e

APP_NAME="Receipt Sorter"
EXECUTABLE_NAME="ReceiptSorterApp"
BUNDLE_NAME="$APP_NAME.app"
SOURCES_DIR="Sources/ReceiptSorterApp"

echo "🚀 Starting Build for $APP_NAME..."

# Ensure we are in the macos directory
if [ -f "Package.swift" ]; then
    echo "✅ Found Package.swift"
else
    if [ -d "macos" ]; then
        cd macos
        echo "📂 Changed directory to macos/"
    else
        echo "❌ Error: Could not find Package.swift or macos directory."
        exit 1
    fi
fi

# 1. Clean previous build (optional, good for release)
# swift package clean

# 2. Build Release Binary
echo "🛠️  Compiling Swift sources (Release)..."
swift build -c release --product "$EXECUTABLE_NAME" --arch arm64 --arch x86_64

# Define Build Path (Binaries location)
BUILD_PATH=".build/apple/Products/Release"
if [ ! -d "$BUILD_PATH" ]; then
    # Fallback for older Swift versions or different layouts
    BUILD_PATH=".build/release"
fi

# 3. Create .app Bundle Structure
echo "📦 Creating App Bundle..."
rm -rf "$BUNDLE_NAME"
mkdir -p "$BUNDLE_NAME/Contents/MacOS"
mkdir -p "$BUNDLE_NAME/Contents/Resources"

# 4. Copy Assets
echo "📄 Copying Info.plist..."
if [ -f "$SOURCES_DIR/Info.plist" ]; then
    cp "$SOURCES_DIR/Info.plist" "$BUNDLE_NAME/Contents/Info.plist"
else
    echo "⚠️  Warning: Info.plist not found at $SOURCES_DIR/Info.plist"
fi

echo "🖼️  Copying App Icon..."
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$BUNDLE_NAME/Contents/Resources/AppIcon.icns"
else
    echo "⚠️  Warning: AppIcon.icns not found in Resources/"
fi

# 5. Copy Binary
echo "💿 Copying Executable..."
cp "$BUILD_PATH/$EXECUTABLE_NAME" "$BUNDLE_NAME/Contents/MacOS/$EXECUTABLE_NAME"

# Update Info.plist executable name if it differs (safety check)
# PlistBuddy is a built-in Mac tool for editing plists
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $EXECUTABLE_NAME" "$BUNDLE_NAME/Contents/Info.plist"

# 6. Ad-hoc Code Signing
echo "✍️  Signing Application..."
if [ -f "$SOURCES_DIR/ReceiptSorterApp.entitlements" ]; then
    echo "   Using entitlements..."
    codesign --force --deep --sign - --entitlements "$SOURCES_DIR/ReceiptSorterApp.entitlements" "$BUNDLE_NAME"
else
    echo "   No entitlements found (Network access might fail)..."
    codesign --force --deep --sign - "$BUNDLE_NAME"
fi

echo ""
echo "✅ Build Complete!"
echo "👉 Application is ready at: $(pwd)/$BUNDLE_NAME"

echo ""
echo "To run it, type: open \"$BUNDLE_NAME\""