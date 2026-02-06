# Makefile for VGA TinyTapeout Project
# Bouncing "EMBEDDEDINN" text with parallax starfield
#
# Project structure:
#   src/               - Core TinyTapeout module + FPGA wrapper
#   test/              - Verilog testbench
#   .fpga/             - FPGA tools (dot-prefix hides from apio scanning)
#     common/          - Shared components (PLL) - single source of truth
#     led_test/        - LED test for PLL verification
#
# Shared PLL is synced to src/ and led_test/ before each build.

# Paths
TT_SHUTTLE_REPO ?= ../tinytapeout-ihp-26a
TT_PROJECT_NAME = tt_um_embeddedinn_vga
TT_RELEASE_DIR = ../vga_tt_release
COMMON_DIR = .fpga/common
LED_TEST_DIR = .fpga/led_test

.PHONY: all build flash clean test led-test led-build tt-release tt-copy tt-diff help sync-common

# =============================================================================
# FPGA Targets (VGA Project)
# =============================================================================

all: build

# Sync shared PLL module to src directory for FPGA build
sync-common:
	@echo "Syncing shared PLL module from $(COMMON_DIR)..."
	@cp $(COMMON_DIR)/pll_25mhz.v src/
	@echo "Sync complete!"

# Build FPGA bitstream
build: sync-common
	@echo "Building VGA FPGA bitstream..."
	uv run apio build
	@echo "Build complete!"

# Flash to FPGA
flash: build
	@echo "Flashing VGA project to FPGA..."
	uv run apio upload
	@echo "Flash complete!"

# Upload without rebuild
upload:
	@echo "Uploading to FPGA..."
	uv run apio upload

# =============================================================================
# LED Test Targets
# =============================================================================

# Build and flash LED test (for PLL verification)
led-test:
	@echo "Building and flashing LED test..."
	$(MAKE) -C $(LED_TEST_DIR) flash

led-build:
	$(MAKE) -C $(LED_TEST_DIR) build

# =============================================================================
# Testing
# =============================================================================

# Run cocotb tests (TinyTapeout compatible)
# Uses apio's oss-cad-suite for iverilog/vvp
test:
	@echo "Running cocotb tests..."
	cd test && uv run apio raw -- make

# =============================================================================
# TinyTapeout Release
# =============================================================================

# Create TinyTapeout release package
# This creates a directory structure that can be dropped directly into the TT shuttle repo
tt-release: clean-release
	@echo "Creating TinyTapeout release package..."
	@mkdir -p $(TT_RELEASE_DIR)/src
	@mkdir -p $(TT_RELEASE_DIR)/test
	@# Copy core source (only vga_tt.v - not FPGA-specific files)
	@cp src/vga_tt.v $(TT_RELEASE_DIR)/src/
	@# Copy info.yaml
	@cp src/info.yaml $(TT_RELEASE_DIR)/
	@# Copy TT-compatible tests
	@cp test/Makefile test/tb.v test/test.py $(TT_RELEASE_DIR)/test/
	@echo ""
	@echo "TinyTapeout release created in: $(TT_RELEASE_DIR)/"
	@echo "Contents:"
	@ls -la $(TT_RELEASE_DIR)/
	@ls -la $(TT_RELEASE_DIR)/src/
	@ls -la $(TT_RELEASE_DIR)/test/
	@echo ""
	@echo "To submit: copy contents to TT shuttle repo project directory"

# Copy release to TinyTapeout shuttle repo
tt-copy: tt-release
	@echo "Copying to TinyTapeout shuttle repo..."
	@mkdir -p "$(TT_SHUTTLE_REPO)/projects/$(TT_PROJECT_NAME)/src"
	@mkdir -p "$(TT_SHUTTLE_REPO)/projects/$(TT_PROJECT_NAME)/test"
	@cp $(TT_RELEASE_DIR)/src/* "$(TT_SHUTTLE_REPO)/projects/$(TT_PROJECT_NAME)/src/"
	@cp $(TT_RELEASE_DIR)/info.yaml "$(TT_SHUTTLE_REPO)/projects/$(TT_PROJECT_NAME)/"
	@cp $(TT_RELEASE_DIR)/test/* "$(TT_SHUTTLE_REPO)/projects/$(TT_PROJECT_NAME)/test/"
	@echo "Copied to: $(TT_SHUTTLE_REPO)/projects/$(TT_PROJECT_NAME)/"

# Show differences between local and shuttle repo
tt-diff:
	@echo "=== vga_tt.v ==="
	@diff -q src/vga_tt.v "$(TT_SHUTTLE_REPO)/projects/$(TT_PROJECT_NAME)/src/vga_tt.v" 2>/dev/null && echo "MATCH" || echo "DIFFERS"
	@echo "=== info.yaml ==="
	@diff -q src/info.yaml "$(TT_SHUTTLE_REPO)/projects/$(TT_PROJECT_NAME)/info.yaml" 2>/dev/null && echo "MATCH" || echo "DIFFERS"
	@echo "=== test/test.py ==="
	@diff -q test/test.py "$(TT_SHUTTLE_REPO)/projects/$(TT_PROJECT_NAME)/test/test.py" 2>/dev/null && echo "MATCH" || echo "DIFFERS"

# =============================================================================
# Setup & Clean
# =============================================================================

# Setup development environment
setup:
	@echo "Setting up development environment..."
	uv pip install apio cocotb
	uv run apio packages --install --force oss-cad-suite
	@echo "Setup complete!"

# Clean FPGA build artifacts
clean:
	@echo "Cleaning build artifacts..."
	uv run apio clean
	@rm -f src/pll_25mhz.v
	$(MAKE) -C $(LED_TEST_DIR) clean
	@echo "Clean complete!"

# Clean release directory
clean-release:
	@rm -rf $(TT_RELEASE_DIR)

# Clean everything
clean-all: clean clean-release

# =============================================================================
# Help
# =============================================================================

help:
	@echo "VGA TinyTapeout Project - Bouncing EMBEDDEDINN Text"
	@echo ""
	@echo "=== FPGA Targets ==="
	@echo "  make build       - Build VGA FPGA bitstream"
	@echo "  make flash       - Build and flash VGA project to FPGA"
	@echo "  make upload      - Upload without rebuilding"
	@echo "  make led-test    - Build and flash LED test (PLL verification)"
	@echo ""
	@echo "=== Testing ==="
	@echo "  make test        - Run cocotb tests"
	@echo ""
	@echo "=== TinyTapeout Release ==="
	@echo "  make tt-release  - Create TT release package (ready to drop into shuttle repo)"
	@echo "  make tt-copy     - Copy release to TT shuttle repo"
	@echo "  make tt-diff     - Compare local files with shuttle repo"
	@echo ""
	@echo "=== Setup & Clean ==="
	@echo "  make setup       - Install development dependencies"
	@echo "  make clean       - Clean build artifacts"
	@echo "  make clean-all   - Clean everything including release"
	@echo ""
	@echo "=== Shared Components ==="
	@echo "  PLL source:      $(COMMON_DIR)/pll_25mhz.v"
	@echo "  LED test:        $(LED_TEST_DIR)/"
	@echo ""
	@echo "=== Configuration ==="
	@echo "  TT_SHUTTLE_REPO  = $(TT_SHUTTLE_REPO)"
	@echo "  TT_PROJECT_NAME  = $(TT_PROJECT_NAME)"
