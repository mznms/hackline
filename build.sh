#!/bin/bash
#
# HackLine Font Build Script
# Usage: ./build.sh [--nerd]
#
# This script builds HackLine font with slashed zero from Hack source
# Uses uv for Python dependency management
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}HackLine Font Build Script${NC}"
echo -e "${GREEN}============================================================${NC}"

# Check uv is installed
echo -e "\n${YELLOW}[1/8] Checking dependencies...${NC}"
if ! command -v uv &> /dev/null; then
    echo -e "${RED}Error: uv is required${NC}"
    echo -e "Install uv: curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

# Setup virtual environment and install dependencies
echo "Setting up Python environment with uv..."
uv sync
echo -e "${GREEN}✓ Dependencies OK${NC}"

# Download Hack source (for building with slashed zero)
echo -e "\n${YELLOW}[2/8] Downloading Hack source...${NC}"
if [ ! -d "hack_source" ]; then
    echo "Downloading Hack source repository..."
    curl -L -o hack-source.zip https://github.com/source-foundry/Hack/archive/refs/tags/v3.003.zip
    unzip -o hack-source.zip -d hack_source_tmp
    mv hack_source_tmp/Hack-3.003 hack_source
    rm -rf hack_source_tmp hack-source.zip
    echo -e "${GREEN}✓ Hack source downloaded${NC}"
else
    echo -e "${GREEN}✓ Hack source already exists${NC}"
fi

# Download alt-hack slashed zero glyphs
echo -e "\n${YELLOW}[3/8] Downloading slashed zero glyphs from alt-hack...${NC}"
if [ ! -d "alt_hack_glyphs" ]; then
    mkdir -p alt_hack_glyphs
    # Download slashed zero glyphs for each style
    for style in regular bold italic bolditalic; do
        mkdir -p "alt_hack_glyphs/${style}"
        curl -L -o "alt_hack_glyphs/${style}/zero.glif" \
            "https://raw.githubusercontent.com/source-foundry/alt-hack/master/glyphs/u0030-forwardslash/${style}/zero.glif"
    done
    echo -e "${GREEN}✓ Slashed zero glyphs downloaded${NC}"
else
    echo -e "${GREEN}✓ Slashed zero glyphs already exist${NC}"
fi

# Apply slashed zero glyphs to Hack source
echo -e "\n${YELLOW}[4/8] Applying slashed zero glyphs...${NC}"
cp "alt_hack_glyphs/regular/zero.glif" "hack_source/source/Hack-Regular.ufo/glyphs/zero.glif"
cp "alt_hack_glyphs/bold/zero.glif" "hack_source/source/Hack-Bold.ufo/glyphs/zero.glif"
cp "alt_hack_glyphs/italic/zero.glif" "hack_source/source/Hack-Italic.ufo/glyphs/zero.glif"
cp "alt_hack_glyphs/bolditalic/zero.glif" "hack_source/source/Hack-BoldItalic.ufo/glyphs/zero.glif"
echo -e "${GREEN}✓ Slashed zero glyphs applied${NC}"

# Build Hack TTF with fontmake
echo -e "\n${YELLOW}[5/8] Building Hack TTF with slashed zero...${NC}"
mkdir -p hack_font/ttf
for style in Regular Bold; do
    echo "Building Hack-${style}..."
    uv run fontmake -u "hack_source/source/Hack-${style}.ufo" -o ttf --output-dir hack_font/ttf
done
echo -e "${GREEN}✓ Hack TTF built with slashed zero${NC}"

# Download LINE Seed JP font
echo -e "\n${YELLOW}[6/8] Downloading LINE Seed JP font...${NC}"
if [ ! -d "line_seed_font" ]; then
    curl -L -o LINE_Seed_JP.zip "https://seed.line.me/src/images/fonts/LINE_Seed_JP.zip"
    mkdir -p line_seed_font
    unzip -o LINE_Seed_JP.zip -d line_seed_font
    rm LINE_Seed_JP.zip
    echo -e "${GREEN}✓ LINE Seed JP font downloaded${NC}"
else
    echo -e "${GREEN}✓ LINE Seed JP font already exists${NC}"
fi

# Build HackLine fonts
echo -e "\n${YELLOW}[7/8] Building HackLine fonts...${NC}"
uv run python merge_fonts.py
echo -e "${GREEN}✓ HackLine fonts generated${NC}"

# Build Nerd Font version (optional)
if [ "$1" = "--nerd" ] || [ "$1" = "-n" ]; then
    echo -e "\n${YELLOW}[8/8] Building Nerd Font version...${NC}"

    if [ ! -d "HackNerdFont" ]; then
        echo "Downloading HackNerdFont..."
        curl -L -o HackNerdFont.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Hack.zip
        unzip -o HackNerdFont.zip -d HackNerdFont
        rm HackNerdFont.zip
    fi

    uv run python add_nerd_glyphs.py
    echo -e "${GREEN}✓ Nerd Font version generated${NC}"
else
    echo -e "\n${YELLOW}[8/8] Skipping Nerd Font version (use --nerd to enable)${NC}"
fi

# Summary
echo -e "\n${GREEN}============================================================${NC}"
echo -e "${GREEN}Build Complete!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo -e "Generated fonts in ${YELLOW}build/${NC}:"
ls -lh build/*.ttf
