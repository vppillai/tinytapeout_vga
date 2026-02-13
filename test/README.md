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

The test suite verifies:

### VGA Timing
- **Horizontal timing**: Validates HSYNC period (31.77 µs) and pulse width
- **Vertical timing**: Validates VSYNC period (16.67 ms) and pulse width
- **Frame rate**: Confirms 60 Hz frame generation

### Video Output
- **Active region**: Checks RGB output during visible display area (640x480)
- **Blanking**: Verifies RGB = 0 during blanking periods
- **Sync polarity**: Confirms negative polarity for HSYNC and VSYNC

### Animation
- **Frame counter**: Verifies frame updates on VSYNC
- **Text position**: Checks bouncing animation state changes

## Waveform Viewing

View simulation waveforms:

```bash
# Using GTKWave
gtkwave tb.vcd tb.gtkw

# Using Surfer
surfer tb.vcd
```

## Test Output

Expected test results:
```
test.test_vga_timing ... PASS
test.test_frame_generation ... PASS
test.test_color_output ... PASS
```

All tests should pass for a valid submission.

## Additional Resources

- [TinyTapeout Testing Guide](https://tinytapeout.com/hdl/testing/)
- [cocotb Documentation](https://docs.cocotb.org/)
- [VGA Timing Specifications](http://tinyvga.com/vga-timing/640x480@60Hz)
