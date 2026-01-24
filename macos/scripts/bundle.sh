#!/bin/bash
set -e

# Configuration
APP_NAME="Receipt Sorter"
EXECUTABLE_NAME="ReceiptSorterApp"
BUNDLE_NAME="$APP_NAME.app"

# Navigate to project root (macos directory)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

echo "📍 Working in: $(pwd)"

# Clean previous build artifacts to ensure a fresh build
# echo "🧹 Cleaning..."
# rm -rf .build "$BUNDLE_NAME"

# Build using xcodebuild (required for Metal shader compilation)
# SwiftPM cannot compile Metal shaders, xcodebuild handles this
echo "🛠️  Building Binary (using xcodebuild for Metal shaders)..."
xcodebuild build \
    -scheme "$EXECUTABLE_NAME" \
    -configuration Release \
    -destination 'platform=macOS' \
    -derivedDataPath .build/xcode \
    -quiet

# Locate the binary built by xcodebuild
echo "🔍 Locating binary..."

# Xcodebuild outputs to DerivedData structure
BIN_PATH=".build/xcode/Build/Products/Release/$EXECUTABLE_NAME"

if [ ! -f "$BIN_PATH" ]; then
    # Fallback: search in DerivedData
    BIN_PATH=$(find .build/xcode -name "$EXECUTABLE_NAME" -type f ! -path "*Intermediates*" -path "*Release*" | head -n 1)
fi

if [ -z "$BIN_PATH" ] || [ ! -f "$BIN_PATH" ]; then
    echo "❌ Error: Could not find compiled binary '$EXECUTABLE_NAME'."
    exit 1
fi

echo "✅ Found binary at: $BIN_PATH"

# Create Bundle Structure
echo "📦 Creating App Bundle Structure..."
rm -rf "$BUNDLE_NAME"
mkdir -p "$BUNDLE_NAME/Contents/MacOS"
mkdir -p "$BUNDLE_NAME/Contents/Resources"

# Copy Binary
echo "dg Copying Binary..."
cp "$BIN_PATH" "$BUNDLE_NAME/Contents/MacOS/$EXECUTABLE_NAME"

# Copy Resources
echo "📄 Copying Info.plist..."
if [ -f "Sources/$EXECUTABLE_NAME/Info.plist" ]; then
    cp "Sources/$EXECUTABLE_NAME/Info.plist" "$BUNDLE_NAME/Contents/Info.plist"
else
    echo "⚠️  Warning: Info.plist not found in Sources/$EXECUTABLE_NAME/"
fi

echo "🖼️  Copying App Icon..."
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$BUNDLE_NAME/Contents/Resources/AppIcon.icns"
else
    echo "⚠️  Warning: AppIcon.icns not found in Resources/"
fi

# Copy SwiftPM resource bundles (including MLX metallib)
echo "📦 Copying Resource Bundles (MLX Metal shaders)..."
XCODE_PRODUCTS=".build/xcode/Build/Products/Release"

# Copy all .bundle directories to Resources
for bundle in "$XCODE_PRODUCTS"/*.bundle; do
    if [ -d "$bundle" ]; then
        bundle_name=$(basename "$bundle")
        echo "   📦 Copying $bundle_name..."
        cp -R "$bundle" "$BUNDLE_NAME/Contents/Resources/"
    fi
done

# Set Executable Name in Info.plist (ensure it matches)
if [ -f "$BUNDLE_NAME/Contents/Info.plist" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $EXECUTABLE_NAME" "$BUNDLE_NAME/Contents/Info.plist"
fi

# Code Signing
ENTITLEMENTS_PATH="Sources/$EXECUTABLE_NAME/$EXECUTABLE_NAME.entitlements"
SIGNING_IDENTITY="${CODE_SIGN_IDENTITY:-"-"}" # Default to ad-hoc ("-") if not set

echo "✍️  Signing Bundle with identity: '$SIGNING_IDENTITY'..."

if [ -f "$ENTITLEMENTS_PATH" ]; then
    echo "📜 Applying Entitlements from $ENTITLEMENTS_PATH..."
    codesign --force --deep --options runtime --entitlements "$ENTITLEMENTS_PATH" --sign "$SIGNING_IDENTITY" "$BUNDLE_NAME"
else
    echo "⚠️  Warning: Entitlements file not found at $ENTITLEMENTS_PATH"
    codesign --force --deep --options runtime --sign "$SIGNING_IDENTITY" "$BUNDLE_NAME"
fi

echo "✅ Bundle created: $(pwd)/$BUNDLE_NAME"
# Verify signature
echo "🔍 Verifying signature..."
codesign --verify --verbose "$BUNDLE_NAME"
