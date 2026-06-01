// noc_virtual_sequence_base.sv - Virtual sequence base class
class noc_virtual_sequence_base extends uvm_sequence;

    `uvm_object_utils(noc_virtual_sequence_base)

    noc_virtual_sequencer  p_sequencer;
    noc_env_cfg            m_cfg;

    function new(string name = "noc_virtual_sequence_base");
        super.new(name);
    endfunction

    task pre_body();
        if (m_cfg == null) begin
            if (!uvm_config_db #(noc_env_cfg)::get(null, get_full_name(), "noc_env_cfg", m_cfg))
                `uvm_info("NOC_VSEQ", "No noc_env_cfg in config_db", UVM_MEDIUM)
        end
        if (!$cast(p_sequencer, get_sequencer())) begin
            `uvm_fatal("NOC_VSEQ", "Virtual sequence must run on noc_virtual_sequencer")
        end
    endtask

    // Convenience: start a sequence on a specific master's sequencer
    task start_on_master(int master_id, noc_base_sequence seq);
        if (master_id >= 0 && master_id < `NOC_MAX_MASTERS &&
            p_sequencer.m_master_seqr[master_id] != null) begin
            seq.start(p_sequencer.m_master_seqr[master_id]);
        end else begin
            `uvm_error("NOC_VSEQ", $sformatf("Invalid master_id=%0d", master_id))
        end
    endtask

    // Parallel traffic: all masters generate random traffic
    task parallel_traffic(int num_txns_per_master = 50);
        noc_random_traffic_sequence seqs[`NOC_MAX_MASTERS];

        for (int i = 0; i < m_cfg.num_masters; i++) begin
            seqs[i] = noc_random_traffic_sequence::type_id::create(
                $sformatf("rand_seq_m%0d", i));
            seqs[i].m_num_txns = num_txns_per_master;
        end

        fork
            for (int i = 0; i < m_cfg.num_masters; i++) begin
                automatic int mid = i;
                seqs[mid].start(p_sequencer.m_master_seqr[mid]);
            end
        join
    endtask
endclass

// =====================================================
// Auto-Generated Test Sequences (template pattern)
// =====================================================

