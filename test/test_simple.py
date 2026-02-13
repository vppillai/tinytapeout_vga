# SPDX-FileCopyrightText: © 2026 Vysakh P Pillai
# SPDX-License-Identifier: Apache-2.0

"""
Simplified VGA Test for Gate-Level Simulation
Tests basic functionality without extensive timing verification
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

@cocotb.test()
async def test_basic_operation(dut):
    """Test that the VGA module produces output"""
    dut._log.info("Starting basic VGA test")

    # Set up clock (25.175 MHz = ~39.7ns period, use 40ns for simplicity)
    clock = Clock(dut.clk, 40, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)

    # Release reset
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)

    # Run for a short time and check that outputs are toggling
    hsync_values = []
    vsync_values = []

    for _ in range(1000):
        await ClockCycles(dut.clk, 1)
        hsync = (int(dut.uo_out.value) >> 7) & 1
        vsync = (int(dut.uo_out.value) >> 3) & 1
        hsync_values.append(hsync)
        vsync_values.append(vsync)

    # Check that HSYNC toggles (not stuck)
    assert len(set(hsync_values)) > 1, "HSYNC is stuck!"

    # Check that outputs are not all X or Z
    assert any(v == 0 for v in hsync_values), "HSYNC never goes low"
    assert any(v == 1 for v in hsync_values), "HSYNC never goes high"

    dut._log.info("Basic VGA test passed!")
