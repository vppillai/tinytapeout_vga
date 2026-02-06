`default_nettype none

// Shared PLL Module - 12 MHz to 25.175 MHz
// Used by VGA project and LED test for clock generation
// Target: iCE40 HX1K (iCEstick)
//
// Input:  12 MHz crystal
// Output: ~25.175 MHz (VGA 640x480 @ 60Hz pixel clock)
//
// PLL Parameters calculated for iCE40:
//   Fout = Fin * (DIVF + 1) / ((DIVR + 1) * 2^DIVQ)
//   25.175 ≈ 12 * (66 + 1) / ((0 + 1) * 2^5) = 12 * 67 / 32 = 25.125 MHz

module pll_25mhz (
    input  wire clk_in,      // 12 MHz input clock
    output wire clk_out,     // ~25.175 MHz output clock
    output wire locked       // PLL lock indicator
);

    SB_PLL40_CORE #(
        .FEEDBACK_PATH("SIMPLE"),
        .DIVR(4'b0000),         // DIVR =  0
        .DIVF(7'b1000010),      // DIVF = 66
        .DIVQ(3'b101),          // DIVQ =  5
        .FILTER_RANGE(3'b001)
    ) pll_inst (
        .LOCK(locked),
        .RESETB(1'b1),
        .BYPASS(1'b0),
        .REFERENCECLK(clk_in),
        .PLLOUTCORE(clk_out)
    );

endmodule
