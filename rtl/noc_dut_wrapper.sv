// noc_dut_wrapper.sv - DUT wrapper interface for NOC testbench connectivity
interface noc_dut_if;
    logic clk;
    logic rst_n;

    // AXI4 Master interface (placeholder - connect to actual DUT)
    logic [3:0]  axi_awid;
    logic [63:0] axi_awaddr;
    logic [7:0]  axi_awlen;
    logic [2:0]  axi_awsize;
    logic [1:0]  axi_awburst;
    logic        axi_awvalid;
    logic        axi_awready;
    logic [63:0] axi_wdata;
    logic [7:0]  axi_wstrb;
    logic        axi_wlast;
    logic        axi_wvalid;
    logic        axi_wready;
    logic [3:0]  axi_bid;
    logic [1:0]  axi_bresp;
    logic        axi_bvalid;
    logic        axi_bready;
    logic [3:0]  axi_arid;
    logic [63:0] axi_araddr;
    logic [7:0]  axi_arlen;
    logic [2:0]  axi_arsize;
    logic [1:0]  axi_arburst;
    logic        axi_arvalid;
    logic        axi_arready;
    logic [3:0]  axi_rid;
    logic [63:0] axi_rdata;
    logic [1:0]  axi_rresp;
    logic        axi_rlast;
    logic        axi_rvalid;
    logic        axi_rready;

    // AHB-Lite Master interface
    logic [63:0] ahb_haddr;
    logic [1:0]  ahb_htrans;
    logic [2:0]  ahb_hsize;
    logic [2:0]  ahb_hburst;
    logic        ahb_hwrite;
    logic [63:0] ahb_hwdata;
    logic [63:0] ahb_hrdata;
    logic        ahb_hready;
    logic        ahb_hresp;

    // APB4 Master interface
    logic [63:0] apb_paddr;
    logic        apb_psel;
    logic        apb_penable;
    logic        apb_pwrite;
    logic [31:0] apb_pwdata;
    logic [31:0] apb_prdata;
    logic        apb_pready;
    logic        apb_pslverr;

    // Avalon-MM Master interface
    logic [63:0] avm_address;
    logic [7:0]  avm_burstcount;
    logic [7:0]  avm_byteenable;
    logic        avm_read;
    logic        avm_write;
    logic [63:0] avm_writedata;
    logic [63:0] avm_readdata;
    logic        avm_waitrequest;
    logic        avm_readdatavalid;

    // Clocking blocks
    default clocking cb @(posedge clk);
    endclocking

endinterface

module noc_dut_wrapper (
    input  logic clk,
    input  logic rst_n
);
    // DUT placeholder - In real integration, instantiate the actual NOC RTL here
    // The SVT VIP agents connect to the DUT signal-level interfaces

    noc_dut_if vif();
    assign vif.clk   = clk;
    assign vif.rst_n = rst_n;

    // Default tie-offs (overridden when connected to actual DUT)
    assign vif.axi_awaddr = 64'h0;
    assign vif.axi_awlen = 8'h0;
    assign vif.axi_awsize = 3'h0;
    assign vif.axi_awburst = 2'h0;
    assign vif.axi_awvalid = 1'b0;
    assign vif.axi_wdata = 64'h0;
    assign vif.axi_wstrb = 8'h0;
    assign vif.axi_wlast = 1'b0;
    assign vif.axi_wvalid = 1'b0;
    assign vif.axi_bready = 1'b1;
    assign vif.axi_araddr = 64'h0;
    assign vif.axi_arlen = 8'h0;
    assign vif.axi_arsize = 3'h0;
    assign vif.axi_arburst = 2'h0;
    assign vif.axi_arvalid = 1'b0;
    assign vif.axi_rready = 1'b1;

    assign vif.ahb_haddr = 64'h0;
    assign vif.ahb_htrans = 2'h0;
    assign vif.ahb_hsize = 3'h0;
    assign vif.ahb_hburst = 3'h0;
    assign vif.ahb_hwrite = 1'b0;
    assign vif.ahb_hwdata = 64'h0;

    assign vif.apb_paddr = 64'h0;
    assign vif.apb_psel = 1'b0;
    assign vif.apb_penable = 1'b0;
    assign vif.apb_pwrite = 1'b0;
    assign vif.apb_pwdata = 32'h0;

    assign vif.avm_address = 64'h0;
    assign vif.avm_burstcount = 8'h0;
    assign vif.avm_byteenable = 8'h0;
    assign vif.avm_read = 1'b0;
    assign vif.avm_write = 1'b0;
    assign vif.avm_writedata = 64'h0;

endmodule
