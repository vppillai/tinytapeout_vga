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

The test suite contains 18 cocotb tests organized into three categories:

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

## Waveform Viewing

View simulation waveforms:

```bash
# Using GTKWave
gtkwave tb.vcd tb.gtkw

# Using Surfer
surfer tb.vcd
```

## Test Output

Expected test results (all 18 tests should pass):
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
```

All 18 tests should pass for a valid submission.

## Additional Resources

- [TinyTapeout Testing Guide](https://tinytapeout.com/hdl/testing/)
- [cocotb Documentation](https://docs.cocotb.org/)
- [VGA Timing Specifications](http://tinyvga.com/vga-timing/640x480@60Hz)
