`timescale 1ns/1ps
`default_nettype none

module vga_tt_tb;

    // DUT signals
    reg  [7:0] ui_in;
    wire [7:0] uo_out;
    reg  [7:0] uio_in;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;
    reg        ena;
    reg        clk;
    reg        rst_n;

    // VGA 640x480 @ 60Hz timing constants (active low sync)
    localparam H_DISPLAY = 640;
    localparam H_FRONT   = 16;
    localparam H_SYNC    = 96;
    localparam H_BACK    = 48;
    localparam H_TOTAL   = 800;

    localparam V_DISPLAY = 480;
    localparam V_FRONT   = 10;
    localparam V_SYNC    = 2;
    localparam V_BACK    = 33;
    localparam V_TOTAL   = 525;

    localparam FRAME_CLOCKS = H_TOTAL * V_TOTAL; // 420000

    // Timing tolerances
    localparam HSYNC_TOL = 1;      // ±1 clock tolerance for hsync
    localparam HPERIOD_TOL = 2;    // ±2 clock tolerance for h period
    localparam VSYNC_TOL = H_TOTAL; // ±1 line tolerance for vsync
    localparam VPERIOD_TOL = H_TOTAL * 2; // ±2 lines for frame

    // Decoded VGA signals
    wire hsync = uo_out[7];
    wire vsync = uo_out[3];
    wire [1:0] r = {uo_out[4], uo_out[0]};
    wire [1:0] g = {uo_out[5], uo_out[1]};
    wire [1:0] b = {uo_out[6], uo_out[2]};

    // Test counters and state
    integer test_num;
    integer test_pass;
    integer test_fail;
    integer i, j;
    integer count;
    integer hsync_low_count, hsync_high_count;
    integer vsync_low_count;
    integer frame_clocks;
    integer non_black_pixels;
    integer black_during_blank;
    integer total_blank_samples;
    integer line_count;
    integer pixel_in_line;
    integer active_line_pixels;
    integer blanking_errors;

    // For multi-frame tests
    reg [5:0] frame1_colors [0:9];
    reg [5:0] frame2_colors [0:9];
    integer color_changes;

    // Instantiate DUT
    tt_um_embeddedinn_vga dut (
        .ui_in   (ui_in),
        .uo_out  (uo_out),
        .uio_in  (uio_in),
        .uio_out (uio_out),
        .uio_oe  (uio_oe),
        .ena     (ena),
        .clk     (clk),
        .rst_n   (rst_n)
    );

    // 25.175 MHz clock (~39.72ns period, using 40ns for simplicity)
    initial clk = 0;
    always #20 clk = ~clk;

    // VCD dump
    initial begin
        $dumpvars(0, vga_tt_tb);
    end

    // Task to wait for hsync falling edge
    task wait_hsync_fall;
        begin
            wait(hsync == 1);
            @(posedge clk);
            wait(hsync == 0);
            @(posedge clk);
        end
    endtask

    // Task to wait for vsync falling edge
    task wait_vsync_fall;
        begin
            wait(vsync == 1);
            @(posedge clk);
            wait(vsync == 0);
            @(posedge clk);
        end
    endtask

    // Task to wait for start of active video (after vsync rising, back porch)
    task wait_active_start;
        begin
            wait(vsync == 0);
            wait(vsync == 1);
            @(posedge clk);
            // Wait for V_BACK lines
            repeat(H_TOTAL * V_BACK) @(posedge clk);
            // Wait for start of line (after hsync)
            wait(hsync == 0);
            wait(hsync == 1);
            @(posedge clk);
            repeat(H_BACK) @(posedge clk);
        end
    endtask

    // Main test sequence
    initial begin
        test_num = 0;
        test_pass = 0;
        test_fail = 0;

        // Initialize
        ui_in  = 8'b0;
        uio_in = 8'b0;
        ena    = 1'b1;
        rst_n  = 1'b0;

        $display("========================================");
        $display("VGA 640x480 @ 60Hz Verification Suite");
        $display("========================================");
        $display("");

        // Apply reset
        repeat(20) @(posedge clk);
        rst_n = 1'b1;
        $display("[%0t] Reset released", $time);
        repeat(5) @(posedge clk);

        // =====================================================================
        // TEST 1: Verify TT interface - uio_out and uio_oe must be 0
        // =====================================================================
        test_num = 1;
        if (uio_out === 8'b0 && uio_oe === 8'b0) begin
            $display("[PASS] TEST %0d: TT interface - uio_out=0, uio_oe=0", test_num);
            test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TEST %0d: TT interface - uio_out=%b, uio_oe=%b (expected 0)", test_num, uio_out, uio_oe);
            test_fail = test_fail + 1;
        end

        // =====================================================================
        // TEST 2: HSYNC pulse width (must be exactly 96 clocks ±1)
        // =====================================================================
        test_num = 2;
        wait_hsync_fall();
        hsync_low_count = 0;
        while (hsync == 0) begin
            @(posedge clk);
            hsync_low_count = hsync_low_count + 1;
        end

        if (hsync_low_count >= H_SYNC - HSYNC_TOL && hsync_low_count <= H_SYNC + HSYNC_TOL) begin
            $display("[PASS] TEST %0d: HSYNC pulse width = %0d clocks (spec: %0d ±%0d)", test_num, hsync_low_count, H_SYNC, HSYNC_TOL);
            test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TEST %0d: HSYNC pulse width = %0d clocks (spec: %0d ±%0d)", test_num, hsync_low_count, H_SYNC, HSYNC_TOL);
            test_fail = test_fail + 1;
        end

        // =====================================================================
        // TEST 3: HSYNC polarity (active LOW for 640x480)
        // =====================================================================
        test_num = 3;
        // HSYNC should be HIGH during active video, LOW during sync
        // We already measured low during sync, verify high otherwise
        wait(hsync == 1);
        repeat(10) @(posedge clk);
        if (hsync == 1) begin
            $display("[PASS] TEST %0d: HSYNC polarity correct (active LOW)", test_num);
            test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TEST %0d: HSYNC polarity incorrect", test_num);
            test_fail = test_fail + 1;
        end

        // =====================================================================
        // TEST 4: HSYNC period (must be exactly 800 clocks ±2)
        // =====================================================================
        test_num = 4;
        // Measure from falling edge to falling edge
        wait_hsync_fall();
        count = 0;
        // Count through high period
        while (hsync == 0) begin
            @(posedge clk);
            count = count + 1;
        end
        while (hsync == 1) begin
            @(posedge clk);
            count = count + 1;
        end
        // Now at next falling edge
        if (count >= H_TOTAL - HPERIOD_TOL && count <= H_TOTAL + HPERIOD_TOL) begin
            $display("[PASS] TEST %0d: HSYNC period = %0d clocks (spec: %0d ±%0d)", test_num, count, H_TOTAL, HPERIOD_TOL);
            test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TEST %0d: HSYNC period = %0d clocks (spec: %0d ±%0d)", test_num, count, H_TOTAL, HPERIOD_TOL);
            test_fail = test_fail + 1;
        end

        // =====================================================================
        // TEST 5: Measure multiple HSYNC periods for consistency
        // =====================================================================
        test_num = 5;
        begin
            integer min_period, max_period, total_period;
            min_period = H_TOTAL + 100;
            max_period = 0;
            total_period = 0;

            for (i = 0; i < 10; i = i + 1) begin
                wait_hsync_fall();
                count = 0;
                while (hsync == 0) begin
                    @(posedge clk);
                    count = count + 1;
                end
                while (hsync == 1) begin
                    @(posedge clk);
                    count = count + 1;
                end
                if (count < min_period) min_period = count;
                if (count > max_period) max_period = count;
                total_period = total_period + count;
            end

            if (max_period - min_period <= 2) begin
                $display("[PASS] TEST %0d: HSYNC consistency over 10 lines (min=%0d, max=%0d, avg=%0d)", test_num, min_period, max_period, total_period/10);
                test_pass = test_pass + 1;
            end else begin
                $display("[FAIL] TEST %0d: HSYNC jitter too high (min=%0d, max=%0d)", test_num, min_period, max_period);
                test_fail = test_fail + 1;
            end
        end

        // =====================================================================
        // TEST 6: VSYNC pulse width (must be 2 lines = 1600 clocks ±1 line)
        // =====================================================================
        test_num = 6;
        $display("[INFO] Waiting for VSYNC...");
        wait_vsync_fall();
        vsync_low_count = 0;
        while (vsync == 0) begin
            @(posedge clk);
            vsync_low_count = vsync_low_count + 1;
        end

        if (vsync_low_count >= (V_SYNC * H_TOTAL) - VSYNC_TOL && vsync_low_count <= (V_SYNC * H_TOTAL) + VSYNC_TOL) begin
            $display("[PASS] TEST %0d: VSYNC pulse width = %0d clocks (spec: %0d ±%0d)", test_num, vsync_low_count, V_SYNC * H_TOTAL, VSYNC_TOL);
            test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TEST %0d: VSYNC pulse width = %0d clocks (spec: %0d ±%0d)", test_num, vsync_low_count, V_SYNC * H_TOTAL, VSYNC_TOL);
            test_fail = test_fail + 1;
        end

        // =====================================================================
        // TEST 7: VSYNC polarity (active LOW for 640x480)
        // =====================================================================
        test_num = 7;
        wait(vsync == 1);
        repeat(100) @(posedge clk);
        if (vsync == 1) begin
            $display("[PASS] TEST %0d: VSYNC polarity correct (active LOW)", test_num);
            test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TEST %0d: VSYNC polarity incorrect", test_num);
            test_fail = test_fail + 1;
        end

        // =====================================================================
        // TEST 8: Full frame period (525 lines × 800 = 420000 clocks)
        // =====================================================================
        test_num = 8;
        $display("[INFO] Measuring full frame period...");
        wait_vsync_fall();
        frame_clocks = 0;
        wait(vsync == 1);
        @(posedge clk);
        while (vsync == 1) begin
            @(posedge clk);
            frame_clocks = frame_clocks + 1;
        end
        // Add vsync low period
        while (vsync == 0) begin
            @(posedge clk);
            frame_clocks = frame_clocks + 1;
        end

        if (frame_clocks >= FRAME_CLOCKS - VPERIOD_TOL && frame_clocks <= FRAME_CLOCKS + VPERIOD_TOL) begin
            $display("[PASS] TEST %0d: Frame period = %0d clocks (spec: %0d ±%0d)", test_num, frame_clocks, FRAME_CLOCKS, VPERIOD_TOL);
            test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TEST %0d: Frame period = %0d clocks (spec: %0d ±%0d)", test_num, frame_clocks, FRAME_CLOCKS, VPERIOD_TOL);
            test_fail = test_fail + 1;
        end

        // =====================================================================
        // TEST 9: Blanking - pixels must be BLACK during HSYNC
        // =====================================================================
        test_num = 9;
        black_during_blank = 0;
        total_blank_samples = 0;

        // Sample during 5 hsync pulses
        for (i = 0; i < 5; i = i + 1) begin
            wait_hsync_fall();
            for (j = 0; j < 20; j = j + 1) begin
                @(posedge clk);
                total_blank_samples = total_blank_samples + 1;
                if (r == 0 && g == 0 && b == 0)
                    black_during_blank = black_during_blank + 1;
            end
        end

        if (black_during_blank == total_blank_samples) begin
            $display("[PASS] TEST %0d: All %0d samples BLACK during HSYNC", test_num, total_blank_samples);
            test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TEST %0d: %0d/%0d samples not BLACK during HSYNC", test_num, total_blank_samples - black_during_blank, total_blank_samples);
            test_fail = test_fail + 1;
        end

        // =====================================================================
        // TEST 10: Blanking - pixels must be BLACK during VSYNC
        // =====================================================================
        test_num = 10;
        black_during_blank = 0;
        total_blank_samples = 0;

        wait_vsync_fall();
        for (i = 0; i < 100; i = i + 1) begin
            @(posedge clk);
            total_blank_samples = total_blank_samples + 1;
            if (r == 0 && g == 0 && b == 0)
                black_during_blank = black_during_blank + 1;
        end

        if (black_during_blank == total_blank_samples) begin
            $display("[PASS] TEST %0d: All %0d samples BLACK during VSYNC", test_num, total_blank_samples);
            test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TEST %0d: %0d/%0d samples not BLACK during VSYNC", test_num, total_blank_samples - black_during_blank, total_blank_samples);
            test_fail = test_fail + 1;
        end

        // =====================================================================
        // TEST 11: Blanking - pixels BLACK during horizontal front porch
        // =====================================================================
        test_num = 11;
        blanking_errors = 0;

        // Wait for active region then check front porch
        wait(hsync == 1);
        repeat(H_BACK + H_DISPLAY + 2) @(posedge clk); // Move to front porch
        for (i = 0; i < H_FRONT - 4; i = i + 1) begin
            @(posedge clk);
            if (r != 0 || g != 0 || b != 0)
                blanking_errors = blanking_errors + 1;
        end

        if (blanking_errors == 0) begin
            $display("[PASS] TEST %0d: Pixels BLACK during H front porch", test_num);
            test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TEST %0d: %0d non-black pixels in H front porch", test_num, blanking_errors);
            test_fail = test_fail + 1;
        end

        // =====================================================================
        // TEST 12: Blanking - pixels BLACK during horizontal back porch
        // =====================================================================
        test_num = 12;
        blanking_errors = 0;

        wait(hsync == 0);
        wait(hsync == 1);
        @(posedge clk);
        // Now in back porch
        for (i = 0; i < H_BACK - 2; i = i + 1) begin
            @(posedge clk);
            if (r != 0 || g != 0 || b != 0)
                blanking_errors = blanking_errors + 1;
        end

        if (blanking_errors == 0) begin
            $display("[PASS] TEST %0d: Pixels BLACK during H back porch", test_num);
            test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TEST %0d: %0d non-black pixels in H back porch", test_num, blanking_errors);
            test_fail = test_fail + 1;
        end

        // =====================================================================
        // TEST 13: Active video region has colored pixels
        // =====================================================================
        test_num = 13;
        $display("[INFO] Checking active region for colored pixels...");

        wait_active_start();
        non_black_pixels = 0;
        active_line_pixels = 0;

        // Sample one full line in active region
        for (i = 0; i < H_DISPLAY; i = i + 1) begin
            @(posedge clk);
            active_line_pixels = active_line_pixels + 1;
            if (r != 0 || g != 0 || b != 0)
                non_black_pixels = non_black_pixels + 1;
        end

        if (non_black_pixels > 50) begin
            $display("[PASS] TEST %0d: Found %0d/%0d colored pixels in active line", test_num, non_black_pixels, active_line_pixels);
            test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TEST %0d: Only %0d/%0d colored pixels (too few)", test_num, non_black_pixels, active_line_pixels);
            test_fail = test_fail + 1;
        end

        // =====================================================================
        // TEST 14: Color values are valid (2-bit RGB, values 0-3)
        // =====================================================================
        test_num = 14;
        begin
            integer invalid_colors;
            invalid_colors = 0;

            wait_active_start();
            for (i = 0; i < 1000; i = i + 1) begin
                @(posedge clk);
                if (r > 3 || g > 3 || b > 3)
                    invalid_colors = invalid_colors + 1;
            end

            if (invalid_colors == 0) begin
                $display("[PASS] TEST %0d: All color values valid (0-3 range)", test_num);
                test_pass = test_pass + 1;
            end else begin
                $display("[FAIL] TEST %0d: %0d invalid color values detected", test_num, invalid_colors);
                test_fail = test_fail + 1;
            end
        end

        // =====================================================================
        // TEST 15: Animation - colors change between frames (orbs moving)
        // =====================================================================
        test_num = 15;
        $display("[INFO] Checking animation across frames...");

        // Orbs move on posedge vsync at speed 2 and 3 pixels/frame
        // Distance field is downsampled by 16, so need ~16+ pixel movement
        // Wait 10 frames = 20-30 pixel movement to ensure visible change

        // Capture colors near orb1 starting position (300,200) in frame 1
        wait_active_start();
        repeat(H_TOTAL * 200 + 300) @(posedge clk); // Line 200, pixel 300
        for (i = 0; i < 10; i = i + 1) begin
            @(posedge clk);
            frame1_colors[i] = {r, g, b};
        end

        // Wait for 10 frames (orbs move 20-30 pixels, >1 quantization step)
        for (i = 0; i < 10; i = i + 1) begin
            wait_vsync_fall();
            wait(vsync == 1);
        end

        // Sample same location
        wait_active_start();
        repeat(H_TOTAL * 200 + 300) @(posedge clk);
        for (i = 0; i < 10; i = i + 1) begin
            @(posedge clk);
            frame2_colors[i] = {r, g, b};
        end

        // Compare frames
        color_changes = 0;
        for (i = 0; i < 10; i = i + 1) begin
            if (frame1_colors[i] != frame2_colors[i])
                color_changes = color_changes + 1;
        end

        if (color_changes > 0) begin
            $display("[PASS] TEST %0d: Animation detected - %0d/10 pixels changed after 10 frames", test_num, color_changes);
            test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TEST %0d: No animation detected - pixels identical after 10 frames", test_num);
            test_fail = test_fail + 1;
        end

        // =====================================================================
        // TEST 16: Reset clears state and restarts correctly
        // =====================================================================
        test_num = 16;
        $display("[INFO] Testing reset behavior...");

        // Assert reset
        rst_n = 0;
        repeat(10) @(posedge clk);

        // Check that sync signals are in known state after reset
        rst_n = 1;
        repeat(5) @(posedge clk);

        // Wait for first hsync and verify timing still correct
        wait_hsync_fall();
        hsync_low_count = 0;
        while (hsync == 0) begin
            @(posedge clk);
            hsync_low_count = hsync_low_count + 1;
        end

        if (hsync_low_count >= H_SYNC - HSYNC_TOL && hsync_low_count <= H_SYNC + HSYNC_TOL) begin
            $display("[PASS] TEST %0d: Timing correct after reset (HSYNC=%0d)", test_num, hsync_low_count);
            test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] TEST %0d: Timing incorrect after reset (HSYNC=%0d)", test_num, hsync_low_count);
            test_fail = test_fail + 1;
        end

        // =====================================================================
        // TEST 17: Multiple consecutive lines have correct timing
        // =====================================================================
        test_num = 17;
        begin
            integer line_errors;
            line_errors = 0;

            for (i = 0; i < 50; i = i + 1) begin
                wait_hsync_fall();
                count = 0;
                // Count full period: low + high
                while (hsync == 0) begin
                    @(posedge clk);
                    count = count + 1;
                    if (count > H_TOTAL + 100) begin
                        line_errors = line_errors + 1;
                        i = 50; // Exit loop
                    end
                end
                while (hsync == 1) begin
                    @(posedge clk);
                    count = count + 1;
                    if (count > H_TOTAL + 100) begin
                        line_errors = line_errors + 1;
                        i = 50; // Exit loop
                    end
                end
                if (count < H_TOTAL - HPERIOD_TOL || count > H_TOTAL + HPERIOD_TOL)
                    line_errors = line_errors + 1;
            end

            if (line_errors == 0) begin
                $display("[PASS] TEST %0d: 50 consecutive lines have correct timing", test_num);
                test_pass = test_pass + 1;
            end else begin
                $display("[FAIL] TEST %0d: %0d lines with incorrect timing", test_num, line_errors);
                test_fail = test_fail + 1;
            end
        end

        // =====================================================================
        // SUMMARY
        // =====================================================================
        $display("");
        $display("========================================");
        $display("VGA VERIFICATION SUMMARY");
        $display("========================================");
        $display("Tests passed: %0d / %0d", test_pass, test_pass + test_fail);
        $display("Tests failed: %0d / %0d", test_fail, test_pass + test_fail);
        $display("========================================");

        if (test_fail == 0) begin
            $display("*** ALL TESTS PASSED ***");
            $display("VGA output verified for 640x480 @ 60Hz");
        end else begin
            $display("*** SOME TESTS FAILED ***");
            $display("Review failures above");
        end
        $display("========================================");

        $finish;
    end

    // Timeout watchdog
    initial begin
        #500_000_000; // 500ms timeout (enough for ~30 frames at 60Hz)
        $display("");
        $display("[ERROR] Simulation timeout after 500ms!");
        $display("========================================");
        $finish;
    end

endmodule
