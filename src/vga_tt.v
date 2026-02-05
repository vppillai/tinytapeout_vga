`default_nettype none
/* verilator lint_off UNUSED */
/* verilator lint_off WIDTH */

module tt_um_vga_example(
  input  wire [7:0] ui_in,    // Switches
  output wire [7:0] uo_out,   // VGA Pins
  input  wire [7:0] uio_in,   // IOs
  output wire [7:0] uio_out,  // IOs
  output wire [7:0] uio_oe,   // IOs
  input  wire       ena,      // Power
  input  wire       clk,      // Clock
  input  wire       rst_n     // Reset
);

  // 1. STANDARD SETUP
  assign uio_out = 0;
  assign uio_oe  = 0;

  // 2. VGA SIGNALS
  wire hsync;
  wire vsync;
  wire video_active;
  wire [9:0] pix_x;
  wire [9:0] pix_y;

  // 3. HOOK UP TO THE HIDDEN LIBRARY
  // We use the simulator's built-in generator so the web canvas updates.
  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n), // Invert reset (Active Low -> Active High)
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(pix_x),
    .vpos(pix_y)
  );

  // =========================================================================
  // 4. THE LIQUID PLASMA ENGINE
  // =========================================================================

  // --- A. ORB MOVEMENT PHYSICS ---
  reg [9:0] orb1_x, orb1_y;
  reg [9:0] orb2_x, orb2_y;

  reg dir1_x, dir1_y;
  reg dir2_x, dir2_y;

  // Initialize for Simulator (prevents black screen start)
  initial begin
      orb1_x = 300; orb1_y = 200;
      orb2_x = 340; orb2_y = 280;
      dir1_x = 1;   dir1_y = 1;
      dir2_x = 0;   dir2_y = 1;
  end

  always @(posedge vsync or negedge rst_n) begin
      if (~rst_n) begin
          orb1_x <= 300; orb1_y <= 200;
          orb2_x <= 340; orb2_y <= 280;
          dir1_x <= 1;   dir1_y <= 1;
          dir2_x <= 0;   dir2_y <= 1;
      end else begin
          // ORB 1 (Speed 2)
          if (dir1_x) begin if (orb1_x >= 630) dir1_x <= 0; else orb1_x <= orb1_x + 2; end
          else        begin if (orb1_x <= 10)  dir1_x <= 1; else orb1_x <= orb1_x - 2; end

          if (dir1_y) begin if (orb1_y >= 470) dir1_y <= 0; else orb1_y <= orb1_y + 2; end
          else        begin if (orb1_y <= 10)  dir1_y <= 1; else orb1_y <= orb1_y - 2; end

          // ORB 2 (Speed 3)
          if (dir2_x) begin if (orb2_x >= 630) dir2_x <= 0; else orb2_x <= orb2_x + 3; end
          else        begin if (orb2_x <= 10)  dir2_x <= 1; else orb2_x <= orb2_x - 3; end

          if (dir2_y) begin if (orb2_y >= 470) dir2_y <= 0; else orb2_y <= orb2_y + 3; end
          else        begin if (orb2_y <= 10)  dir2_y <= 1; else orb2_y <= orb2_y - 3; end
      end
  end

  // --- B. DISTANCE FIELD CALCULATOR ---
  // Approximate Distance Squared: (x-x1)^2 + (y-y1)^2

  wire [9:0] dx1 = (pix_x > orb1_x) ? (pix_x - orb1_x) : (orb1_x - pix_x);
  wire [9:0] dy1 = (pix_y > orb1_y) ? (pix_y - orb1_y) : (orb1_y - pix_y);

  wire [9:0] dx2 = (pix_x > orb2_x) ? (pix_x - orb2_x) : (orb2_x - pix_x);
  wire [9:0] dy2 = (pix_y > orb2_y) ? (pix_y - orb2_y) : (orb2_y - pix_y);

  // Downsample to keep math small (6-bit multiply)
  wire [5:0] small_dx1 = dx1[9:4];
  wire [5:0] small_dy1 = dy1[9:4];
  wire [5:0] small_dx2 = dx2[9:4];
  wire [5:0] small_dy2 = dy2[9:4];

  wire [12:0] dist1 = (small_dx1 * small_dx1) + (small_dy1 * small_dy1);
  wire [12:0] dist2 = (small_dx2 * small_dx2) + (small_dy2 * small_dy2);

  // --- C. INTERFERENCE COMPOSITION ---
  // Average the fields to create merging blobs
  wire [12:0] field = (dist1 + dist2);

  // --- D. COLOR MAPPING ---
  reg [1:0] r, g, b;

  // Use bits [8:5] to create the "Rings" effect
  wire [3:0] palette_idx = field[8:5];

  always @(*) begin
      if (!video_active) begin
          r = 0; g = 0; b = 0;
      end else begin
          // Liquid Palette
          case (palette_idx)
             4'd0:  begin r=3; g=3; b=3; end // White Core
             4'd1:  begin r=3; g=3; b=0; end // Yellow
             4'd2:  begin r=3; g=0; b=0; end // Red
             4'd3:  begin r=2; g=0; b=1; end // Magenta
             4'd4:  begin r=0; g=0; b=3; end // Blue
             4'd5:  begin r=0; g=2; b=3; end // Cyan
             4'd6:  begin r=0; g=3; b=0; end // Green
             4'd7:  begin r=0; g=1; b=0; end // Fade
             default: begin r=0; g=0; b=0; end // Void
          endcase
      end
  end

  // 5. OUTPUT ASSIGNMENT
  assign uo_out = {hsync, b[0], g[0], r[0], vsync, b[1], g[1], r[1]};

endmodule

// PASTE THIS AT THE BOTTOM FOR TAPEOUT
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
