# VGA Bouncing Text for TinyTapeout

![VGA Preview](vga_preview.gif)

Bouncing "EMBEDDEDINN" text with parallax starfield background, designed for [TinyTapeout](https://tinytapeout.com/). Generates 640x480 @ 60Hz VGA output with animated text rendered using procedural gate-logic (no ROM).

## Features

- **Bouncing text** "EMBEDDEDINN" with procedurally generated font
- **Parallax starfield** background for depth effect
- **No ROM required** - text shapes generated via combinational logic
- **VGA 640x480 @ 60Hz** standard timing
- **TinyTapeout compatible** - standard TT interface

## Project Structure

```
vga_tt/
├── src/
│   ├── vga_tt.v           # Core TinyTapeout module (for submission)
│   ├── fpga_top.v         # FPGA wrapper (uses PLL)
│   ├── info.yaml          # TinyTapeout project metadata
│   └── vga_tt.pcf         # FPGA pin constraints (TinyVGA PMOD)
├── test/                  # TinyTapeout cocotb tests
│   ├── Makefile
│   ├── tb.v
│   └── test.py
├── .fpga/                 # FPGA tools (dot-prefix hides from apio)
│   ├── common/
│   │   └── pll_25mhz.v    # Shared PLL module (12MHz → 25.175MHz)
│   └── led_test/          # LED test for PLL verification
├── apio.ini               # Apio project configuration
├── Makefile               # Build automation
└── README.md
```

### File Separation

The project maintains a clear separation between TinyTapeout submission files and FPGA-specific files:

| File | Purpose | Submitted to TT |
|------|---------|-----------------|
| `src/vga_tt.v` | Core VGA design | Yes |
| `src/info.yaml` | Project metadata | Yes |
| `src/fpga_top.v` | FPGA wrapper with PLL | No |
| `.fpga/common/pll_25mhz.v` | iCE40 PLL configuration | No |

### Shared Components

The `.fpga/common/` directory contains components shared between the VGA project and LED test. The dot-prefix prevents apio from scanning this directory during builds. Components are synced to their respective build locations via `make sync-common`.

## Quick Start

```bash
# Setup development environment
make setup

# Build and flash VGA project to FPGA
make flash

# Or run LED test first to verify PLL
make led-test
```

## Makefile Targets

### FPGA Targets
| Target | Description |
|--------|-------------|
| `make build` | Build VGA FPGA bitstream |
| `make flash` | Build and flash VGA project to FPGA |
| `make upload` | Upload without rebuilding |
| `make led-test` | Build and flash LED test (PLL verification) |

### Testing
| Target | Description |
|--------|-------------|
| `make test` | Run cocotb tests (TinyTapeout compatible) |
| `make gif` | Generate animated GIF from VGA simulation output |

### TinyTapeout Release
| Target | Description |
|--------|-------------|
| `make tt-release` | Create TT release package (ready to drop into shuttle repo) |
| `make tt-copy` | Copy release to TT shuttle repo |
| `make tt-diff` | Compare local files with shuttle repo |

### Setup & Clean
| Target | Description |
|--------|-------------|
| `make setup` | Install development dependencies |
| `make clean` | Clean build artifacts |
| `make clean-all` | Clean everything including release |

## Hardware Testing

### LED Test (PLL Verification)

Before testing VGA output, verify the PLL clock is working:

```bash
make led-test
```

**Expected behavior:**
- **Green LED (LED[4])**: ON = PLL locked
- **Red LEDs (LED[3:0])**: Walking pattern (~0.3s per step)

### VGA Output

Connect TinyVGA PMOD to J2 header on iCEstick:

```bash
make flash
```

**Expected output:** Bouncing "EMBEDDEDINN" text with starfield background

## TinyTapeout Submission

### Workflow Overview

1. **Develop locally** - Edit `src/vga_tt.v` and `src/info.yaml`
2. **Test on FPGA** - Use `make flash` to verify on hardware
3. **Run tests** - Use `make test` to verify cocotb tests pass
4. **Create release** - Use `make tt-release` to package for TT
5. **Copy to shuttle** - Use `make tt-copy` to sync with shuttle repo

### Create Release Package

```bash
make tt-release
```

This creates `../vga_tt_release/` with:
- `src/vga_tt.v` - Core module for submission
- `info.yaml` - Project metadata
- `test/` - Cocotb tests (Makefile, tb.v, test.py)

The release package can be dropped directly into the TinyTapeout shuttle repo.

### Copy to Shuttle Repo

```bash
# Set shuttle repo path (default: ../tinytapeout-ihp-26a)
export TT_SHUTTLE_REPO=/path/to/shuttle/repo

# Copy files to shuttle repo
make tt-copy

# Check for differences
make tt-diff
```


## Architecture

### Block Diagram

```
                    ┌─────────────────────────────────────────────────────┐
                    │              tt_um_embeddedinn_vga                  │
                    │                                                     │
  clk (25MHz) ──────┤──┬──────────────────────────────────────────────────┤
                    │  │                                                  │
  rst_n ────────────┤──┼─────┐                                           │
                    │  │     │                                           │
                    │  ▼     ▼                                           │
                    │ ┌─────────────────┐    ┌──────────────────────┐    │
                    │ │ hvsync_generator│    │  Text & Starfield    │    │
                    │ │                 │    │     Renderer         │    │
                    │ │  hpos[9:0] ─────┼───►│                      │    │
                    │ │  vpos[9:0] ─────┼───►│  Procedural font     │    │
                    │ │  hsync ─────────┼────┼──────────────────┐   │    │
                    │ │  vsync ─────────┼────┼───────────────┐  │   │    │
                    │ │  display_on ────┼───►│               │  │   │    │
                    │ └─────────────────┘    └───────┬───────┘  │   │    │
                    │                                │          │   │    │
                    │                                ▼          ▼   ▼    │
                    │                        ┌─────────────────────────┐ │
                    │                        │    Output Packing       │ │
                    │                        │ {hsync,B0,G0,R0,        │ │
                    │                        │  vsync,B1,G1,R1}        │ │
                    │                        └────────────┬────────────┘ │
                    │                                     │              │
                    └─────────────────────────────────────┼──────────────┘
                                                         ▼
                                                   uo_out[7:0]
```

### VGA Timing (640x480 @ 60Hz)

| Parameter | Value |
|-----------|-------|
| Pixel Clock | 25.175 MHz |
| H Display | 640 |
| H Front Porch | 16 |
| H Sync | 96 |
| H Back Porch | 48 |
| **H Total** | **800** |
| V Display | 480 |
| V Front Porch | 10 |
| V Sync | 2 |
| V Back Porch | 33 |
| **V Total** | **525** |

### Pin Mapping

#### TinyTapeout Output (uo_out) to TinyVGA PMOD

The TinyTapeout module packs VGA signals into `uo_out[7:0]`:

| uo_out Bit | Signal | TinyVGA PMOD Pin |
|------------|--------|------------------|
| 7 | HSYNC | Pin 10 |
| 6 | B[0] (Blue LSB) | Pin 9 |
| 5 | G[0] (Green LSB) | Pin 8 |
| 4 | R[0] (Red LSB) | Pin 7 |
| 3 | VSYNC | Pin 4 |
| 2 | B[1] (Blue MSB) | Pin 3 |
| 1 | G[1] (Green MSB) | Pin 2 |
| 0 | R[1] (Red MSB) | Pin 1 |

#### iCEstick J2 Header to TinyVGA PMOD

For FPGA testing on iCEstick, connect TinyVGA PMOD to J2 header:

```
TinyVGA PMOD Pinout:
  Top Row:    [1:R1] [2:G1] [3:B1] [4:VS] [5:GND] [6:VCC]
  Bottom Row: [7:R0] [8:G0] [9:B0] [10:HS] [11:GND] [12:VCC]
```

| PMOD Pin | Signal | iCEstick J2 | FPGA Pin |
|----------|--------|-------------|----------|
| 1 | R1 (Red MSB) | Top row, pin 1 | 78 |
| 2 | G1 (Green MSB) | Top row, pin 2 | 79 |
| 3 | B1 (Blue MSB) | Top row, pin 3 | 80 |
| 4 | VS (VSync) | Top row, pin 4 | 81 |
| 7 | R0 (Red LSB) | Bottom row, pin 1 | 87 |
| 8 | G0 (Green LSB) | Bottom row, pin 2 | 88 |
| 9 | B0 (Blue LSB) | Bottom row, pin 3 | 90 |
| 10 | HS (HSync) | Bottom row, pin 4 | 91 |

Reference: [TinyVGA PMOD by mole99](https://github.com/mole99/tiny-vga)

## PLL Module

The `.fpga/common/pll_25mhz.v` module provides clock generation for iCE40:
- Input: 12 MHz crystal
- Output: ~25.175 MHz (VGA pixel clock)
- Lock indicator output

This is the **single source of truth** for PLL configuration. Both the VGA project and LED test sync this file before building (`make sync-common`), ensuring any PLL changes propagate to all projects automatically.

## Verification

TinyTapeout compatible cocotb tests in `test/` directory:

```bash
make test
```

These are the same tests used in the TinyTapeout submission.

### Visual Validation

Generate animated GIFs showing the VGA output:

```bash
make gif
```

This uses Verilator for fast native simulation, capturing 540 consecutive frames (one full horizontal bounce cycle, ~9 seconds at 60Hz) and creates two GIF files:

| File | Description |
|------|-------------|
| `vga_output.gif` | Frame-accurate capture (all 540 frames @ 17ms) |
| `vga_preview.gif` | Browser-compensated preview (real-time playback) |

**GIF Framerate Note:** The GIF format specifies frame delays in centiseconds (1/100th second), and most browsers enforce a minimum delay of ~20ms per frame. This means `vga_output.gif` may play slower than real-time in browsers. The `vga_preview.gif` compensates by skipping frames, so it plays at the correct real-time speed despite browser limitations. The actual RTL runs at true 60Hz when deployed on hardware.

## Prerequisites

- [uv](https://github.com/astral-sh/uv) - Python package manager
- Python 3.11+
- Docker (optional, for local TT hardening)

### macOS

```bash
# Install uv (Python package manager)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install project dependencies and apio packages
make setup
```

### Ubuntu

```bash
# Install uv (Python package manager)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install libusb for FPGA programming (optional, for flashing)
sudo apt-get update
sudo apt-get install -y libusb-1.0-0-dev

# Install project dependencies and apio packages
make setup
```

### What `make setup` Does

1. Installs Python dependencies via uv (apio, cocotb, pytest)
2. Downloads apio packages (oss-cad-suite: yosys, nextpnr, iverilog, iceprog)

## License

MIT
