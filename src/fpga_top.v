`default_nettype none

// FPGA Top Module - VGA TinyTapeout Project
// Wraps the TinyTapeout module for iCEstick FPGA testing
// Uses shared PLL for 25.175 MHz clock generation

module fpga_top(
    input  wire CLK,          // 12 MHz crystal
    input  wire BTN_N,        // Reset button (active low)

    // VGA Output Pins (directly mapped to TinyVGA PMOD)
    output wire VGA_HSYNC,
    output wire VGA_VSYNC,
    output wire [1:0] VGA_R,
    output wire [1:0] VGA_G,
    output wire [1:0] VGA_B,

    // Status LED
    output wire LED_ACTIVE    // Shows PLL is locked / design running
);

    // Generate 25.175 MHz clock using shared PLL module
    wire clk_25mhz;
    wire pll_locked;

    pll_25mhz pll (
        .clk_in(CLK),
        .clk_out(clk_25mhz),
        .locked(pll_locked)
    );

    // TinyTapeout module interface
    wire [7:0] uo_out;
    wire [7:0] ui_in = 8'b0;   // Unused inputs tied low
    wire [7:0] uio_in = 8'b0;

    // Reset: TinyTapeout uses active-low reset (rst_n)
    // Only release reset when PLL is locked
    wire rst_n = BTN_N & pll_locked;

    tt_um_embeddedinn_vga tt_project (
        .ui_in  (ui_in),
        .uo_out (uo_out),
        .uio_in (uio_in),
        .uio_out(),
        .uio_oe (),
        .ena    (1'b1),
        .clk    (clk_25mhz),
        .rst_n  (rst_n)
    );

    // Unpack uo_out to VGA signals
    // TinyTapeout output format: {hsync, B0, G0, R0, vsync, B1, G1, R1}
    assign VGA_HSYNC = uo_out[7];
    assign VGA_B[0]  = uo_out[6];
    assign VGA_G[0]  = uo_out[5];
    assign VGA_R[0]  = uo_out[4];
    assign VGA_VSYNC = uo_out[3];
    assign VGA_B[1]  = uo_out[2];
    assign VGA_G[1]  = uo_out[1];
    assign VGA_R[1]  = uo_out[0];

    // Status LED shows PLL is locked
    assign LED_ACTIVE = pll_locked;

endmodule
