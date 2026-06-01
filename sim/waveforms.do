# waveforms.do - Questa Sim waveform configuration for noc_vip
# Add signals to waveform window
add wave -group "Clock & Reset" \
    sim:/noc_tb_top/clk \
    sim:/noc_tb_top/rst_n

add wave -group "AXI4" \
    -radix hex \
    sim:/noc_tb_top/dut/vif/axi_awvalid \
    sim:/noc_tb_top/dut/vif/axi_awready \
    sim:/noc_tb_top/dut/vif/axi_awaddr \
    sim:/noc_tb_top/dut/vif/axi_awlen \
    sim:/noc_tb_top/dut/vif/axi_awsize \
    sim:/noc_tb_top/dut/vif/axi_wvalid \
    sim:/noc_tb_top/dut/vif/axi_wready \
    sim:/noc_tb_top/dut/vif/axi_wdata \
    sim:/noc_tb_top/dut/vif/axi_wlast \
    sim:/noc_tb_top/dut/vif/axi_bvalid \
    sim:/noc_tb_top/dut/vif/axi_bready \
    sim:/noc_tb_top/dut/vif/axi_bresp \
    sim:/noc_tb_top/dut/vif/axi_arvalid \
    sim:/noc_tb_top/dut/vif/axi_arready \
    sim:/noc_tb_top/dut/vif/axi_araddr \
    sim:/noc_tb_top/dut/vif/axi_arlen \
    sim:/noc_tb_top/dut/vif/axi_rvalid \
    sim:/noc_tb_top/dut/vif/axi_rready \
    sim:/noc_tb_top/dut/vif/axi_rdata \
    sim:/noc_tb_top/dut/vif/axi_rlast

add wave -group "AHB-Lite" \
    -radix hex \
    sim:/noc_tb_top/dut/vif/ahb_haddr \
    sim:/noc_tb_top/dut/vif/ahb_htrans \
    sim:/noc_tb_top/dut/vif/ahb_hwrite \
    sim:/noc_tb_top/dut/vif/ahb_hsize \
    sim:/noc_tb_top/dut/vif/ahb_hwdata \
    sim:/noc_tb_top/dut/vif/ahb_hrdata \
    sim:/noc_tb_top/dut/vif/ahb_hready \
    sim:/noc_tb_top/dut/vif/ahb_hresp

add wave -group "APB4" \
    -radix hex \
    sim:/noc_tb_top/dut/vif/apb_paddr \
    sim:/noc_tb_top/dut/vif/apb_psel \
    sim:/noc_tb_top/dut/vif/apb_penable \
    sim:/noc_tb_top/dut/vif/apb_pwrite \
    sim:/noc_tb_top/dut/vif/apb_pwdata \
    sim:/noc_tb_top/dut/vif/apb_prdata \
    sim:/noc_tb_top/dut/vif/apb_pready \
    sim:/noc_tb_top/dut/vif/apb_pslverr

add wave -group "Avalon-MM" \
    -radix hex \
    sim:/noc_tb_top/dut/vif/avm_address \
    sim:/noc_tb_top/dut/vif/avm_burstcount \
    sim:/noc_tb_top/dut/vif/avm_read \
    sim:/noc_tb_top/dut/vif/avm_write \
    sim:/noc_tb_top/dut/vif/avm_writedata \
    sim:/noc_tb_top/dut/vif/avm_readdata \
    sim:/noc_tb_top/dut/vif/avm_waitrequest \
    sim:/noc_tb_top/dut/vif/avm_readdatavalid

# Configure waveform display
configure wave -namecolwidth 250
configure wave -valuecolwidth 150
configure wave -signalnamewidth 1
configure wave -timelineunits ns
