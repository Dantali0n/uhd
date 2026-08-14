#
# Copyright 2015 Ettus Research LLC
#

# Define BASE_DIR to point to the "top" dir
BASE_DIR = $(abspath ../../../top)
# Include viv_sim_preamble after defining BASE_DIR
include $(BASE_DIR)/../tools/make/viv_design_builder.mak

#-------------------------------------------------
# Design Specific
#-------------------------------------------------
ifndef PRODUCT
PRODUCT=X310
endif

ARCH=$(XIL_ARCH_${PRODUCT})
PART_ID=$(XIL_PART_ID_${PRODUCT})

# Include makefiles and sources for the DUT and its dependencies
include $(LIB_DIR)/control/Makefile.srcs
include $(LIB_DIR)/fifo/Makefile.srcs
include $(LIB_DIR)/timing/Makefile.srcs
include $(LIB_DIR)/packet_proc/Makefile.srcs
include $(LIB_DIR)/dsp/Makefile.srcs
include $(LIB_DIR)/axi/Makefile.srcs
include $(BASE_DIR)/x300/coregen_dsp/Makefile.srcs

DESIGN_SRCS += $(abspath \
$(FIFO_SRCS) \
$(CONTROL_LIB_SRCS) \
$(TIMING_SRCS) \
$(PACKET_PROC_SRCS) \
$(DSP_SRCS) \
$(AXI_SRCS) \
$(COREGEN_DSP_SRCS) \
)

TOP_MODULE = radio

# DESIGN_SRCS and VERILOG_DEFS must be defined
.DEFAULT_GOAL := netlist
netlist: .prereqs $(DESIGN_SRCS)
	$(call BUILD_VIVADO_DESIGN,$(abspath ./build.tcl),$(TOP_MODULE),$(PART_ID))

clean:
	@rm -rf build
	@rm -rf build-ip

.PHONY: netlist clean