#!/bin/bash
# Generate Android app icons from SVG
# Usage: ./scripts/generate_icons.sh [svg_file]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default SVG file
SVG_FILE="${1:-$PROJECT_ROOT/assets/icon/app_icon_pure.svg}"
RES_DIR="$PROJECT_ROOT/android/app/src/main/res"

echo -e "${CYAN}=== Android Icon Generator ===${NC}"
echo "SVG source: $SVG_FILE"
echo "Output dir: $RES_DIR"
echo ""

# Check if SVG file exists
if [ ! -f "$SVG_FILE" ]; then
    echo -e "${RED}Error: SVG file not found: $SVG_FILE${NC}"
    exit 1
fi

# Check for rsvg-convert
if ! command -v rsvg-convert &> /dev/null; then
    echo -e "${RED}Error: rsvg-convert not found. Install librsvg:${NC}"
    echo "  Arch/Manjaro: sudo pacman -S librsvg"
    echo "  Ubuntu/Debian: sudo apt install librsvg2-bin"
    echo "  macOS: brew install librsvg"
    exit 1
fi

# Create mipmap directories
mkdir -p "$RES_DIR/mipmap-mdpi"
mkdir -p "$RES_DIR/mipmap-hdpi"
mkdir -p "$RES_DIR/mipmap-xhdpi"
mkdir -p "$RES_DIR/mipmap-xxhdpi"
mkdir -p "$RES_DIR/mipmap-xxxhdpi"

# Remove adaptive icon directory if exists (it causes cropping issues with full icons)
if [ -d "$RES_DIR/mipmap-anydpi-v26" ]; then
    echo -e "${YELLOW}Removing adaptive icon directory (prevents cropping)...${NC}"
    rm -rf "$RES_DIR/mipmap-anydpi-v26"
fi

echo -e "${GREEN}Generating launcher icons...${NC}"

# Standard launcher icons
# These are displayed as-is without cropping
rsvg-convert -w 48 -h 48 "$SVG_FILE" -o "$RES_DIR/mipmap-mdpi/ic_launcher.png"
echo "  ✓ mdpi    48x48"

rsvg-convert -w 72 -h 72 "$SVG_FILE" -o "$RES_DIR/mipmap-hdpi/ic_launcher.png"
echo "  ✓ hdpi    72x72"

rsvg-convert -w 96 -h 96 "$SVG_FILE" -o "$RES_DIR/mipmap-xhdpi/ic_launcher.png"
echo "  ✓ xhdpi   96x96"

rsvg-convert -w 144 -h 144 "$SVG_FILE" -o "$RES_DIR/mipmap-xxhdpi/ic_launcher.png"
echo "  ✓ xxhdpi  144x144"

rsvg-convert -w 192 -h 192 "$SVG_FILE" -o "$RES_DIR/mipmap-xxxhdpi/ic_launcher.png"
echo "  ✓ xxxhdpi 192x192"

# Also generate a high-res version for Play Store (512x512)
ICON_DIR="$PROJECT_ROOT/assets/icon"
mkdir -p "$ICON_DIR"
rsvg-convert -w 512 -h 512 "$SVG_FILE" -o "$ICON_DIR/playstore_icon.png"
echo "  ✓ Play Store 512x512"

echo ""
echo -e "${GREEN}=== Done! ===${NC}"
echo ""
echo "Generated icons:"
for f in "$RES_DIR"/mipmap-*/ic_launcher.png; do
    size=$(identify -format "%wx%h" "$f" 2>/dev/null || echo "?x?")
    bytes=$(stat -c%s "$f" 2>/dev/null || stat -f%z "$f" 2>/dev/null || echo "?")
    echo "  $(basename $(dirname $f))/ic_launcher.png  ${size}  ${bytes} bytes"
done
echo "  assets/icon/playstore_icon.png  512x512"

echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  flutter clean && flutter build apk"
