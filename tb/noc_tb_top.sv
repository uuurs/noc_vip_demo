// noc_tb_top.sv - Top-level NOC testbench
module noc_tb_top;

    import uvm_pkg::*;
    import noc_pkg::*;

    // Clock and reset
    bit clk;
    bit rst_n;

    // Clock generation
    initial begin
        clk = 0;
        forever #5000 clk = ~clk;  // 10ns period (100MHz)
    end

    // Reset
    initial begin
        rst_n = 0;
        #50000 rst_n = 1;  // release after 50ns
    end

    // DUT instantiation (placeholder for actual NOC RTL)
    noc_dut_wrapper dut (
        .clk   (clk),
        .rst_n (rst_n)
    );

    // UVM configuration
    initial begin
        uvm_config_db #(virtual noc_dut_if)::set(null, "*", "dut_vif", dut.vif);
        uvm_config_int::set(null, "*", "recording_detail", UVM_FULL);
    end

    // Start test
    initial begin
        string test_name;
        if ($value$plusargs("UVM_TESTNAME=%s", test_name))
            run_test(test_name);
        else
            run_test("noc_smoke_test");
    end

    // Timeout watchdog
    initial begin
        #100000000ns;  // 100ms
        `uvm_fatal("TB_TIMEOUT", "Global timeout reached!")
    end

endmodule
