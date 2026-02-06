`default_nettype none

/* * Project: Cyber EMBEDDEDINN
 * Description: A single-tile VGA design for Tiny Tapeout.
 * Features:
 * - Generative block font (no ROM required)
 * - 640x480 @ 60Hz VGA timing
 * - Parallax starfield background
 * - Rock-solid stable animation
 */

module tt_um_embeddedinn_vga(
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs: VGA Pins (PMOD Standard)
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path
    input  wire       ena,      // Will be high when the design is enabled
    input  wire       clk,      // 25.175 MHz clock for VGA 640x480
    input  wire       rst_n     // Reset (Active Low)
);

    // =========================================================================
    // 1. PIN & SIGNAL ASSIGNMENTS
    // =========================================================================
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    wire hsync, vsync, video_active;
    wire [9:0] pix_x, pix_y;

    // =========================================================================
    // 2. VGA SYNC GENERATOR
    // =========================================================================
    hvsync_generator hvsync_gen(
        .clk(clk),
        .reset(~rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(video_active),
        .hpos(pix_x),
        .vpos(pix_y)
    );

    // =========================================================================
    // 3. ANIMATION TIMERS (Clean Bouncing)
    // =========================================================================
    reg [15:0] frame_cnt;
    reg [8:0] tx, ty;
    reg x_dir, y_dir;

    always @(posedge vsync or negedge rst_n) begin
        if (~rst_n) begin
            frame_cnt <= 0;
            tx <= 100; ty <= 100;
            x_dir <= 0; y_dir <= 0;
        end else begin
            frame_cnt <= frame_cnt + 1;

            // Linear Movement
            tx <= x_dir ? tx - 1 : tx + 1;
            ty <= y_dir ? ty - 1 : ty + 1;

            // Screen boundary checks for 640x480
            if (tx >= 280) x_dir <= 1; else if (tx <= 10) x_dir <= 0;
            if (ty >= 420) y_dir <= 1; else if (ty <= 10) y_dir <= 0;
        end
    end

    // =========================================================================
    // 4. GENERATIVE FONT ENGINE (Modern & Spaced)
    // =========================================================================
    wire [9:0] rx = pix_x - {1'b0, tx};
    wire [9:0] ry = pix_y - {1'b0, ty};

    // Each character is given a 32px slot
    wire [3:0] char_idx = rx[8:5];
    wire [4:0] lx = rx[4:0];
    wire [3:0] ly = ry[5:2];

    // Shape Primitives (Construct letters from bars to save gate space)
    wire left_bar   = (lx < 4);
    wire right_bar  = (lx >= 16 && lx < 20);
    wire top_bar    = (ly == 0);
    wire mid_bar    = (ly == 5);
    wire bot_bar    = (ly == 9);
    wire corner     = (top_bar || bot_bar || mid_bar) && right_bar;

    reg pix;
    always @(*) begin
        pix = 0;
        // Draw characters only if within the 11-char block and within the 20px letter width
        if (rx < 352 && ry < 40 && lx < 20) begin
            case (char_idx)
                4'd0, 4'd3, 4'd6: pix = left_bar || top_bar || mid_bar || bot_bar; // E
                4'd1:             pix = left_bar || right_bar || (lx >= 8 && lx < 12 && ly < 6); // M
                4'd2:             pix = (left_bar || right_bar || top_bar || mid_bar || bot_bar) && !corner; // B
                4'd4, 4'd5, 4'd7: pix = left_bar || ((top_bar || bot_bar) && lx < 16) || (right_bar && !top_bar && !bot_bar); // D
                4'd8:             pix = (lx >= 8 && lx < 12); // I
                4'd9, 4'd10:      pix = left_bar || right_bar || (ly == lx[4:2] + 2); // N
                default:          pix = 0;
            endcase
        end
    end

    // =========================================================================
    // 5. COLOR MIXER (Clean Aesthetic)
    // =========================================================================
    // Starfield: Moving XOR pattern
    wire star = (pix_x[4:0] ^ frame_cnt[4:0]) == (pix_y[4:0] ^ frame_cnt[9:5]);
    wire scanline = pix_y[0];

    // Final color selection: White text over deep blue/purple stars
    wire [1:0] r = video_active ? (pix ? 2'b11 : (star ? 2'b10 : 2'b00)) : 2'b00;
    wire [1:0] g = video_active ? (pix ? 2'b11 : 2'b00) : 2'b00;
    wire [1:0] b = video_active ? (pix ? 2'b11 : (scanline ? 2'b10 : 2'b01)) : 2'b00;

    // Output Packing for TinyVGA PMOD
    assign uo_out = {hsync, b[0], g[0], r[0], vsync, b[1], g[1], r[1]};

    // =========================================================================
    // 6. LINTER TRAP
    // =========================================================================
    wire _unused = &{ui_in, uio_in, ena, frame_cnt[15:10], ry[9:6]};

endmodule

// =========================================================================
// VGA TIMING GENERATOR (640x480 @ 60Hz)
// =========================================================================
module hvsync_generator(
    input clk,
    input reset,
    output reg hsync,
    output reg vsync,
    output reg display_on,
    output reg [9:0] hpos,
    output reg [9:0] vpos
);
  localparam H_DISPLAY = 640;
  localparam H_BACK    = 48;
  localparam H_FRONT   = 16;
  localparam H_SYNC    = 96;
  localparam V_DISPLAY = 480;
  localparam V_BACK    = 33;
  localparam V_FRONT   = 10;
  localparam V_SYNC    = 2;

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      hpos <= 0; vpos <= 0; hsync <= 0; vsync <= 0; display_on <= 0;
    end else begin
      if (hpos < 799) hpos <= hpos + 1;
      else begin
        hpos <= 0;
        if (vpos < 524) vpos <= vpos + 1; else vpos <= 0;
      end
      hsync <= !((hpos >= H_DISPLAY + H_FRONT) && (hpos < H_DISPLAY + H_FRONT + H_SYNC));
      vsync <= !((vpos >= V_DISPLAY + V_FRONT) && (vpos < V_DISPLAY + V_FRONT + V_SYNC));
      display_on <= (hpos < H_DISPLAY) && (vpos < V_DISPLAY);
    end
  end
endmodule