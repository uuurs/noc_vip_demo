// noc_env_cfg.sv - Environment configuration (config database)
`include "noc_macros.svh"

class noc_env_cfg extends uvm_object;

    // NOC topology
    string                          noc_name;
    int                             num_masters;
    int                             num_slaves;
    int                             data_width;
    int                             addr_width;
    real                            clk_period_ps;

    // Config arrays
    noc_slave_config                slaves[`NOC_MAX_SLAVES];
    noc_master_config               masters[`NOC_MAX_MASTERS];

    // Feature flags
    bit                             enable_checker;
    bit                             enable_logger;
    bit                             enable_coverage;
    bit                             enable_perf_monitor;
    bit                             enable_error_injection;
    bit                             enable_backdoor;
    bit                             enable_scoreboard;

    // Logger config
    int                             log_format;       // NOC_LOG_FMT_CSV / JSON / BOTH
    string                          log_csv_path;
    string                          log_json_path;
    string                          violation_log_path;

    // Coverage config
    bit                             cov_burst_en;
    bit                             cov_len_en;
    bit                             cov_size_en;
    bit                             cov_resp_en;
    bit                             cov_slave_en;
    bit                             cov_outstanding_en;
    bit                             cov_cross_en;

    // Performance config
    int                             perf_sample_window;
    int                             perf_report_interval_ns;

    // Sim config
    int                             global_timeout_ns;

    `uvm_object_utils_begin(noc_env_cfg)
        `uvm_field_string(noc_name, UVM_DEFAULT)
        `uvm_field_int(num_masters, UVM_DEFAULT)
        `uvm_field_int(num_slaves, UVM_DEFAULT)
        `uvm_field_int(data_width, UVM_DEFAULT)
        `uvm_field_int(addr_width, UVM_DEFAULT)
        `uvm_field_int(enable_checker, UVM_DEFAULT)
        `uvm_field_int(enable_logger, UVM_DEFAULT)
        `uvm_field_int(enable_coverage, UVM_DEFAULT)
        `uvm_field_int(enable_perf_monitor, UVM_DEFAULT)
        `uvm_field_int(enable_error_injection, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "noc_env_cfg");
        super.new(name);
        noc_name                  = "unnamed_noc";
        num_masters               = 0;
        num_slaves                = 0;
        data_width                = 64;
        addr_width                = 40;
        clk_period_ps             = 1000.0;
        enable_checker            = 1'b1;
        enable_logger             = 1'b1;
        enable_coverage           = 1'b1;
        enable_perf_monitor       = 1'b1;
        enable_error_injection    = 1'b0;
        enable_backdoor           = 1'b0;
        enable_scoreboard         = 1'b1;
        log_format                = `NOC_LOG_FMT_BOTH;
        log_csv_path              = "logs/noc_txn_log.csv";
        log_json_path             = "logs/noc_txn_log.json";
        violation_log_path        = "logs/noc_violations.log";
        cov_burst_en              = 1'b1;
        cov_len_en                = 1'b1;
        cov_size_en               = 1'b1;
        cov_resp_en               = 1'b1;
        cov_slave_en              = 1'b1;
        cov_outstanding_en        = 1'b1;
        cov_cross_en              = 1'b1;
        perf_sample_window        = 1000;
        perf_report_interval_ns   = 100000;
        global_timeout_ns         = 10000000;
    endfunction

    // =====================================================
    // Slave lookup utilities
    // =====================================================
    function noc_slave_config find_slave_by_addr(bit [63:0] addr);
        for (int i = 0; i < num_slaves; i++) begin
            if (slaves[i] != null && slaves[i].is_in_range(addr))
                return slaves[i];
        end
        return null;
    endfunction

    function noc_slave_config find_slave_by_name(string name);
        for (int i = 0; i < num_slaves; i++) begin
            if (slaves[i] != null && slaves[i].name == name)
                return slaves[i];
        end
        return null;
    endfunction

    function noc_slave_config find_slave_by_id(int id);
        for (int i = 0; i < num_slaves; i++) begin
            if (slaves[i] != null && slaves[i].slave_id == id)
                return slaves[i];
        end
        return null;
    endfunction

    function noc_master_config find_master_by_id(int id);
        for (int i = 0; i < num_masters; i++) begin
            if (masters[i] != null && masters[i].master_id == id)
                return masters[i];
        end
        return null;
    endfunction

    // Get list of valid address ranges for constraint generation
    function void get_valid_addr_ranges(ref bit [63:0] ranges[$][$]);
        for (int i = 0; i < num_slaves; i++) begin
            if (slaves[i] != null) begin
                bit [63:0] r[2];
                r[0] = slaves[i].base_addr;
                r[1] = slaves[i].base_addr + slaves[i].addr_range - 1;
                ranges.push_back(r);
            end
        end
    endfunction

    // Validate config consistency
    function bit validate();
        bit ok = 1'b1;
        if (num_masters == 0) begin
            `uvm_error("NOC_CFG", "No masters configured")
            ok = 1'b0;
        end
        if (num_slaves == 0) begin
            `uvm_error("NOC_CFG", "No slaves configured")
            ok = 1'b0;
        end
        // Check overlapping slave ranges
        for (int i = 0; i < num_slaves; i++) begin
            for (int j = i+1; j < num_slaves; j++) begin
                if (slaves[i] != null && slaves[j] != null) begin
                    if ((slaves[i].base_addr < slaves[j].get_end_addr()) &&
                        (slaves[j].base_addr < slaves[i].get_end_addr())) begin
                        `uvm_error("NOC_CFG", $sformatf(
                            "Overlapping slave ranges: %s [0x%0h:0x%0h] and %s [0x%0h:0x%0h]",
                            slaves[i].name, slaves[i].base_addr, slaves[i].get_end_addr(),
                            slaves[j].name, slaves[j].base_addr, slaves[j].get_end_addr()))
                        ok = 1'b0;
                    end
                end
            end
        end
        return ok;
    endfunction

    function string convert2string();
        string s;
        s = $sformatf("NOC: %s  Masters:%0d  Slaves:%0d  Data:%0d  Addr:%0d  Clk:%0.0fps\n",
                       noc_name, num_masters, num_slaves, data_width, addr_width, clk_period_ps);
        for (int i = 0; i < num_slaves; i++) begin
            if (slaves[i] != null) begin
                s = {s, $sformatf("  Slave[%0d]: %-16s 0x%0h-0x%0h proto=[%s] outstanding=%0d\n",
                       i, slaves[i].name, slaves[i].base_addr, slaves[i].get_end_addr(),
                       slaves[i].get_all_protocols_str(), slaves[i].outstanding_capability)};
            end
        end
        for (int i = 0; i < num_masters; i++) begin
            if (masters[i] != null) begin
                s = {s, $sformatf("  Master[%0d]: %-16s %s\n",
                       i, masters[i].name, masters[i].protocol)};
            end
        end
        return s;
    endfunction
endclass
