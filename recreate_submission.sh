#!/bin/bash
# Script to recreate tt-vga-submission from official TinyTapeout IHP template

set -e  # Exit on error

echo "======================================="
echo "Recreating TinyTapeout IHP Submission"
echo "======================================="

# Configuration
SUBMISSION_REPO="vppillai/tt-vga-submission"
TEMPLATE_REPO="TinyTapeout/ttihp-verilog-template"
TEMP_DIR="/tmp/tt-vga-fresh"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo "${BLUE}Step 1: Removing old temporary directory if it exists${NC}"
rm -rf "$TEMP_DIR"

echo ""
echo "${BLUE}Step 2: Cloning official TinyTapeout IHP template${NC}"
git clone "https://github.com/$TEMPLATE_REPO.git" "$TEMP_DIR"
cd "$TEMP_DIR"

echo ""
echo "${BLUE}Step 3: Replacing source files with our VGA project${NC}"
# Clear template files
rm -rf src/* test/* docs/*

# Copy our files
echo "Copying vga_tt.v..."
cp /Users/vpillai/temp/vga_tt/src/vga_tt.v src/

echo "Copying info.yaml..."
cp /Users/vpillai/temp/vga_tt/src/info.yaml ./

echo "Copying test files..."
cp /Users/vpillai/temp/vga_tt/test/Makefile test/
cp /Users/vpillai/temp/vga_tt/test/tb.v test/
cp /Users/vpillai/temp/vga_tt/test/test.py test/
cp /Users/vpillai/temp/vga_tt/test/README.md test/

echo "Copying documentation..."
cp /Users/vpillai/temp/vga_tt/docs/info.md docs/
cp /Users/vpillai/temp/vga_tt/docs/README.md ./

echo "Copying VGA preview GIF..."
cp /Users/vpillai/temp/vga_tt/vga_preview.gif ./

echo ""
echo "${BLUE}Step 4: Initializing new Git repository${NC}"
# Remove template's .git directory
rm -rf .git

# Initialize fresh repo
git init
git add .
git commit -m "Initial commit from ttihp-verilog-template with VGA project"

echo ""
echo "${GREEN}✓ Fresh repository created successfully!${NC}"
echo ""
echo "Next steps:"
echo "1. Delete your existing tt-vga-submission repo on GitHub"
echo "   → Go to: https://github.com/vppillai/tt-vga-submission/settings"
echo "   → Scroll down and click 'Delete this repository'"
echo ""
echo "2. Create a new empty repository named 'tt-vga-submission' on GitHub"
echo "   → Go to: https://github.com/new"
echo "   → Name: tt-vga-submission"
echo "   → Description: VGA Bouncing Text for TinyTapeout IHP"
echo "   → Keep it PUBLIC"
echo "   → Do NOT initialize with README, .gitignore, or license"
echo ""
echo "3. Push this fresh repository:"
echo "   cd $TEMP_DIR"
echo "   git remote add origin https://github.com/vppillai/tt-vga-submission.git"
echo "   git branch -M main"
echo "   git push -u origin main"
echo ""
echo "4. Enable GitHub Pages:"
echo "   → Go to: https://github.com/vppillai/tt-vga-submission/settings/pages"
echo "   → Source: GitHub Actions"
echo "   → Click Save"
echo ""
echo "5. Wait for workflows to complete and verify all pass!"
echo ""
echo "Repository location: $TEMP_DIR"
