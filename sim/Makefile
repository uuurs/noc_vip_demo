# noc_vip Makefile - Questa Sim batch flow
QUESTA  = C:/questasim64_2021.1/win64
VLOG    = $(QUESTA)/vlog
VSIM    = $(QUESTA)/vsim
VOPT    = $(QUESTA)/vopt

UVM_HOME = $(QUESTA)/../verilog_src/uvm-1.2
SV_DIR   = ../sv
TB_DIR   = ../tb
RTL_DIR  = ../rtl
LOG_DIR  = ../logs

# Test list
TESTS = noc_smoke_test noc_legality_test noc_boundary_test noc_burst_test noc_random_traffic_test

# Default test
TEST ?= noc_smoke_test
SEED ?= random
VERB  ?= UVM_MEDIUM
GUI   ?= 0

all: compile run

compile:
	-mkdir -p $(LOG_DIR)
	-vlib work
	-vmap work work
	$(VLOG) +acc=rnb -sv $(UVM_HOME)/src/uvm_pkg.sv +incdir+$(UVM_HOME)/src
	$(VLOG) +acc=rnb -sv +incdir+$(SV_DIR) $(SV_DIR)/noc_pkg.sv $(TB_DIR)/noc_tb_pkg.sv
	$(VLOG) +acc=rnb -sv $(RTL_DIR)/noc_dut_wrapper.sv
	$(VLOG) +acc=rnb -sv $(TB_DIR)/noc_tb_top.sv
	$(VOPT) +acc noc_tb_top -o noc_tb_top_opt

run:
ifeq ($(GUI), 1)
	$(VSIM) -gui noc_tb_top_opt \
		-do "do waveforms.do; run -all" \
		-sv_seed $(SEED) \
		+UVM_TESTNAME=$(TEST) \
		+UVM_VERBOSITY=$(VERB) \
		-l $(LOG_DIR)/$(TEST).log
else
	$(VSIM) -c noc_tb_top_opt \
		-do "run -all; quit -f" \
		-sv_seed $(SEED) \
		+UVM_TESTNAME=$(TEST) \
		+UVM_VERBOSITY=$(VERB) \
		-l $(LOG_DIR)/$(TEST).log
endif

regress:
	@for test in $(TESTS); do \
		echo "=== Running $$test ==="; \
		$(MAKE) run TEST=$$test SEED=$$RANDOM; \
	done

coverage:
	$(VLOG) +acc=rnb -sv +incdir+$(SV_DIR) $(SV_DIR)/noc_pkg.sv $(TB_DIR)/noc_tb_pkg.sv
	$(VLOG) +acc=rnb -sv $(RTL_DIR)/noc_dut_wrapper.sv
	$(VLOG) +acc=rnb -sv $(TB_DIR)/noc_tb_top.sv
	$(VOPT) +acc +cover noc_tb_top -o noc_tb_top_cov
	$(VSIM) -c noc_tb_top_cov \
		-coverage \
		-do "coverage save -onexit noc_coverage.ucdb; run -all; quit -f" \
		+UVM_TESTNAME=$(TEST) \
		-l $(LOG_DIR)/$(TEST)_cov.log

clean:
	-rm -rf work noc_vip_lib transcript *.log *.ucdb
	-rm -rf $(LOG_DIR)/*

wave:
	$(MAKE) run GUI=1

.PHONY: all compile run regress coverage clean wave
