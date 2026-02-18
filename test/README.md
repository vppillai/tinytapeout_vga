# Test Documentation for VGA Bouncing Text

This testbench verifies the VGA timing and output for the Cyber EMBEDDEDINN project.

## Test Configuration

The testbench uses cocotb for Python-based verification.

### Makefile Configuration

The `Makefile` is already configured with:
- **PROJECT_SOURCES**: `../src/vga_tt.v` - The main VGA module
- **MODULE**: `test` - Python test module
- **TOPLEVEL**: `tt_um_embeddedinn_vga` - Top-level module name

### Testbench Module

The `tb.v` testbench instantiates the `tt_um_embeddedinn_vga` module with:
- 25.175 MHz clock generation (VGA pixel clock)
- Reset control
- VGA signal outputs (HSYNC, VSYNC, RGB)

## Running Tests

### RTL Simulation

Run RTL-level simulation:

```bash
cd test
make
```

This will:
1. Compile the Verilog design
2. Run cocotb tests
3. Generate waveforms in `tb.vcd`
4. Display test results

### Gate-Level Simulation

For gate-level simulation:

1. First harden your project (GitHub Actions GDS workflow)
2. Download the GDS artifacts
3. Copy the gate-level netlist:
   ```bash
   cp ../runs/wokwi/results/final/verilog/gl/tt_um_embeddedinn_vga.v gate_level_netlist.v
   ```
4. Run gate-level tests:
   ```bash
   make -B GATES=yes
   ```

## Test Coverage

The test suite contains 22 cocotb tests organized into four categories:

### VGA Timing (Tests 1-8)
- **TT interface**: `uio_out` and `uio_oe` must be 0
- **HSYNC pulse width**: 96 clocks +/-1
- **HSYNC polarity**: Active LOW
- **HSYNC period**: 800 clocks +/-2
- **HSYNC consistency**: <2 clock jitter over 10 lines
- **VSYNC pulse width**: 2 lines (1600 clocks +/-800)
- **VSYNC polarity**: Active LOW
- **Frame period**: 420000 clocks +/-1600

### Video Output (Tests 9-12)
- **Blanking during HSYNC**: RGB must be black
- **Blanking during VSYNC**: RGB must be black
- **Active region color**: >50 colored pixels per line
- **Color values valid**: 2-bit RGB, 0-3 range

### Animation & Features (Tests 13-18)
- **Animation detection**: Pixel colors change between frames
- **Reset recovery**: Correct timing after re-asserting reset
- **Consecutive line timing**: 50 lines with correct period
- **Speed control**: Normal, Fast, Slow, Pause modes via `ui_in[1:0]`
- **Palette selection**: Different background colors per palette via `ui_in[3:2]`
- **Scanline toggle**: Scanline effect control via `ui_in[4]`

### Design Verification (Tests 19-22)
- **Font at known position**: Text renders at correct initial position (tx=100, ty=100) with expected text color
- **Pause text frozen**: Text position remains frozen across multiple frames in pause mode
- **Starfield variation**: Background starfield produces varied pixel colors (XOR pattern verification)
- **Output packing format**: `uo_out` bit positions match TinyVGA PMOD spec (hsync@7, vsync@3, RGB in correct bits)

## Waveform Viewing

View simulation waveforms:

```bash
# Using GTKWave
gtkwave tb.vcd tb.gtkw

# Using Surfer
surfer tb.vcd
```

## Test Output

Expected test results (all 22 tests should pass):
```
test.test_tt_interface ... PASS
test.test_hsync_pulse_width ... PASS
test.test_hsync_polarity ... PASS
test.test_hsync_period ... PASS
test.test_hsync_consistency ... PASS
test.test_vsync_pulse_width ... PASS
test.test_vsync_polarity ... PASS
test.test_frame_period ... PASS
test.test_blanking_during_hsync ... PASS
test.test_blanking_during_vsync ... PASS
test.test_active_region_has_color ... PASS
test.test_color_values_valid ... PASS
test.test_animation ... PASS
test.test_reset_recovery ... PASS
test.test_consecutive_line_timing ... PASS
test.test_speed_control ... PASS
test.test_palettes ... PASS
test.test_scanline_toggle ... PASS
test.test_font_at_known_position ... PASS
test.test_pause_text_frozen ... PASS
test.test_starfield_variation ... PASS
test.test_output_packing_format ... PASS
```

All 22 tests should pass for a valid submission.

### Parallel Execution

For faster local development, tests can run in 5 parallel groups:

```bash
make -j5 test-parallel
```

This runs ~2x faster by distributing tests across 5 independent simulator instances grouped by estimated wall time. From the project root, use `make test-parallel`.

## Additional Resources

- [TinyTapeout Testing Guide](https://tinytapeout.com/hdl/testing/)
- [cocotb Documentation](https://docs.cocotb.org/)
- [VGA Timing Specifications](http://tinyvga.com/vga-timing/640x480@60Hz)