// Legality test: valid + illegal addresses for each slave
class noc_legality_test_sequence extends noc_virtual_sequence_base;
    `uvm_object_utils(noc_legality_test_sequence)

    function new(string name = "noc_legality_test_sequence");
        super.new(name);
    endfunction

    task body();
        noc_api_wrapper api = noc_api_wrapper::get();

        `uvm_info("NOC_LEGALITY", "Starting legality test...", UVM_LOW)

        for (int i = 0; i < m_cfg.num_slaves; i++) begin
            noc_slave_config slv = m_cfg.slaves[i];
            bit [1023:0] data;
            if (slv == null) continue;

            // Valid: base address
            api.noc_read(.addr(slv.base_addr), .data(data));
            `uvm_info("NOC_LEGALITY", $sformatf("[%s] Base addr OK: 0x%0h", slv.name, slv.base_addr), UVM_MEDIUM)

            // Valid: end address
            api.noc_read(.addr(slv.get_end_addr()), .data(data));
            `uvm_info("NOC_LEGALITY", $sformatf("[%s] End addr OK: 0x%0h", slv.name, slv.get_end_addr()), UVM_MEDIUM)

            // Invalid: below range
            if (slv.base_addr > 0) begin
                api.noc_read(.addr(slv.base_addr - 1), .data(data));
                `uvm_info("NOC_LEGALITY", $sformatf("[%s] Below range (expect DECERR): 0x%0h", slv.name, slv.base_addr - 1), UVM_MEDIUM)
            end

            // Invalid: above range
            api.noc_read(.addr(slv.get_end_addr() + 1), .data(data));
            `uvm_info("NOC_LEGALITY", $sformatf("[%s] Above range (expect DECERR): 0x%0h", slv.name, slv.get_end_addr() + 1), UVM_MEDIUM)
        end

        `uvm_info("NOC_LEGALITY", "Legality test complete", UVM_LOW)
    endtask
endclass

// Boundary test: 4KB crossing, range boundary, wrap alignment
class noc_boundary_test_sequence extends noc_virtual_sequence_base;
    `uvm_object_utils(noc_boundary_test_sequence)

    function new(string name = "noc_boundary_test_sequence");
        super.new(name);
    endfunction

    task body();
        noc_api_wrapper api = noc_api_wrapper::get();
        bit [1023:0] data;

        `uvm_info("NOC_BOUNDARY", "Starting boundary test...", UVM_LOW)

        for (int i = 0; i < m_cfg.num_slaves; i++) begin
            noc_slave_config slv = m_cfg.slaves[i];
            if (slv == null) continue;

            // 4KB boundary test: write burst near 4KB boundary
            bit [63:0] near_4kb = {slv.base_addr[63:12], 12'hFF0};
            if (near_4kb < slv.base_addr) near_4kb = slv.base_addr;

            data = 1024'hDEAD_BEEF;
            api.noc_burst_write(.addr(near_4kb), .data('{data}), .len(2), .size(3));
            `uvm_info("NOC_BOUNDARY", $sformatf("[%s] 4KB boundary test at 0x%0h", slv.name, near_4kb), UVM_MEDIUM)

            // Range end boundary test
            bit [63:0] end_near = slv.get_end_addr() - 32;
            if (end_near >= slv.base_addr) begin
                api.noc_burst_read(.addr(end_near), .data(data), .len(3), .size(3));
                `uvm_info("NOC_BOUNDARY", $sformatf("[%s] Range boundary test at 0x%0h", slv.name, end_near), UVM_MEDIUM)
            end

            // Wrap boundary test
            api.noc_burst_read(.addr(slv.base_addr & ~64'hF), .data(data), .len(3), .size(2),
                .burst(noc_unified_transaction::WRAP));
            `uvm_info("NOC_BOUNDARY", $sformatf("[%s] Wrap boundary test", slv.name), UVM_MEDIUM)
        end

        `uvm_info("NOC_BOUNDARY", "Boundary test complete", UVM_LOW)
    endtask
endclass

// Burst test: all burst types, lengths, sizes
class noc_burst_test_sequence extends noc_virtual_sequence_base;
    `uvm_object_utils(noc_burst_test_sequence)

    function new(string name = "noc_burst_test_sequence");
        super.new(name);
    endfunction

    task body();
        noc_api_wrapper api = noc_api_wrapper::get();
        bit [1023:0] data;

        `uvm_info("NOC_BURST", "Starting burst test...", UVM_LOW)

        for (int i = 0; i < m_cfg.num_slaves; i++) begin
            noc_slave_config slv = m_cfg.slaves[i];
            if (slv == null) continue;

            // Test all supported burst types
            foreach (slv.supported_burst[j]) begin
                noc_unified_transaction::burst_type_e bt;
                case (slv.supported_burst[j])
                    "FIXED": bt = noc_unified_transaction::FIXED;
                    "INCR":  bt = noc_unified_transaction::INCR;
                    "WRAP":  bt = noc_unified_transaction::WRAP;
                    default: bt = noc_unified_transaction::INCR;
                endcase

                api.noc_burst_read(.addr(slv.base_addr), .data(data), .len(slv.max_len), .size(slv.max_size),
                    .burst(bt));
                `uvm_info("NOC_BURST", $sformatf("[%s] Burst=%s len=%0d size=%0d",
                    slv.name, slv.supported_burst[j], slv.max_len, slv.max_size), UVM_MEDIUM)
            end
        end

        `uvm_info("NOC_BURST", "Burst test complete", UVM_LOW)
    endtask
endclass

// Outstanding test: push to max outstanding
class noc_outstanding_test_sequence extends noc_virtual_sequence_base;
    `uvm_object_utils(noc_outstanding_test_sequence)

    function new(string name = "noc_outstanding_test_sequence");
        super.new(name);
    endfunction

    task body();
        `uvm_info("NOC_OUTSTANDING", "Starting outstanding test...", UVM_LOW)

        for (int i = 0; i < m_cfg.num_slaves; i++) begin
            noc_slave_config slv = m_cfg.slaves[i];
            if (slv == null || slv.outstanding_capability == 0) continue;

            // Generate parallel reads up to max outstanding
            for (int j = 0; j < slv.outstanding_capability + 2; j++) begin
                noc_read_sequence seq = noc_read_sequence::type_id::create();
                seq.target_addr = slv.base_addr + (j * 64);
                start_on_master(0, seq);
                `uvm_info("NOC_OUTSTANDING", $sformatf("[%s] Outstanding #%0d", slv.name, j), UVM_MEDIUM)
            end
        end

        `uvm_info("NOC_OUTSTANDING", "Outstanding test complete", UVM_LOW)
    endtask
endclass
