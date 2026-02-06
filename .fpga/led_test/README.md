# FPGA LED Test - PLL Clock Verification

This project verifies the 25.175 MHz PLL clock configuration used by the VGA TinyTapeout project.

## Purpose

Before testing the VGA output with a PMOD, this LED test confirms:
- 12 MHz input clock is working
- PLL is generating 25.175 MHz correctly
- PLL achieves lock
- Basic FPGA I/O is functional

## Expected Behavior

When running correctly:
- **Green LED (LED[4])**: Always ON - indicates PLL is locked
- **Red LEDs (LED[3:0])**: Walking pattern bouncing back and forth (~0.3s per step)

If the green LED is OFF, the PLL failed to lock.

## Hardware

- **Board**: Lattice iCEstick (iCE40HX1K)
- **Input Clock**: 12 MHz crystal
- **PLL Output**: 25.175 MHz (same as VGA 640x480 @ 60Hz pixel clock)

## Usage

```bash
# First time setup
make setup

# Build and flash
make flash

# Or just build
make build

# Or just upload (if already built)
make upload

# Clean build artifacts
make clean
```

## PLL Configuration

The PLL uses the same settings as the VGA project:
- DIVR = 0
- DIVF = 66
- DIVQ = 5
- Input: 12 MHz → Output: ~25.175 MHz

## Shared PLL

This project uses the shared PLL from `../common/pll_25mhz.v`. The Makefile automatically syncs this file before building, ensuring any PLL configuration changes propagate to both this test and the main VGA project.

## Files

- `led_test.v` - Verilog source
- `led_test.pcf` - Pin constraints
- `apio.ini` - Apio project configuration
- `Makefile` - Build automation
- `pll_25mhz.v` - Auto-synced from `../common/` (not committed)
