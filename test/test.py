# SPDX-FileCopyrightText: © 2026 Vysakh P Pillai
# SPDX-License-Identifier: Apache-2.0

"""
VGA 640x480 @ 60Hz Verification Suite for TinyTapeout
Ported from Verilog testbench to cocotb
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge, Timer

# VGA 640x480 @ 60Hz timing constants
H_DISPLAY = 640
H_FRONT = 16
H_SYNC = 96
H_BACK = 48
H_TOTAL = 800

V_DISPLAY = 480
V_FRONT = 10
V_SYNC = 2
V_BACK = 33
V_TOTAL = 525

FRAME_CLOCKS = H_TOTAL * V_TOTAL  # 420000

# Timing tolerances
HSYNC_TOL = 1
HPERIOD_TOL = 2
VSYNC_TOL = H_TOTAL
VPERIOD_TOL = H_TOTAL * 2

# Simulation clock period (smaller = faster simulation)
CLK_PERIOD_NS = 1


def get_hsync(dut):
    """Get HSYNC signal (uo_out[7])"""
    return (int(dut.uo_out.value) >> 7) & 1


def get_vsync(dut):
    """Get VSYNC signal (uo_out[3])"""
    return (int(dut.uo_out.value) >> 3) & 1


def get_rgb(dut):
    """Get RGB values from uo_out"""
    val = int(dut.uo_out.value)
    r = ((val >> 4) & 1) << 1 | ((val >> 0) & 1)
    g = ((val >> 5) & 1) << 1 | ((val >> 1) & 1)
    b = ((val >> 6) & 1) << 1 | ((val >> 2) & 1)
    return r, g, b


def is_black(dut):
    """Check if current pixel is black"""
    r, g, b = get_rgb(dut)
    return r == 0 and g == 0 and b == 0


async def wait_hsync_fall(dut):
    """Wait for HSYNC falling edge"""
    while get_hsync(dut) == 0:
        await RisingEdge(dut.clk)
    while get_hsync(dut) == 1:
        await RisingEdge(dut.clk)


async def wait_vsync_fall(dut):
    """Wait for VSYNC falling edge"""
    while get_vsync(dut) == 0:
        await RisingEdge(dut.clk)
    while get_vsync(dut) == 1:
        await RisingEdge(dut.clk)


async def wait_active_start(dut):
    """Wait for start of active video region"""
    # Wait for vsync to go low then high
    while get_vsync(dut) == 1:
        await RisingEdge(dut.clk)
    while get_vsync(dut) == 0:
        await RisingEdge(dut.clk)
    # Wait for V_BACK lines
    await ClockCycles(dut.clk, H_TOTAL * V_BACK)
    # Wait for hsync
    while get_hsync(dut) == 1:
        await RisingEdge(dut.clk)
    while get_hsync(dut) == 0:
        await RisingEdge(dut.clk)
    # Wait for H_BACK
    await ClockCycles(dut.clk, H_BACK)


@cocotb.test()
async def test_tt_interface(dut):
    """TEST 1: Verify TT interface - uio_out and uio_oe must be 0"""
    dut._log.info("TEST 1: TT interface check")

    clock = Clock(dut.clk, CLK_PERIOD_NS, unit="ns")  # 25 MHz
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 20)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    assert dut.uio_out.value == 0, f"uio_out should be 0, got {dut.uio_out.value}"
    assert dut.uio_oe.value == 0, f"uio_oe should be 0, got {dut.uio_oe.value}"
    dut._log.info("PASS: uio_out=0, uio_oe=0")


@cocotb.test()
async def test_hsync_pulse_width(dut):
    """TEST 2: HSYNC pulse width must be 96 clocks +/-1"""
    dut._log.info("TEST 2: HSYNC pulse width")

    clock = Clock(dut.clk, CLK_PERIOD_NS, unit="ns")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 20)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    await wait_hsync_fall(dut)

    # Count low period
    hsync_low_count = 0
    while get_hsync(dut) == 0:
        await RisingEdge(dut.clk)
        hsync_low_count += 1

    assert H_SYNC - HSYNC_TOL <= hsync_low_count <= H_SYNC + HSYNC_TOL, \
        f"HSYNC pulse width = {hsync_low_count}, expected {H_SYNC} +/-{HSYNC_TOL}"
    dut._log.info(f"PASS: HSYNC pulse width = {hsync_low_count} clocks")


@cocotb.test()
async def test_hsync_polarity(dut):
    """TEST 3: HSYNC polarity (active LOW)"""
    dut._log.info("TEST 3: HSYNC polarity")

    clock = Clock(dut.clk, CLK_PERIOD_NS, unit="ns")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 20)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    # Wait for hsync high (active video)
    while get_hsync(dut) == 0:
        await RisingEdge(dut.clk)
    await ClockCycles(dut.clk, 10)

    assert get_hsync(dut) == 1, "HSYNC should be HIGH during active video"
    dut._log.info("PASS: HSYNC polarity correct (active LOW)")


@cocotb.test()
async def test_hsync_period(dut):
    """TEST 4: HSYNC period must be 800 clocks +/-2"""
    dut._log.info("TEST 4: HSYNC period")

    clock = Clock(dut.clk, CLK_PERIOD_NS, unit="ns")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 20)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    await wait_hsync_fall(dut)

    # Count full period
    count = 0
    while get_hsync(dut) == 0:
        await RisingEdge(dut.clk)
        count += 1
    while get_hsync(dut) == 1:
        await RisingEdge(dut.clk)
        count += 1

    assert H_TOTAL - HPERIOD_TOL <= count <= H_TOTAL + HPERIOD_TOL, \
        f"HSYNC period = {count}, expected {H_TOTAL} +/-{HPERIOD_TOL}"
    dut._log.info(f"PASS: HSYNC period = {count} clocks")


@cocotb.test()
async def test_hsync_consistency(dut):
    """TEST 5: HSYNC consistency over 10 lines"""
    dut._log.info("TEST 5: HSYNC consistency")

    clock = Clock(dut.clk, CLK_PERIOD_NS, unit="ns")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 20)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    periods = []
    for _ in range(10):
        await wait_hsync_fall(dut)
        count = 0
        while get_hsync(dut) == 0:
            await RisingEdge(dut.clk)
            count += 1
        while get_hsync(dut) == 1:
            await RisingEdge(dut.clk)
            count += 1
        periods.append(count)

    min_p, max_p = min(periods), max(periods)
    assert max_p - min_p <= 2, f"HSYNC jitter too high: min={min_p}, max={max_p}"
    dut._log.info(f"PASS: HSYNC consistency (min={min_p}, max={max_p}, avg={sum(periods)//10})")


@cocotb.test()
async def test_vsync_pulse_width(dut):
    """TEST 6: VSYNC pulse width (2 lines = 1600 clocks +/-800)"""
    dut._log.info("TEST 6: VSYNC pulse width")

    clock = Clock(dut.clk, CLK_PERIOD_NS, unit="ns")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 20)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    dut._log.info("Waiting for VSYNC...")
    await wait_vsync_fall(dut)

    vsync_low_count = 0
    while get_vsync(dut) == 0:
        await RisingEdge(dut.clk)
        vsync_low_count += 1

    expected = V_SYNC * H_TOTAL
    assert expected - VSYNC_TOL <= vsync_low_count <= expected + VSYNC_TOL, \
        f"VSYNC pulse width = {vsync_low_count}, expected {expected} +/-{VSYNC_TOL}"
    dut._log.info(f"PASS: VSYNC pulse width = {vsync_low_count} clocks")


@cocotb.test()
async def test_vsync_polarity(dut):
    """TEST 7: VSYNC polarity (active LOW)"""
    dut._log.info("TEST 7: VSYNC polarity")

    clock = Clock(dut.clk, CLK_PERIOD_NS, unit="ns")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 20)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    # Wait for vsync high
    while get_vsync(dut) == 0:
        await RisingEdge(dut.clk)
    await ClockCycles(dut.clk, 100)

    assert get_vsync(dut) == 1, "VSYNC should be HIGH outside sync period"
    dut._log.info("PASS: VSYNC polarity correct (active LOW)")


@cocotb.test()
async def test_frame_period(dut):
    """TEST 8: Full frame period (525 lines x 800 = 420000 clocks)"""
    dut._log.info("TEST 8: Frame period")

    clock = Clock(dut.clk, CLK_PERIOD_NS, unit="ns")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 20)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    dut._log.info("Measuring full frame period...")
    await wait_vsync_fall(dut)

    frame_clocks = 0
    # Wait for vsync high
    while get_vsync(dut) == 0:
        await RisingEdge(dut.clk)
        frame_clocks += 1

    # Count until next vsync low
    while get_vsync(dut) == 1:
        await RisingEdge(dut.clk)
        frame_clocks += 1

    assert FRAME_CLOCKS - VPERIOD_TOL <= frame_clocks <= FRAME_CLOCKS + VPERIOD_TOL, \
        f"Frame period = {frame_clocks}, expected {FRAME_CLOCKS} +/-{VPERIOD_TOL}"
    dut._log.info(f"PASS: Frame period = {frame_clocks} clocks")


@cocotb.test()
async def test_blanking_during_hsync(dut):
    """TEST 9: Pixels must be BLACK during HSYNC"""
    dut._log.info("TEST 9: Blanking during HSYNC")

    clock = Clock(dut.clk, CLK_PERIOD_NS, unit="ns")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 20)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    black_count = 0
    total_samples = 0

    for _ in range(5):
        await wait_hsync_fall(dut)
        for _ in range(20):
            await RisingEdge(dut.clk)
            total_samples += 1
            if is_black(dut):
                black_count += 1

    assert black_count == total_samples, \
        f"{total_samples - black_count}/{total_samples} samples not BLACK during HSYNC"
    dut._log.info(f"PASS: All {total_samples} samples BLACK during HSYNC")


@cocotb.test()
async def test_blanking_during_vsync(dut):
    """TEST 10: Pixels must be BLACK during VSYNC"""
    dut._log.info("TEST 10: Blanking during VSYNC")

    clock = Clock(dut.clk, CLK_PERIOD_NS, unit="ns")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 20)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    await wait_vsync_fall(dut)

    black_count = 0
    total_samples = 100

    for _ in range(total_samples):
        await RisingEdge(dut.clk)
        if is_black(dut):
            black_count += 1

    assert black_count == total_samples, \
        f"{total_samples - black_count}/{total_samples} samples not BLACK during VSYNC"
    dut._log.info(f"PASS: All {total_samples} samples BLACK during VSYNC")


@cocotb.test()
async def test_active_region_has_color(dut):
    """TEST 13: Active video region has colored pixels"""
    dut._log.info("TEST 13: Active region color check")

    clock = Clock(dut.clk, CLK_PERIOD_NS, unit="ns")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 20)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    dut._log.info("Checking active region for colored pixels...")
    await wait_active_start(dut)

    non_black_pixels = 0
    for _ in range(H_DISPLAY):
        await RisingEdge(dut.clk)
        if not is_black(dut):
            non_black_pixels += 1

    assert non_black_pixels > 50, \
        f"Only {non_black_pixels}/{H_DISPLAY} colored pixels (too few)"
    dut._log.info(f"PASS: Found {non_black_pixels}/{H_DISPLAY} colored pixels in active line")


@cocotb.test()
async def test_color_values_valid(dut):
    """TEST 14: Color values are valid (2-bit RGB, values 0-3)"""
    dut._log.info("TEST 14: Color values validation")

    clock = Clock(dut.clk, CLK_PERIOD_NS, unit="ns")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 20)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    await wait_active_start(dut)

    invalid_colors = 0
    for _ in range(1000):
        await RisingEdge(dut.clk)
        r, g, b = get_rgb(dut)
        if r > 3 or g > 3 or b > 3:
            invalid_colors += 1

    assert invalid_colors == 0, f"{invalid_colors} invalid color values detected"
    dut._log.info("PASS: All color values valid (0-3 range)")


@cocotb.test()
async def test_animation(dut):
    """TEST 15: Animation - colors change between frames"""
    dut._log.info("TEST 15: Animation detection")

    clock = Clock(dut.clk, CLK_PERIOD_NS, unit="ns")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 20)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    dut._log.info("Checking animation across frames...")

    # Sample multiple lines to capture the bouncing text area
    # Text starts at tx=100, ty=100 and bounces around
    sample_lines = [120, 130, 140, 150]  # Lines where text is likely to appear
    sample_pixel = 150  # Pixel position in text area

    # Capture colors in frame 1
    frame1_colors = []
    await wait_active_start(dut)
    for line in sample_lines:
        await ClockCycles(dut.clk, H_TOTAL * line + sample_pixel)
        for _ in range(5):
            await RisingEdge(dut.clk)
            frame1_colors.append(get_rgb(dut))

    # Wait 20 frames for more movement (text moves 1 pixel/frame)
    for _ in range(20):
        await wait_vsync_fall(dut)
        while get_vsync(dut) == 0:
            await RisingEdge(dut.clk)

    # Capture colors at same locations
    frame2_colors = []
    await wait_active_start(dut)
    for line in sample_lines:
        await ClockCycles(dut.clk, H_TOTAL * line + sample_pixel)
        for _ in range(5):
            await RisingEdge(dut.clk)
            frame2_colors.append(get_rgb(dut))

    # Compare - check if any pixels changed
    color_changes = sum(1 for c1, c2 in zip(frame1_colors, frame2_colors) if c1 != c2)

    assert color_changes > 0, "No animation detected - pixels identical after 20 frames"
    dut._log.info(f"PASS: Animation detected - {color_changes}/{len(frame1_colors)} pixels changed after 20 frames")


@cocotb.test()
async def test_reset_recovery(dut):
    """TEST 16: Reset clears state and restarts correctly"""
    dut._log.info("TEST 16: Reset recovery")

    clock = Clock(dut.clk, CLK_PERIOD_NS, unit="ns")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 20)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 100)

    # Assert reset again
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    # Verify timing still correct
    await wait_hsync_fall(dut)
    hsync_low_count = 0
    while get_hsync(dut) == 0:
        await RisingEdge(dut.clk)
        hsync_low_count += 1

    assert H_SYNC - HSYNC_TOL <= hsync_low_count <= H_SYNC + HSYNC_TOL, \
        f"Timing incorrect after reset (HSYNC={hsync_low_count})"
    dut._log.info(f"PASS: Timing correct after reset (HSYNC={hsync_low_count})")


@cocotb.test()
async def test_consecutive_line_timing(dut):
    """TEST 17: 50 consecutive lines have correct timing"""
    dut._log.info("TEST 17: Consecutive line timing")

    clock = Clock(dut.clk, CLK_PERIOD_NS, unit="ns")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 20)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    line_errors = 0

    for i in range(50):
        await wait_hsync_fall(dut)
        count = 0

        while get_hsync(dut) == 0:
            await RisingEdge(dut.clk)
            count += 1
            if count > H_TOTAL + 100:
                line_errors += 1
                break

        while get_hsync(dut) == 1:
            await RisingEdge(dut.clk)
            count += 1
            if count > H_TOTAL + 100:
                line_errors += 1
                break

        if count < H_TOTAL - HPERIOD_TOL or count > H_TOTAL + HPERIOD_TOL:
            line_errors += 1

    assert line_errors == 0, f"{line_errors} lines with incorrect timing"
    dut._log.info("PASS: 50 consecutive lines have correct timing")
