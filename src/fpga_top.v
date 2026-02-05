
`default_nettype none

// This module translates the FPGA pins to the Tiny Tapeout format
module fpga_top(
    input  wire CLK,      // 12 MHz Crystal on the FPGA board
    input  wire BTN_N,    // Reset Button (Usually active low on boards)

    // Physical VGA Pins (Connect these to your Pmod/connector)
    output wire VGA_HSYNC,
    output wire VGA_VSYNC,
    output wire [1:0] VGA_R,
    output wire [1:0] VGA_G,
    output wire [1:0] VGA_B
);

    // 1. GENERATE 25.125 MHz CLOCK
    // This uses the specialized hardware inside the iCE40
    wire clk_25mhz;
    wire locked;
    // We surround this block with "lint_off" so Apio stops complaining
    // about the unconnected advanced pins (SDI, SDO, etc).
    /* verilator lint_off PINMISSING */
    SB_PLL40_CORE #(
        .FEEDBACK_PATH("SIMPLE"),
        .DIVR(4'b0000),      // DIVR =  0
        .DIVF(7'b1000010),   // DIVF = 66
        .DIVQ(3'b101),       // DIVQ =  5
        .FILTER_RANGE(3'b001)
    ) pll (
        .LOCK(locked),
        .RESETB(1'b1),
        .BYPASS(1'b0),
        .REFERENCECLK(CLK),
        .PLLOUTCORE(clk_25mhz)
    );

    // 2. INSTANTIATE YOUR TINY TAPE OUT PROJECT
    wire [7:0] uo_out;
    wire [7:0] ui_in = 8'b0;  // Tie inputs to 0 for now (or connect to other buttons)
    wire [7:0] uio_in = 8'b0;

    // Handle Reset: Tiny Tapeout wants Active Low (rst_n).
    // If your board button is Active Low, pass it through.
    // If your board button is Active High, invert it.
    wire rst_n = BTN_N;

    tt_um_vga_example tt_project (
        .ui_in  (ui_in),
        .uo_out (uo_out),
        .uio_in (uio_in),
        .uio_out(),
        .uio_oe (),
        .ena    (1'b1),
        .clk    (clk_25mhz), // Use the generated 25MHz clock
        .rst_n  (rst_n)
    );

    // 3. MAP THE PINS
    // We must unpack the 8-bit 'uo_out' bundle into physical VGA wires.
    // Based on your Tiny Tapeout logic:
    // uo_out = {hsync, B0, G0, R0, vsync, B1, G1, R1}

    // MSB (High Bit)
    assign VGA_HSYNC = uo_out[7];
    assign VGA_B[0]  = uo_out[6];
    assign VGA_G[0]  = uo_out[5];
    assign VGA_R[0]  = uo_out[4];

    // LSB (Low Bit)
    assign VGA_VSYNC = uo_out[3];
    assign VGA_B[1]  = uo_out[2];
    assign VGA_G[1]  = uo_out[1];
    assign VGA_R[1]  = uo_out[0];

endmodule
