# VGA Plasma Effect for Tiny Tapeout

A VGA plasma/metaball visual effect generator designed for [Tiny Tapeout](https://tinytapeout.com/). Generates 640x480 @ 60Hz VGA output with animated colorful "liquid" blobs that bounce and merge.

## Architecture

### Block Diagram

```
                    ┌─────────────────────────────────────────────────────┐
                    │              tt_um_vga_example                       │
                    │                                                      │
  clk (25MHz) ──────┤──┬──────────────────────────────────────────────────┤
                    │  │                                                   │
  rst_n ────────────┤──┼─────┐                                            │
                    │  │     │                                            │
                    │  ▼     ▼                                            │
                    │ ┌─────────────────┐    ┌─────────────────────────┐  │
                    │ │ hvsync_generator│    │   Orb Movement Logic    │  │
                    │ │                 │    │                         │  │
                    │ │  hpos[9:0] ─────┼───►│  orb1_x/y, orb2_x/y    │  │
                    │ │  vpos[9:0] ─────┼───►│  (updated on vsync)     │  │
                    │ │  hsync ─────────┼────┼──────────────────────┐  │  │
                    │ │  vsync ─────────┼────┼───────────────────┐  │  │  │
                    │ │  display_on ────┼───►│                   │  │  │  │
                    │ └─────────────────┘    └─────────┬─────────┘  │  │  │
                    │                                  │            │  │  │
                    │                                  ▼            │  │  │
                    │                        ┌─────────────────┐    │  │  │
                    │                        │ Distance Field  │    │  │  │
                    │                        │   Calculator    │    │  │  │
                    │                        │                 │    │  │  │
                    │                        │ dist1 + dist2   │    │  │  │
                    │                        └────────┬────────┘    │  │  │
                    │                                 │             │  │  │
                    │                                 ▼             │  │  │
                    │                        ┌─────────────────┐    │  │  │
                    │                        │  Color Mapper   │    │  │  │
                    │                        │  (8-color LUT)  │    │  │  │
                    │                        │                 │    │  │  │
                    │                        │  R[1:0],G[1:0], │    │  │  │
                    │                        │  B[1:0]         │    │  │  │
                    │                        └────────┬────────┘    │  │  │
                    │                                 │             │  │  │
                    │                                 ▼             ▼  ▼  │
                    │                        ┌─────────────────────────┐  │
                    │                        │    Output Packing       │  │
                    │                        │ {hsync,B0,G0,R0,        │  │
                    │                        │  vsync,B1,G1,R1}        │  │
                    │                        └────────────┬────────────┘  │
                    │                                     │               │
                    └─────────────────────────────────────┼───────────────┘
                                                          ▼
                                                    uo_out[7:0]
```

### Modules

| Module | Description |
|--------|-------------|
| `tt_um_vga_example` | Top-level Tiny Tapeout wrapper with standard TT interface |
| `hvsync_generator` | VGA timing generator for 640x480 @ 60Hz (25.175 MHz pixel clock) |
| `fpga_top` | FPGA wrapper with PLL for iCE40 (not used for tapeout) |

### Key Features

- **Two animated metaballs** bouncing at different speeds (2 and 3 pixels/frame)
- **Distance field rendering** using squared Euclidean distance
- **8-color palette** with smooth gradient transitions
- **Resource-efficient** 6-bit downsampled distance calculation

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

### Pin Mapping (uo_out)

| Bit | Signal |
|-----|--------|
| 7 | HSYNC |
| 6 | B[0] |
| 5 | G[0] |
| 4 | R[0] |
| 3 | VSYNC |
| 2 | B[1] |
| 1 | G[1] |
| 0 | R[1] |

## Project Structure

```
vga_tt/
├── src/
│   ├── vga_tt.v          # Main TT module + hvsync_generator
│   └── fpga_top.v        # FPGA wrapper (iCE40 PLL)
├── test/
│   └── vga_tt_tb.v       # Verilog testbench
├── apio.ini              # Apio project configuration
├── pyproject.toml        # Python/uv dependencies
├── vga_tt.pcf            # FPGA pin constraints
└── README.md
```

## Prerequisites

- [uv](https://github.com/astral-sh/uv) - Python package manager
- Python 3.11-3.13

## Setup

```bash
# Install dependencies
uv sync

# Install apio packages (oss-cad-suite with iverilog, yosys, etc.)
uv run apio packages update
```

## Verification

The testbench (`test/vga_tt_tb.v`) provides comprehensive VGA 640x480 @ 60Hz verification:

### Timing Tests
| Test | Description | Tolerance |
|------|-------------|-----------|
| TEST 2 | HSYNC pulse width = 96 clocks | ±1 clock |
| TEST 3 | HSYNC polarity (active LOW) | - |
| TEST 4 | HSYNC period = 800 clocks | ±2 clocks |
| TEST 5 | HSYNC consistency (10 lines) | ±2 clocks jitter |
| TEST 6 | VSYNC pulse width = 1600 clocks | ±800 clocks |
| TEST 7 | VSYNC polarity (active LOW) | - |
| TEST 8 | Frame period = 420000 clocks | ±1600 clocks |
| TEST 17 | 50 consecutive line timing | ±2 clocks |

### Blanking Tests
| Test | Description |
|------|-------------|
| TEST 9 | Pixels BLACK during HSYNC (100 samples) |
| TEST 10 | Pixels BLACK during VSYNC (100 samples) |
| TEST 11 | Pixels BLACK during H front porch |
| TEST 12 | Pixels BLACK during H back porch |

### Functional Tests
| Test | Description |
|------|-------------|
| TEST 1 | TT interface (`uio_out`=0, `uio_oe`=0) |
| TEST 13 | Colored pixels in active region (>50 required) |
| TEST 14 | Color values valid (2-bit RGB, 0-3 range) |
| TEST 15 | Animation detection (pixel change after 10 frames) |
| TEST 16 | Reset recovery (timing correct after reset) |

### Run Tests

```bash
# Run simulation (headless)
uv run apio sim --no-gtkwave

# Run simulation with waveform viewer
uv run apio sim
```

### Expected Output

```
========================================
VGA 640x480 @ 60Hz Verification Suite
========================================

[PASS] TEST 1: TT interface - uio_out=0, uio_oe=0
[PASS] TEST 2: HSYNC pulse width = 96 clocks (spec: 96 ±1)
[PASS] TEST 3: HSYNC polarity correct (active LOW)
[PASS] TEST 4: HSYNC period = 800 clocks (spec: 800 ±2)
[PASS] TEST 5: HSYNC consistency over 10 lines (min=800, max=800, avg=800)
[PASS] TEST 6: VSYNC pulse width = 1600 clocks (spec: 1600 ±800)
[PASS] TEST 7: VSYNC polarity correct (active LOW)
[PASS] TEST 8: Frame period = 420000 clocks (spec: 420000 ±1600)
[PASS] TEST 9: All 100 samples BLACK during HSYNC
[PASS] TEST 10: All 100 samples BLACK during VSYNC
[PASS] TEST 11: Pixels BLACK during H front porch
[PASS] TEST 12: Pixels BLACK during H back porch
[PASS] TEST 13: Found 397/640 colored pixels in active line
[PASS] TEST 14: All color values valid (0-3 range)
[PASS] TEST 15: Animation detected - 10/10 pixels changed after 10 frames
[PASS] TEST 16: Timing correct after reset (HSYNC=96)
[PASS] TEST 17: 50 consecutive lines have correct timing

========================================
VGA VERIFICATION SUMMARY
========================================
Tests passed: 17 / 17
Tests failed: 0 / 17
========================================
*** ALL TESTS PASSED ***
VGA output verified for 640x480 @ 60Hz
========================================
```

## FPGA Build

```bash
# Build for iCE40 (icestick)
uv run apio build

# Upload to FPGA
uv run apio upload
```

## Tiny Tapeout Submission

For tapeout, use only `src/vga_tt.v` which contains:
- `tt_um_vga_example` - Main module with TT interface
- `hvsync_generator` - VGA timing generator

The `fpga_top.v` wrapper (with iCE40 PLL) is excluded from tapeout.

## License

MIT
