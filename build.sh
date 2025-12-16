#!/bin/bash
#
# HackLine Font Build Script
# Usage: ./build.sh [--nerd]
#
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
echo -e "\n${YELLOW}[1/5] Checking dependencies...${NC}"
if ! command -v uv &> /dev/null; then
    echo -e "${RED}Error: uv is required${NC}"
    echo -e "Install uv: curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

# Setup virtual environment and install dependencies
echo "Setting up Python environment with uv..."
uv sync
echo -e "${GREEN}✓ Dependencies OK${NC}"

# Download Hack font
echo -e "\n${YELLOW}[2/5] Downloading Hack font...${NC}"
if [ ! -d "hack_font" ]; then
    curl -L -o Hack-v3.003-ttf.zip https://github.com/source-foundry/Hack/releases/download/v3.003/Hack-v3.003-ttf.zip
    unzip -o Hack-v3.003-ttf.zip -d hack_font
    rm Hack-v3.003-ttf.zip
    echo -e "${GREEN}✓ Hack font downloaded${NC}"
else
    echo -e "${GREEN}✓ Hack font already exists${NC}"
fi

# Download LINE Seed JP font
echo -e "\n${YELLOW}[3/5] Downloading LINE Seed JP font...${NC}"
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
echo -e "\n${YELLOW}[4/5] Building HackLine fonts...${NC}"
uv run python merge_fonts.py
echo -e "${GREEN}✓ HackLine fonts generated${NC}"

# Build Nerd Font version (optional)
if [ "$1" = "--nerd" ] || [ "$1" = "-n" ]; then
    echo -e "\n${YELLOW}[5/5] Building Nerd Font version...${NC}"

    if [ ! -d "HackNerdFont" ]; then
        echo "Downloading HackNerdFont..."
        curl -L -o HackNerdFont.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Hack.zip
        unzip -o HackNerdFont.zip -d HackNerdFont
        rm HackNerdFont.zip
    fi

    uv run python add_nerd_glyphs.py
    echo -e "${GREEN}✓ Nerd Font version generated${NC}"
else
    echo -e "\n${YELLOW}[5/5] Skipping Nerd Font version (use --nerd to enable)${NC}"
fi

# Summary
echo -e "\n${GREEN}============================================================${NC}"
echo -e "${GREEN}Build Complete!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo -e "Generated fonts in ${YELLOW}build/${NC}:"
ls -lh build/*.ttf
