#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
GITHUB_PAGES_BASE="https://agnesfa.github.io/farm-tiles"

usage() {
    echo "Usage: $0 <geotiff-path> <paddock-name> <date> [variant]"
    echo ""
    echo "Arguments:"
    echo "  geotiff-path   Path to source GeoTIFF file"
    echo "  paddock-name   Lowercase kebab-case paddock name (e.g. p1, p1-p2)"
    echo "  date           ISO date YYYY-MM-DD (e.g. 2026-02-09)"
    echo "  variant        Optional: rgb, raw, or omit if only one export"
    echo ""
    echo "Example:"
    echo "  $0 ~/Desktop/ortho.tif p1-p2 2026-02-09 rgb"
    exit 1
}

if [[ $# -lt 3 || $# -gt 4 ]]; then
    usage
fi

GEOTIFF="$1"
PADDOCK="$2"
DATE="$3"
VARIANT="${4:-}"

# Validate GeoTIFF exists
if [[ ! -f "$GEOTIFF" ]]; then
    echo "Error: GeoTIFF not found: $GEOTIFF"
    exit 1
fi

# Validate paddock name (lowercase kebab-case)
if [[ ! "$PADDOCK" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    echo "Error: Paddock name must be lowercase kebab-case (e.g. p1, p1-p2)"
    exit 1
fi

# Validate date format
if [[ ! "$DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "Error: Date must be ISO format YYYY-MM-DD"
    exit 1
fi

# Validate variant if provided
if [[ -n "$VARIANT" && ! "$VARIANT" =~ ^(rgb|raw)$ ]]; then
    echo "Error: Variant must be 'rgb' or 'raw' (or omit)"
    exit 1
fi

# Build names
if [[ -n "$VARIANT" ]]; then
    FILENAME="${PADDOCK}-${DATE}-${VARIANT}.tif"
    TILE_DIR="tiles/${PADDOCK}/${DATE}-${VARIANT}"
else
    FILENAME="${PADDOCK}-${DATE}.tif"
    TILE_DIR="tiles/${PADDOCK}/${DATE}"
fi

SRC_DIR="src/${PADDOCK}/${DATE}"

echo "=== Tile Deploy ==="
echo "Source:  $GEOTIFF"
echo "Paddock: $PADDOCK"
echo "Date:    $DATE"
echo "Variant: ${VARIANT:-none}"
echo ""

# Validate GeoTIFF with gdalinfo
echo "--- Inspecting GeoTIFF ---"
if ! gdalinfo "$GEOTIFF" | head -20; then
    echo "Error: gdalinfo failed — file may not be a valid GeoTIFF"
    exit 1
fi
echo ""

# Copy source GeoTIFF
echo "--- Copying source to $SRC_DIR/$FILENAME ---"
mkdir -p "$REPO_DIR/$SRC_DIR"
cp "$GEOTIFF" "$REPO_DIR/$SRC_DIR/$FILENAME"
echo "Done."
echo ""

# Generate tiles
echo "--- Generating tiles (zoom 17-22) ---"
mkdir -p "$REPO_DIR/$TILE_DIR"
gdal2tiles.py \
    -z 17-22 \
    -w none \
    --xyz \
    --processes=4 \
    "$REPO_DIR/$SRC_DIR/$FILENAME" \
    "$REPO_DIR/$TILE_DIR"
echo "Done."
echo ""

# Commit and push
echo "--- Committing and pushing ---"
cd "$REPO_DIR"
git add "$TILE_DIR"
git commit -m "Add tiles: ${PADDOCK}/${DATE}${VARIANT:+-$VARIANT}"
git push
echo ""

# Print tile URL
TILE_URL="${GITHUB_PAGES_BASE}/${TILE_DIR}/{z}/{x}/{y}.png"
echo "=== Complete ==="
echo "Tile URL: $TILE_URL"
echo ""
echo "Use this URL in farmOS as an XYZ tile layer."
