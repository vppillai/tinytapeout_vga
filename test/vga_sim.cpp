// VGA Frame Capture using Verilator
// Fast native simulation for GIF generation

#include <verilated.h>
#include "Vtt_um_embeddedinn_vga.h"
#include <cstdio>
#include <cstdint>
#include <vector>

// VGA timing constants
const int H_DISPLAY = 640;
const int H_FRONT = 16;
const int H_SYNC = 96;
const int H_BACK = 48;
const int H_TOTAL = 800;

const int V_DISPLAY = 480;
const int V_FRONT = 10;
const int V_SYNC = 2;
const int V_BACK = 33;
const int V_TOTAL = 525;

// Configuration
// Full X-axis bounce cycle: 100→280 (180) + 280→10 (270) + 10→100 (90) = 540 frames
// This captures complete left-right bouncing motion (~9 seconds at 60Hz)
const int NUM_FRAMES = 540;
const int FRAME_SKIP = 0;   // No skipping - capture every frame

// 2-bit to 8-bit color mapping
const uint8_t COLOR_MAP[] = {0, 85, 170, 255};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    auto* dut = new Vtt_um_embeddedinn_vga;

    // Output file
    FILE* outfile = fopen("vga_frames.bin", "wb");
    if (!outfile) {
        fprintf(stderr, "Error: Cannot create output file\n");
        return 1;
    }

    // Write header
    uint32_t header[3] = {NUM_FRAMES, H_DISPLAY, V_DISPLAY};
    fwrite(header, sizeof(uint32_t), 3, outfile);

    // Initialize
    dut->clk = 0;
    dut->rst_n = 0;
    dut->ena = 1;
    dut->ui_in = 0;
    dut->uio_in = 0;

    // Reset
    for (int i = 0; i < 40; i++) {
        dut->clk = !dut->clk;
        dut->eval();
    }
    dut->rst_n = 1;

    printf("Capturing %d frames at %dx%d...\n", NUM_FRAMES, H_DISPLAY, V_DISPLAY);

    std::vector<uint8_t> frame_data;
    frame_data.reserve(H_DISPLAY * V_DISPLAY * 3);

    for (int frame = 0; frame < NUM_FRAMES; frame++) {
        printf("  Frame %d/%d\r", frame + 1, NUM_FRAMES);
        fflush(stdout);

        frame_data.clear();

        // Wait for vsync falling edge
        while ((dut->uo_out & 0x08) == 0) { dut->clk = !dut->clk; dut->eval(); dut->clk = !dut->clk; dut->eval(); }
        while ((dut->uo_out & 0x08) != 0) { dut->clk = !dut->clk; dut->eval(); dut->clk = !dut->clk; dut->eval(); }

        // Wait for vsync to end
        while ((dut->uo_out & 0x08) == 0) { dut->clk = !dut->clk; dut->eval(); dut->clk = !dut->clk; dut->eval(); }

        // Wait V_BACK lines
        for (int i = 0; i < H_TOTAL * V_BACK; i++) {
            dut->clk = !dut->clk; dut->eval();
            dut->clk = !dut->clk; dut->eval();
        }

        // Capture active video
        for (int y = 0; y < V_DISPLAY; y++) {
            // Wait for hsync falling edge
            while ((dut->uo_out & 0x80) != 0) { dut->clk = !dut->clk; dut->eval(); dut->clk = !dut->clk; dut->eval(); }
            while ((dut->uo_out & 0x80) == 0) { dut->clk = !dut->clk; dut->eval(); dut->clk = !dut->clk; dut->eval(); }

            // Wait H_BACK
            for (int i = 0; i < H_BACK; i++) {
                dut->clk = !dut->clk; dut->eval();
                dut->clk = !dut->clk; dut->eval();
            }

            // Capture pixels
            for (int x = 0; x < H_DISPLAY; x++) {
                uint8_t val = dut->uo_out;
                // uo_out = {hsync, b[0], g[0], r[0], vsync, b[1], g[1], r[1]}
                //            7      6     5     4      3      2     1     0
                uint8_t r = ((val >> 0) & 1) << 1 | ((val >> 4) & 1);  // {r[1], r[0]}
                uint8_t g = ((val >> 1) & 1) << 1 | ((val >> 5) & 1);  // {g[1], g[0]}
                uint8_t b = ((val >> 2) & 1) << 1 | ((val >> 6) & 1);  // {b[1], b[0]}

                frame_data.push_back(COLOR_MAP[r]);
                frame_data.push_back(COLOR_MAP[g]);
                frame_data.push_back(COLOR_MAP[b]);

                dut->clk = !dut->clk; dut->eval();
                dut->clk = !dut->clk; dut->eval();
            }
        }

        fwrite(frame_data.data(), 1, frame_data.size(), outfile);

        // Skip frames (if configured)
        if (FRAME_SKIP > 0) {
            for (int skip = 0; skip < FRAME_SKIP; skip++) {
                while ((dut->uo_out & 0x08) == 0) { dut->clk = !dut->clk; dut->eval(); dut->clk = !dut->clk; dut->eval(); }
                while ((dut->uo_out & 0x08) != 0) { dut->clk = !dut->clk; dut->eval(); dut->clk = !dut->clk; dut->eval(); }
            }
        }
    }

    printf("\nDone! Saved to vga_frames.bin\n");

    fclose(outfile);
    delete dut;

    return 0;
}
