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
        noc_api_wrapper api = noc_api_wrapper::get();
        `uvm_info("NOC_OUTSTANDING", "Starting outstanding test...", UVM_LOW)

        for (int i = 0; i < m_cfg.num_slaves; i++) begin
            noc_slave_config slv = m_cfg.slaves[i];
            if (slv == null || slv.outstanding_capability == 0) continue;

            noc_master_config msts[$];
            m_cfg.find_masters_for_slave(slv.name, msts);
            if (msts.size() == 0) continue;

            int mid = msts[0].master_id;
            bit [1023:0] rdata;
            for (int j = 0; j < slv.outstanding_capability + 2; j++) begin
                api.noc_read(.addr(slv.base_addr + (j * 64)), .data(rdata), .size(3), .master_id(mid));
                `uvm_info("NOC_OUTSTANDING", $sformatf("[%s] M[%0d] Outstanding #%0d", slv.name, mid, j), UVM_MEDIUM)
            end
        end

        `uvm_info("NOC_OUTSTANDING", "Outstanding test complete", UVM_LOW)
    endtask
endclass

// =====================================================
// Master Traverse Test: one master visits all slaves it can access
// =====================================================
class noc_master_traverse_sequence extends noc_virtual_sequence_base;
    `uvm_object_utils(noc_master_traverse_sequence)

    int m_master_id;

    function new(string name = "noc_master_traverse_sequence");
        super.new(name);
        m_master_id = 0;
    endfunction

    task body();
        noc_api_wrapper api = noc_api_wrapper::get();
        noc_slave_config slvs[$];
        bit [1023:0] rdata;

        m_cfg.find_slaves_for_master(m_master_id, slvs);
        noc_master_config mst = m_cfg.find_master_by_id(m_master_id);
        string m_name = (mst != null) ? mst.name : $sformatf("M%0d", m_master_id);

        `uvm_info("NOC_MASTER_TRAVERSE", $sformatf("Master[%0d] '%s' traversing %0d slaves", m_master_id, m_name, slvs.size()), UVM_LOW)

        foreach (slvs[i]) begin
            // Write then read
            api.noc_write(.addr(slvs[i].base_addr), .data(1024'hFEED_FACE), .size(2), .master_id(m_master_id));
            api.noc_read(.addr(slvs[i].base_addr), .data(rdata), .size(2), .master_id(m_master_id));
            `uvm_info("NOC_MASTER_TRAVERSE", $sformatf("  M[%0d]%s -> %s [0x%0h-0x%0h] OK",
                m_master_id, m_name, slvs[i].name, slvs[i].base_addr, slvs[i].get_end_addr()), UVM_MEDIUM)
        end

        `uvm_info("NOC_MASTER_TRAVERSE", "Master traverse test complete", UVM_LOW)
    endtask
endclass

// =====================================================
// Conflict Test: all accessible masters access one slave concurrently
// =====================================================
class noc_conflict_test_sequence extends noc_virtual_sequence_base;
    `uvm_object_utils(noc_conflict_test_sequence)

    int m_slave_id;

    function new(string name = "noc_conflict_test_sequence");
        super.new(name);
        m_slave_id = 0;
    endfunction

    task body();
        noc_slave_config slv = m_cfg.find_slave_by_id(m_slave_id);
        noc_master_config msts[$];
        noc_api_wrapper api = noc_api_wrapper::get();
        bit [1023:0] rdata;

        if (slv == null) begin
            `uvm_error("NOC_CONFLICT", $sformatf("Slave[%0d] not found", m_slave_id))
            return;
        end

        m_cfg.find_masters_for_slave(slv.name, msts);
        `uvm_info("NOC_CONFLICT", $sformatf("Conflict test: %0d masters -> slave '%s'", msts.size(), slv.name), UVM_LOW)

        if (msts.size() == 0) begin
            `uvm_info("NOC_CONFLICT", $sformatf("No masters can access slave '%s'", slv.name), UVM_MEDIUM)
            return;
        end

        // Round 1: all masters write to distinct addresses within the same slave
        `uvm_info("NOC_CONFLICT", "  Round 1: Concurrent writes", UVM_MEDIUM)
        fork
            foreach (msts[i]) begin
                automatic noc_master_config m = msts[i];
                automatic bit [63:0] taddr = slv.base_addr + (m.master_id * 128);
                api.noc_write(.addr(taddr), .data({960'h0, 64'h(m.master_id)}), .size(3), .master_id(m.master_id));
                `uvm_info("NOC_CONFLICT", $sformatf("    M[%0d]%s write to 0x%0h", m.master_id, m.name, taddr), UVM_MEDIUM)
            end
        join

        // Round 2: all masters read back concurrently
        `uvm_info("NOC_CONFLICT", "  Round 2: Concurrent reads", UVM_MEDIUM)
        fork
            foreach (msts[i]) begin
                automatic noc_master_config m = msts[i];
                automatic bit [63:0] taddr = slv.base_addr + (m.master_id * 128);
                api.noc_read(.addr(taddr), .data(rdata), .size(3), .master_id(m.master_id));
                `uvm_info("NOC_CONFLICT", $sformatf("    M[%0d]%s read from 0x%0h", m.master_id, m.name, taddr), UVM_MEDIUM)
            end
        join

        // Round 3: mixed R/W to same address range
        `uvm_info("NOC_CONFLICT", "  Round 3: Mixed R/W", UVM_MEDIUM)
        fork
            foreach (msts[i]) begin
                automatic noc_master_config m = msts[i];
                automatic bit [63:0] taddr = slv.base_addr + (m.master_id * 128);
                if (m.master_id % 2 == 0) begin
                    api.noc_write(.addr(taddr), .data(1024'h0), .size(3), .master_id(m.master_id));
                end else begin
                    api.noc_read(.addr(taddr), .data(rdata), .size(3), .master_id(m.master_id));
                end
            end
        join

        `uvm_info("NOC_CONFLICT", "Conflict test complete", UVM_LOW)
    endtask
endclass
