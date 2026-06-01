# vsim.do - Questa Sim compilation and simulation script for noc_vip
# Usage: vsim -c -do vsim.do

# Set UVM home (Questa Sim 2021.1 built-in UVM 1.2)
set UVM_HOME $env(MODEL_TECH)/../verilog_src/uvm-1.2
set QUESTA_ROOT C:/questasim64_2021.1/win64

# Create libraries
vlib work
vlib noc_vip_lib
vmap noc_vip_lib noc_vip_lib

# UVM compilation
vlog +acc=rnb -sv \
    ${UVM_HOME}/src/uvm_pkg.sv \
    +incdir+${UVM_HOME}/src

# NOC VIP compilation
vlog +acc=rnb -sv \
    +incdir+../sv \
    ../sv/noc_pkg.sv \
    ../tb/noc_tb_pkg.sv

# DUT wrapper
vlog +acc=rnb -sv \
    ../rtl/noc_dut_wrapper.sv

# Testbench top
vlog +acc=rnb -sv \
    ../tb/noc_tb_top.sv

# Optimization
vopt +acc noc_tb_top -o noc_tb_top_opt

# Run simulation
vsim -c noc_tb_top_opt \
    -do "log -r /*; run -all; quit -f" \
    -sv_seed random \
    +UVM_TESTNAME=noc_smoke_test \
    +UVM_VERBOSITY=UVM_MEDIUM

# Coverage (optional)
# vsim -c noc_tb_top_opt \
#     -coverage \
#     -do "coverage save -onexit noc_coverage.ucdb; run -all; quit -f"

# Waveform (GUI mode)
# vsim -gui noc_tb_top_opt \
#     -do "do waveforms.do; run -all"
