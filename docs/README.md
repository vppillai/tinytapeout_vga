![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# Cyber EMBEDDEDINN - VGA Bouncing Text

A single-tile VGA design for [Tiny Tapeout](https://tinytapeout.com) featuring bouncing "EMBEDDEDINN" text with a parallax starfield background.

![VGA Preview](docs/vga_preview.gif)

## Features

- **Bouncing text animation** - "EMBEDDEDINN" bounces smoothly across the screen
- **Procedurally generated font** - Characters rendered using combinational logic (no ROM)
- **Parallax starfield** - Dynamic background with depth effect
- **Interactive controls** - 4 speed modes, 4 color palettes, toggleable scanline effect
- **Standard VGA output** - 640x480 @ 60Hz, 2-bit RGB per channel
- **Single tile design** - Fits in one 167x108 µm tile

## How it works

### VGA Timing Generator
Implements standard VGA 640x480 @ 60Hz timing using horizontal and vertical counters. Generates HSYNC and VSYNC signals according to the VGA specification (25.175 MHz pixel clock).

### Generative Font Engine
Each character in "EMBEDDEDINN" is generated on-the-fly using combinational logic that defines primitive shapes (left bar, right bar, top bar, mid bar, bottom bar). Characters occupy 32x40 pixel slots with proper spacing for readability.

### Animation System
Frame counter synchronized to VSYNC drives smooth bouncing motion. Text position updates each frame with configurable speed and direction reversal at screen boundaries, creating stable, glitch-free animation.

### Interactive Controls
The design supports real-time control via `ui_in` pins:
- **Speed** (`ui_in[1:0]`): Normal, Fast (2x), Slow (0.5x), or Pause
- **Palette** (`ui_in[3:2]`): Classic, Cyberpunk, Forest, or Monochrome color themes
- **Scanline** (`ui_in[4]`): Toggle retro scanline effect

### Parallax Starfield
Background starfield created using XOR patterns that evolve with the frame counter, providing visual depth and a retro aesthetic.

## Pin Configuration

### Inputs

| Pin | Signal | Description |
|-----|--------|-------------|
| ui[0] | Speed Sel 0 | Speed selection bit 0 |
| ui[1] | Speed Sel 1 | Speed selection bit 1 |
| ui[2] | Palette Sel 0 | Color palette bit 0 |
| ui[3] | Palette Sel 1 | Color palette bit 1 |
| ui[4] | Scanline Toggle | Toggle scanline effect (OFF when HIGH) |
| ui[5:7] | - | Unused |

**Speed Control (`ui_in[1:0]`):** `00` Normal, `01` Fast (2x), `10` Slow (0.5x), `11` Pause

**Color Palettes (`ui_in[3:2]`):** `00` Classic (Deep Blue/Purple), `01` Cyberpunk (Neon Pink/Cyan), `10` Forest (Green/Emerald), `11` Monochrome (Grayscale)

### Outputs (TinyVGA PMOD Compatible)

| Pin | Signal | Description |
|-----|--------|-------------|
| uo[0] | R1 | Red MSB |
| uo[1] | G1 | Green MSB |
| uo[2] | B1 | Blue MSB |
| uo[3] | VSYNC | Vertical sync |
| uo[4] | R0 | Red LSB |
| uo[5] | G0 | Green LSB |
| uo[6] | B0 | Blue LSB |
| uo[7] | HSYNC | Horizontal sync |

### Bidirectional I/O
All bidirectional pins are unused.

## External Hardware

- **[TinyVGA PMOD](https://github.com/mole99/tiny-vga)** - Provides resistor DAC for 2-bit RGB and VGA connector
- **VGA Monitor** - Any monitor supporting 640x480 @ 60Hz
- **VGA Cable** - Standard 15-pin VGA cable

## Testing

The design includes 18 cocotb tests that verify:
- VGA timing compliance (HSYNC/VSYNC periods, polarity, consistency)
- Frame generation and blanking correctness
- Color output during active video regions
- Animation detection and reset recovery
- Speed control, palette selection, and scanline toggle

Run tests locally:
```bash
cd test
make
```

## Development Repository

This is the TinyTapeout submission package. For the full development repository with FPGA testing, simulation, and build tools, see:

**[vppillai/tinytapeout_vga](https://github.com/vppillai/tinytapeout_vga)**

## Resources

- [VGA timing specifications](http://tinyvga.com/vga-timing/640x480@60Hz)
- [TinyVGA PMOD documentation](https://github.com/mole99/tiny-vga)
- [Tiny Tapeout documentation](https://tinytapeout.com)

## What is Tiny Tapeout?

Tiny Tapeout is an educational project that makes it easier and cheaper than ever to get your digital and analog designs manufactured on a real chip.

To learn more and get started, visit https://tinytapeout.com.

## License

MIT
