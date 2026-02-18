# Makefile for cocotb simulation
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
SRC_DIR = $(PWD)/../src
PROJECT_SOURCES = vga_tt.v

ifneq ($(GATES),yes)

# RTL simulation:
SIM_BUILD				= sim_build/rtl
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))

else

# Gate level simulation:
SIM_BUILD				= sim_build/gl
COMPILE_ARGS    += -DGL_TEST
COMPILE_ARGS    += -DFUNCTIONAL
COMPILE_ARGS    += -DSIM

# IHP-SG13G2 PDK files for gate level simulation
VERILOG_SOURCES += $(PDK_ROOT)/ihp-sg13g2/libs.ref/sg13g2_io/verilog/sg13g2_io.v
VERILOG_SOURCES += $(PDK_ROOT)/ihp-sg13g2/libs.ref/sg13g2_stdcell/verilog/sg13g2_stdcell.v

# this gets copied in by the GDS action workflow
VERILOG_SOURCES += $(PWD)/gate_level_netlist.v

endif

# Allow sharing configuration between design and testbench via `include`:
COMPILE_ARGS 		+= -I$(SRC_DIR)

# Include the testbench sources:
VERILOG_SOURCES += $(PWD)/tb.v
TOPLEVEL = tb

# COCOTB_TEST_MODULES is the basename of the Python test file
COCOTB_TEST_MODULES = test

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim

# =============================================================================
# Parallel test execution (run with: make -j5 test-parallel)
# =============================================================================
# Groups balanced by estimated wall time. Each group runs in its own
# simulator instance with separate build and results directories.

_g_anim:
	$(MAKE) TESTCASE=test_animation \
		SIM_BUILD=sim_build/g_anim \
		COCOTB_RESULTS_FILE=results_anim.xml

_g_speed:
	$(MAKE) TESTCASE=test_speed_control,test_pause_text_frozen \
		SIM_BUILD=sim_build/g_speed \
		COCOTB_RESULTS_FILE=results_speed.xml

_g_visual:
	$(MAKE) TESTCASE=test_palettes,test_scanline_toggle,test_starfield_variation \
		SIM_BUILD=sim_build/g_visual \
		COCOTB_RESULTS_FILE=results_visual.xml

_g_frame:
	$(MAKE) TESTCASE=test_frame_period,test_blanking_during_vsync,test_active_region_has_color,test_color_values_valid,test_vsync_pulse_width,test_font_at_known_position,test_output_packing_format \
		SIM_BUILD=sim_build/g_frame \
		COCOTB_RESULTS_FILE=results_frame.xml

_g_fast:
	$(MAKE) TESTCASE=test_tt_interface,test_hsync_pulse_width,test_hsync_polarity,test_hsync_period,test_hsync_consistency,test_vsync_polarity,test_blanking_during_hsync,test_reset_recovery,test_consecutive_line_timing \
		SIM_BUILD=sim_build/g_fast \
		COCOTB_RESULTS_FILE=results_fast.xml

test-parallel: _g_anim _g_speed _g_visual _g_frame _g_fast
	@echo "All parallel test groups passed"

.PHONY: test-parallel _g_anim _g_speed _g_visual _g_frame _g_fast
