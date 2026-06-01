// noc_test_base.sv - Base test class for NOC verification
class noc_test_base extends uvm_test;

    `uvm_component_utils(noc_test_base)

    noc_env         m_env;
    noc_env_cfg     m_cfg;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Create default config
        m_cfg = noc_env_cfg::type_id::create("m_cfg");
        m_cfg.noc_name     = "test_noc";
        m_cfg.num_masters   = 1;
        m_cfg.num_slaves    = 1;
        m_cfg.data_width    = 64;
        m_cfg.addr_width    = 40;
        m_cfg.clk_period_ps = 1000.0;

        // Configure one default slave
        m_cfg.slaves[0] = noc_slave_config::type_id::create("default_slave");
        m_cfg.slaves[0].name       = "default_slave";
        m_cfg.slaves[0].base_addr  = 64'hA000_0000;
        m_cfg.slaves[0].addr_range = 64'h0001_0000;
        m_cfg.slaves[0].slave_id   = 0;
        m_cfg.slaves[0].supported_protocols = {"AXI4"};
        m_cfg.slaves[0].supported_burst     = {"FIXED", "INCR", "WRAP"};
        m_cfg.slaves[0].max_len     = 15;
        m_cfg.slaves[0].max_size    = 7;
        m_cfg.slaves[0].outstanding_capability = 16;

        // Configure one default master
        m_cfg.masters[0] = noc_master_config::type_id::create("default_master");
        m_cfg.masters[0].name      = "default_master";
        m_cfg.masters[0].master_id = 0;
        m_cfg.masters[0].protocol  = "AXI4";

        // Default feature flags
        m_cfg.enable_checker    = 1'b1;
        m_cfg.enable_logger     = 1'b1;
        m_cfg.enable_coverage   = 1'b1;
        m_cfg.enable_perf_monitor = 1'b1;
        m_cfg.enable_scoreboard = 1'b1;

        // Place config in DB
        uvm_config_db #(noc_env_cfg)::set(this, "*", "noc_env_cfg", m_cfg);

        // Build env
        m_env = noc_env::type_id::create("m_env", this);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
    endfunction

    // Helper: load config from JSON (called by derived tests)
    function void load_config_from_json(string json_path);
        // Parses noc_slave_config.json and populates m_cfg
        // In actual implementation, uses JSON parser or Python-generated SV
        `uvm_info("NOC_TEST", $sformatf("Loading config from %s", json_path), UVM_LOW)
        // configure_from_json(json_path, m_cfg);
    endfunction
endclass

// =====================================================
// Concrete Tests
// =====================================================

// Smoke test: single read + write to each slave
class noc_smoke_test extends noc_test_base;

    `uvm_component_utils(noc_smoke_test)

    function new(string name = "noc_smoke_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    task main_phase(uvm_phase phase);
        noc_smoke_vseq vseq = noc_smoke_vseq::type_id::create("vseq");

        phase.raise_objection(this);
        vseq.start(m_env.m_vseqr);
        phase.drop_objection(this);
    endtask
endclass

class noc_smoke_vseq extends noc_virtual_sequence_base;
    `uvm_object_utils(noc_smoke_vseq)

    task body();
        noc_api_wrapper api = noc_api_wrapper::get();
        bit [1023:0] rdata;

        `uvm_info("NOC_SMOKE", "=== NOC Smoke Test ===", UVM_LOW)

        // Write then read each slave
        for (int i = 0; i < m_cfg.num_slaves; i++) begin
            noc_slave_config slv = m_cfg.slaves[i];
            if (slv == null) continue;

            // Find first master that can access this slave
            noc_master_config msts[$];
            m_cfg.find_masters_for_slave(slv.name, msts);
            if (msts.size() == 0) continue;
            int mid = msts[0].master_id;

            api.noc_write(.addr(slv.base_addr), .data(1024'hCAFE_BABE_DEAD_BEEF), .size(3), .master_id(mid));
            `uvm_info("NOC_SMOKE", $sformatf("[%s] M[%0d]%s Write: 0x%0h", slv.name, mid, msts[0].name, slv.base_addr), UVM_MEDIUM)

            api.noc_read(.addr(slv.base_addr), .data(rdata), .size(3), .master_id(mid));
            `uvm_info("NOC_SMOKE", $sformatf("[%s] M[%0d]%s Read:  0x%0h = 0x%0h", slv.name, mid, msts[0].name, slv.base_addr, rdata), UVM_MEDIUM)
        end

        `uvm_info("NOC_SMOKE", "Smoke test PASSED", UVM_LOW)
    endtask
