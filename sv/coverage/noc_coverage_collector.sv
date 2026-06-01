// noc_coverage_collector.sv - Functional coverage model for NOC transactions
class noc_coverage_collector extends uvm_subscriber #(noc_unified_transaction);

    `uvm_component_utils(noc_coverage_collector)

    noc_env_cfg     m_cfg;
    int             m_outstanding_cnt;
    int             m_sample_count;
    real            m_coverage_goal;

    // =====================================================
    // Coverage Group
    // =====================================================
    covergroup noc_cg with function sample(noc_unified_transaction txn);
        option.per_instance = 1;
        option.name = "noc_coverage";

        // Burst type
        cp_burst: coverpoint txn.burst iff (m_cfg.cov_burst_en) {
            bins FIXED = {noc_unified_transaction::FIXED};
            bins INCR  = {noc_unified_transaction::INCR};
            bins WRAP  = {noc_unified_transaction::WRAP};
        }

        // Burst length
        cp_len: coverpoint txn.len iff (m_cfg.cov_len_en) {
            bins single       = {0};
            bins short_burst  = {[1:3]};
            bins medium_burst = {[4:7]};
            bins long_burst   = {[8:15]};
            bins max_burst    = {15};
        }

        // Transfer size
        cp_size: coverpoint txn.size iff (m_cfg.cov_size_en) {
            bins byte_8      = {0};
            bins half_16     = {1};
            bins word_32     = {2};
            bins dword_64    = {3};
            bins qword_128   = {4};
            bins dqword_256  = {5};
            bins oqword_512  = {6};
            bins kbit_1024   = {7};
        }

        // Response type
        cp_resp: coverpoint txn.resp iff (m_cfg.cov_resp_en) {
            bins okay        = {noc_unified_transaction::RESP_OKAY};
            bins exokay      = {noc_unified_transaction::RESP_EXOKAY};
            bins slverr      = {noc_unified_transaction::RESP_SLVERR};
            bins decerr      = {noc_unified_transaction::RESP_DECERR};
        }

        // Slave access
        cp_slave: coverpoint txn.slave_id iff (m_cfg.cov_slave_en) {
            bins slaves[] = {[0:m_cfg.num_slaves - 1]};
        }

        // Protocol
        cp_protocol: coverpoint txn.protocol {
            bins axi4      = {noc_unified_transaction::NOC_AXI4};
            bins axilite   = {noc_unified_transaction::NOC_AXILITE};
            bins ahblite   = {noc_unified_transaction::NOC_AHBLITE};
            bins apb4      = {noc_unified_transaction::NOC_APB4};
            bins avalon_mm = {noc_unified_transaction::NOC_AVALON_MM};
        }

        // Direction
        cp_direction: coverpoint txn.direction {
            bins read  = {noc_unified_transaction::NOC_READ};
            bins write = {noc_unified_transaction::NOC_WRITE};
        }

        // Outstanding depth (sampled from monitor)
        cp_outstanding: coverpoint m_outstanding_cnt iff (m_cfg.cov_outstanding_en) {
            bins zero      = {0};
            bins low       = {[1:3]};
            bins medium    = {[4:7]};
            bins high      = {[8:15]};
            bins very_high = {[16:63]};
        }

        // QoS
        cp_qos: coverpoint txn.qos {
            bins default_qos = {0};
            bins low_qos     = {[1:4]};
            bins med_qos     = {[5:8]};
            bins high_qos    = {[9:15]};
        }

        // Cache
        cp_cache: coverpoint txn.cache {
            bins non_cacheable       = {4'b0000};
            bins bufferable          = {4'b0001};
            bins cacheable_wt_nowa   = {4'b0010};
            bins cacheable_wb_nowa   = {4'b0011};
            wildcard bins others     = {4'b????};
        }

        // =====================================================
        // Cross Coverage
        // =====================================================
        crx_burst_len:        cross cp_burst, cp_len       iff (m_cfg.cov_cross_en);
        crx_burst_size:       cross cp_burst, cp_size      iff (m_cfg.cov_cross_en);
        crx_size_len:         cross cp_size, cp_len        iff (m_cfg.cov_cross_en);
        crx_slave_burst:      cross cp_slave, cp_burst     iff (m_cfg.cov_cross_en);
        crx_slave_resp:       cross cp_slave, cp_resp      iff (m_cfg.cov_cross_en);
        crx_slave_size:       cross cp_slave, cp_size      iff (m_cfg.cov_cross_en);
        crx_burst_outstanding: cross cp_burst, cp_outstanding iff (m_cfg.cov_cross_en);
        crx_direction_proto:  cross cp_direction, cp_protocol iff (m_cfg.cov_cross_en);
        crx_slave_direction:  cross cp_slave, cp_direction iff (m_cfg.cov_cross_en);
        crx_protocol_size:    cross cp_protocol, cp_size   iff (m_cfg.cov_cross_en);

    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_outstanding_cnt = 0;
        m_sample_count = 0;
        m_coverage_goal = 95.0;
        noc_cg = new();
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(noc_env_cfg)::get(this, "", "noc_env_cfg", m_cfg))
            `uvm_fatal("NOC_COV", "Failed to get noc_env_cfg from config_db")
    endfunction

    virtual function void write(noc_unified_transaction t);
        m_outstanding_cnt++;  // incremented by input, decremented by response
        if (t.resp != noc_unified_transaction::RESP_OKAY || t.last)
            if (m_outstanding_cnt > 0) m_outstanding_cnt--;

        noc_cg.sample(t);
        m_sample_count++;
    endfunction

    function void report_phase(uvm_phase phase);
        real cov = noc_cg.get_coverage();
        `uvm_info("NOC_COV", $sformatf(
            "Coverage Report: %.2f%% (goal=%.2f%%) | %0d samples | %0d/%0d bins hit",
            cov, m_coverage_goal, m_sample_count,
            noc_cg.get_coverage(noc_cg.get_inst_coverage()),
            0), UVM_LOW)
    endfunction

    function real get_coverage();
        return noc_cg.get_coverage();
    endfunction

    function bit coverage_goal_met();
        return noc_cg.get_coverage() >= m_coverage_goal;
    endfunction
endclass
