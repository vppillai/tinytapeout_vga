`default_nettype none

// LED Test Module - PLL Clock Verification
// Verifies the shared 25.175 MHz PLL used by VGA project
// Uses the common pll_25mhz module

module led_test_top(
    input  wire CLK,      // 12 MHz Crystal on the FPGA board
    input  wire BTN_N,    // Reset Button (active low, directly active low unused)
    output wire [4:0] LED // 5 onboard LEDs (LED[4] is green, others red)
);

    // Generate 25.175 MHz clock using shared PLL module
    wire clk_25mhz;
    wire pll_locked;

    pll_25mhz pll (
        .clk_in(CLK),
        .clk_out(clk_25mhz),
        .locked(pll_locked)
    );

    // Counter using PLL clock
    // 25,175,000 / 2^23 ≈ 3 Hz (~0.33s per step)
    reg [25:0] counter;

    always @(posedge clk_25mhz) begin
        counter <= counter + 1;
    end

    // Walking LED pattern on red LEDs (LED[3:0])
    wire [2:0] pattern_sel = counter[25:23];

    reg [3:0] led_pattern;

    always @(*) begin
        case (pattern_sel)
            3'd0: led_pattern = 4'b0001;
            3'd1: led_pattern = 4'b0010;
            3'd2: led_pattern = 4'b0100;
            3'd3: led_pattern = 4'b1000;
            3'd4: led_pattern = 4'b1000;
            3'd5: led_pattern = 4'b0100;
            3'd6: led_pattern = 4'b0010;
            3'd7: led_pattern = 4'b0001;
        endcase
    end

    // LED[4] (green) = PLL lock indicator (ON when locked)
    // LED[3:0] (red) = walking pattern
    assign LED[4] = pll_locked;
    assign LED[3:0] = led_pattern;

endmodule
