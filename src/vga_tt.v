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
    // 3. ANIMATION TIMERS (Interactive Control)
    // =========================================================================
    reg [15:0] frame_cnt;
    reg [8:0] tx, ty;
    reg x_dir, y_dir;
    reg vsync_prev;

    // Detect vsync rising edge (synchronized to clk)
    wire vsync_rising = vsync && !vsync_prev;

    // Speed control via ui_in[1:0]
    wire [1:0] speed_sel = ui_in[1:0];
    wire move_en = (speed_sel == 2'b11) ? 1'b0 : // Pause
                   (speed_sel == 2'b10) ? frame_cnt[0] : // Slow
                   1'b1; // Normal and Fast (Fast handled by double increment)
    
    wire [1:0] step = (speed_sel == 2'b01) ? 2'd2 : 2'd1;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            vsync_prev <= 0;
            frame_cnt <= 0;
            tx <= 100; ty <= 100;
            x_dir <= 0; y_dir <= 0;
        end else begin
            vsync_prev <= vsync;

            if (vsync_rising) begin
                frame_cnt <= frame_cnt + step;

                if (move_en) begin
                    // Linear Movement
                    tx <= x_dir ? tx - step : tx + step;
                    ty <= y_dir ? ty - step : ty + step;

                    // Screen boundary checks for 640x480
                    if (tx >= 280) x_dir <= 1; else if (tx <= 10) x_dir <= 0;
                    if (ty >= 420) y_dir <= 1; else if (ty <= 10) y_dir <= 0;
                end
            end
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
    // 5. COLOR MIXER (Interactive Aesthetic)
    // =========================================================================
    // Parallax Starfield: Two layers with different speeds
    wire star_f = ((pix_x[5:0] ^ frame_cnt[5:0]) == (pix_y[5:0] ^ frame_cnt[11:6]));
    wire star_s = ((pix_x[5:0] ^ frame_cnt[7:2]) == (pix_y[5:0] ^ frame_cnt[13:8]));
    
    // Scanline effect (toggleable via ui_in[4])
    wire scanline = pix_y[0] && !ui_in[4];

    // Color Palettes via ui_in[3:2]
    reg [1:0] pal_r, pal_g, pal_b;
    always @(*) begin
        case (ui_in[3:2])
            2'b01: begin // Cyberpunk (Pink/Cyan)
                pal_r = star_f ? 2'b11 : 2'b10;
                pal_g = star_s ? 2'b11 : 2'b00;
                pal_b = 2'b11;
            end
            2'b10: begin // Forest (Green/Emerald)
                pal_r = 2'b00;
                pal_g = star_f ? 2'b11 : (star_s ? 2'b10 : 2'b01);
                pal_b = star_s ? 2'b01 : 2'b00;
            end
            2'b11: begin // Monochrome (Grayscale)
                pal_r = star_f ? 2'b11 : (star_s ? 2'b10 : 2'b01);
                pal_g = pal_r;
                pal_b = pal_r;
            end
            default: begin // Classic (Deep Blue/Purple)
                pal_r = star_f ? 2'b01 : 2'b00;
                pal_g = star_s ? 2'b01 : 2'b00;
                pal_b = star_f ? 2'b10 : (star_s ? 2'b11 : (scanline ? 2'b01 : 2'b00));
            end
        endcase
    end

    // Color Cycling for Text (Subtle shifts)
    wire [1:0] text_r = frame_cnt[8] ? 2'b11 : 2'b10;
    wire [1:0] text_g = frame_cnt[9] ? 2'b11 : 2'b01;
    wire [1:0] text_b = 2'b11;

    // Final color selection
    wire [1:0] r = video_active ? (pix ? text_r : pal_r) : 2'b00;
    wire [1:0] g = video_active ? (pix ? text_g : pal_g) : 2'b00;
    wire [1:0] b = video_active ? (pix ? text_b : pal_b) : 2'b00;

    // Output Packing for TinyVGA PMOD
    assign uo_out = {hsync, b[0], g[0], r[0], vsync, b[1], g[1], r[1]};

    // =========================================================================
    // 6. LINTER TRAP
    // =========================================================================
    wire _unused = &{ui_in[7:5], uio_in, ena, frame_cnt[15:14], ry[9:6]};

endmodule

// =========================================================================
// VGA TIMING GENERATOR (640x480 @ 60Hz)
// =========================================================================
module hvsync_generator(
    input wire clk,
    input wire reset,
    output reg hsync,
    output reg vsync,
    output reg display_on,
    output reg [9:0] hpos,
    output reg [9:0] vpos
);
  localparam [9:0] H_DISPLAY = 640;
  localparam [9:0] H_FRONT   = 16;
  localparam [9:0] H_SYNC    = 96;
  localparam [9:0] V_DISPLAY = 480;
  localparam [9:0] V_FRONT   = 10;
  localparam [9:0] V_SYNC    = 2;

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