endclass

// Legality test
class noc_legality_test extends noc_test_base;
    `uvm_component_utils(noc_legality_test)

    function new(string name = "noc_legality_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    task main_phase(uvm_phase phase);
        noc_legality_test_sequence seq = noc_legality_test_sequence::type_id::create("seq");
        phase.raise_objection(this);
        seq.start(m_env.m_vseqr);
        phase.drop_objection(this);
    endtask
endclass

// Boundary test
class noc_boundary_test extends noc_test_base;
    `uvm_component_utils(noc_boundary_test)

    function new(string name = "noc_boundary_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    task main_phase(uvm_phase phase);
        noc_boundary_test_sequence seq = noc_boundary_test_sequence::type_id::create("seq");
        phase.raise_objection(this);
        seq.start(m_env.m_vseqr);
        phase.drop_objection(this);
    endtask
endclass

// Burst test
class noc_burst_test extends noc_test_base;
    `uvm_component_utils(noc_burst_test)

    function new(string name = "noc_burst_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    task main_phase(uvm_phase phase);
        noc_burst_test_sequence seq = noc_burst_test_sequence::type_id::create("seq");
        phase.raise_objection(this);
        seq.start(m_env.m_vseqr);
        phase.drop_objection(this);
    endtask
endclass

// Random traffic test
class noc_random_traffic_test extends noc_test_base;
    `uvm_component_utils(noc_random_traffic_test)

    function new(string name = "noc_random_traffic_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    task main_phase(uvm_phase phase);
        noc_virtual_sequence_base vseq = noc_virtual_sequence_base::type_id::create("vseq");
        phase.raise_objection(this);
        vseq.parallel_traffic(.num_txns_per_master(100));
        phase.drop_objection(this);
    endtask
endclass

// =====================================================
// Master Traverse Test: one master visits all its accessible slaves
// =====================================================
class noc_master_traverse_test extends noc_test_base;
    `uvm_component_utils(noc_master_traverse_test)

    int m_traverse_master_id;

    function new(string name = "noc_master_traverse_test", uvm_component parent);
        super.new(name, parent);
        m_traverse_master_id = 1;  // default: DMA engine traverses all slaves
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_config_db #(int)::get(this, "", "traverse_master_id", m_traverse_master_id));
    endfunction

    task main_phase(uvm_phase phase);
        noc_master_traverse_sequence seq = noc_master_traverse_sequence::type_id::create("seq");
        seq.m_master_id = m_traverse_master_id;
        phase.raise_objection(this);
        seq.start(m_env.m_vseqr);
        phase.drop_objection(this);
    endtask
endclass

// =====================================================
// Conflict Test: multiple masters access one slave concurrently
// =====================================================
class noc_conflict_test extends noc_test_base;
    `uvm_component_utils(noc_conflict_test)

    int m_conflict_slave_id;

    function new(string name = "noc_conflict_test", uvm_component parent);
        super.new(name, parent);
        m_conflict_slave_id = 0;  // default: target first slave
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_config_db #(int)::get(this, "", "conflict_slave_id", m_conflict_slave_id));
    endfunction

    task main_phase(uvm_phase phase);
        noc_conflict_test_sequence seq = noc_conflict_test_sequence::type_id::create("seq");
        seq.m_slave_id = m_conflict_slave_id;
        phase.raise_objection(this);
        seq.start(m_env.m_vseqr);
        phase.drop_objection(this);
    endtask
endclass
