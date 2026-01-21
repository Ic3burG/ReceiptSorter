#!/bin/bash
set -e

# Configuration
APP_PATH="$1"

if [ -z "$APP_PATH" ]; then
    echo "❌ Error: Usage: ./notarize.sh <path-to-app-or-zip>"
    exit 1
fi

echo "🛡️  Starting Notarization for: $APP_PATH"

# Check if required environment variables are set
if [ -z "$MACOS_NOTARIZATION_KEY_ID" ] || [ -z "$MACOS_NOTARIZATION_ISSUER_ID" ] || [ -z "$MACOS_NOTARIZATION_PRIVATE_KEY" ]; then
    echo "⚠️  Skipping Notarization: Missing credentials (MACOS_NOTARIZATION_KEY_ID, MACOS_NOTARIZATION_ISSUER_ID, MACOS_NOTARIZATION_PRIVATE_KEY)"
    exit 0
fi

# Create a temporary file for the private key
KEY_FILE="auth_key.p8"
echo "$MACOS_NOTARIZATION_PRIVATE_KEY" > "$KEY_FILE"

# Submit for Notarization using notarytool (Xcode 13+)
echo "📤 Submitting to Apple Notary Service..."

SUBMISSION_FILE="$APP_PATH"
IS_TEMP_ZIP=false

if [ -d "$APP_PATH" ]; then
    echo "📦 Zipping '$APP_PATH' for notarization..."
    SUBMISSION_FILE="${APP_PATH}.zip"
    /usr/bin/zip -r -y "$SUBMISSION_FILE" "$APP_PATH" > /dev/null
    IS_TEMP_ZIP=true
fi

xcrun notarytool submit "$SUBMISSION_FILE" \
    --key-id "$MACOS_NOTARIZATION_KEY_ID" \
    --issuer "$MACOS_NOTARIZATION_ISSUER_ID" \
    --key "$KEY_FILE" \
    --wait

if [ "$IS_TEMP_ZIP" = true ]; then
    rm "$SUBMISSION_FILE"
fi

echo "✅ Notarization submission successful."

# Cleanup
rm "$KEY_FILE"

# If it's an .app bundle, staple the ticket
if [[ "$APP_PATH" == *.app ]]; then
    echo "stapling ticket..."
    xcrun stapler staple "$APP_PATH"
    echo "✅ Stapling complete."
fi
