# SPDX-FileCopyrightText: © 2026 Vysakh P Pillai
# SPDX-License-Identifier: Apache-2.0

"""
VGA Frame Capture - Generate GIF from VGA simulation output

Captures VGA frames from cocotb simulation and generates an animated GIF.
This provides visual validation of the VGA output.
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge
import numpy as np

try:
    from PIL import Image
    import imageio
    HAS_IMAGING = True
except ImportError:
    HAS_IMAGING = False
    print("Warning: PIL/imageio not installed. Install with: pip install pillow imageio")

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

# Simulation clock period (1ns for faster simulation)
CLK_PERIOD_NS = 1

# 2-bit color to 8-bit mapping (0->0, 1->85, 2->170, 3->255)
COLOR_MAP = [0, 85, 170, 255]


def get_hsync(dut):
    """Get HSYNC signal (uo_out[7])"""
    return (int(dut.uo_out.value) >> 7) & 1


def get_vsync(dut):
    """Get VSYNC signal (uo_out[3])"""
    return (int(dut.uo_out.value) >> 3) & 1


def get_rgb(dut):
    """Get RGB values from uo_out as 8-bit values"""
    val = int(dut.uo_out.value)
    r = ((val >> 4) & 1) << 1 | ((val >> 0) & 1)
    g = ((val >> 5) & 1) << 1 | ((val >> 1) & 1)
    b = ((val >> 6) & 1) << 1 | ((val >> 2) & 1)
    return COLOR_MAP[r], COLOR_MAP[g], COLOR_MAP[b]


async def wait_vsync_fall(dut):
    """Wait for VSYNC falling edge (start of frame)"""
    while get_vsync(dut) == 0:
        await RisingEdge(dut.clk)
    while get_vsync(dut) == 1:
        await RisingEdge(dut.clk)


async def capture_frame(dut):
    """Capture a single 640x480 frame"""
    frame = np.zeros((V_DISPLAY, H_DISPLAY, 3), dtype=np.uint8)

    # Wait for VSYNC (start of frame)
    await wait_vsync_fall(dut)

    # Wait for vsync pulse to end
    while get_vsync(dut) == 0:
        await RisingEdge(dut.clk)

    # Wait for V_BACK lines
    await ClockCycles(dut.clk, H_TOTAL * V_BACK)

    # Capture active video region
    for y in range(V_DISPLAY):
        # Wait for HSYNC pulse
        while get_hsync(dut) == 1:
            await RisingEdge(dut.clk)
        while get_hsync(dut) == 0:
            await RisingEdge(dut.clk)

        # Wait for H_BACK
        await ClockCycles(dut.clk, H_BACK)

        # Capture pixels
        for x in range(H_DISPLAY):
            r, g, b = get_rgb(dut)
            frame[y, x] = [r, g, b]
            await RisingEdge(dut.clk)

    return frame


@cocotb.test()
async def capture_vga_gif(dut):
    """Capture VGA frames and generate animated GIF"""

    if not HAS_IMAGING:
        dut._log.warning("Skipping GIF capture - PIL/imageio not installed")
        return

    NUM_FRAMES = 30  # Number of frames to capture
    FRAME_SKIP = 2   # Skip frames between captures for faster animation
    OUTPUT_FILE = "vga_output.gif"

    dut._log.info(f"Starting VGA capture: {NUM_FRAMES} frames")

    clock = Clock(dut.clk, CLK_PERIOD_NS, unit="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 20)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    frames = []

    for i in range(NUM_FRAMES):
        dut._log.info(f"Capturing frame {i+1}/{NUM_FRAMES}")

        frame = await capture_frame(dut)
        frames.append(frame)

        # Skip frames for animation speed
        for _ in range(FRAME_SKIP):
            await wait_vsync_fall(dut)
            while get_vsync(dut) == 0:
                await RisingEdge(dut.clk)

    # Generate GIF
    dut._log.info(f"Generating GIF: {OUTPUT_FILE}")

    images = [Image.fromarray(f) for f in frames]
    imageio.mimsave(OUTPUT_FILE, images, duration=100, loop=0)  # 100ms per frame, loop forever

    dut._log.info(f"GIF saved: {OUTPUT_FILE}")
