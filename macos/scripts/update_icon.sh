#!/bin/bash
set -e

# Check if input image is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <path_to_source_image_png>"
    exit 1
fi

SOURCE_IMG="$1"
ICONSET_DIR="AppIcon.iconset"
OUTPUT_ICNS="../Resources/AppIcon.icns"

# Navigate to script directory
cd "$(dirname "$0")"

echo "📂 Creating iconset directory..."
mkdir -p "$ICONSET_DIR"

# Resize images
echo "📐 Resizing images..."

# Helper function to resize
resize() {
    SIZE=$1
    SCALE=$2
    FILENAME="icon_${SIZE}x${SIZE}"
    if [ "$SCALE" == "2x" ]; then
        FILENAME="${FILENAME}@2x.png"
        PIXEL_SIZE=$((SIZE * 2))
    else
        FILENAME="${FILENAME}.png"
        PIXEL_SIZE=$SIZE
    fi
    
    sips -z "$PIXEL_SIZE" "$PIXEL_SIZE" --setProperty format png "$SOURCE_IMG" --out "$ICONSET_DIR/$FILENAME" > /dev/null
}

resize 16 1x
resize 16 2x
resize 32 1x
resize 32 2x
resize 128 1x
resize 128 2x
resize 256 1x
resize 256 2x
resize 512 1x
resize 512 2x

echo "🔄 Converting to .icns..."
iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICNS"

echo "🧹 Cleaning up..."
rm -rf "$ICONSET_DIR"

echo "✅ AppIcon.icns updated at $OUTPUT_ICNS"
