# Makefile for FPGA LED Test Project
# Uses uv for Python environment management
# Part of vga_tt project - uses shared PLL module

# PLL source is in shared common directory
PLL_SRC = ../common/pll_25mhz.v

.PHONY: all setup build flash clean help sync-common

# Default target
all: build

# Setup the environment (install apio if needed)
setup:
	@echo "Setting up environment..."
	uv pip install apio
	uv run apio packages --install --force oss-cad-suite
	@echo "Setup complete!"

# Sync shared files from common directory
sync-common:
	@echo "Syncing shared PLL module..."
	@cp $(PLL_SRC) .
	@echo "Sync complete!"

# Build the bitstream
build: sync-common
	@echo "Building bitstream..."
	uv run apio build
	@echo "Build complete!"

# Flash to FPGA
flash: build
	@echo "Flashing to FPGA..."
	uv run apio upload
	@echo "Flash complete!"

# Just upload (skip build if already built)
upload:
	@echo "Uploading to FPGA..."
	uv run apio upload

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	uv run apio clean
	@rm -f pll_25mhz.v
	@echo "Clean complete!"

# Run simulation (if testbench exists)
sim: sync-common
	@echo "Running simulation..."
	uv run apio sim
	@echo "Simulation complete!"

# Show help
help:
	@echo "FPGA LED Test - PLL Clock Verification"
	@echo ""
	@echo "This project verifies the 25.175 MHz PLL clock used by the VGA project."
	@echo "Uses shared PLL module from: $(PLL_SRC)"
	@echo ""
	@echo "When working correctly:"
	@echo "  - Green LED (LED[4]) = ON (PLL locked)"
	@echo "  - Red LEDs (LED[3:0]) = Walking pattern (~0.3s per step)"
	@echo ""
	@echo "Available targets:"
	@echo "  make setup       - Install apio and required packages"
	@echo "  make build       - Build the bitstream (syncs shared files)"
	@echo "  make flash       - Build and flash to FPGA"
	@echo "  make upload      - Upload without rebuilding"
	@echo "  make clean       - Remove build artifacts"
	@echo "  make sync-common - Sync shared files only"
	@echo "  make help        - Show this help message"
