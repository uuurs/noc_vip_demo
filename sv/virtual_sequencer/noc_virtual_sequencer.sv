// noc_virtual_sequencer.sv - Coordinates multi-master traffic via access matrix
class noc_virtual_sequencer extends uvm_sequencer;

    `uvm_component_utils(noc_virtual_sequencer)

    // Handles to each master's unified sequencer
    noc_unified_sequencer   m_master_seqr[`NOC_MAX_MASTERS];

    noc_env_cfg             m_cfg;
    int                     m_num_masters;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(noc_env_cfg)::get(this, "", "noc_env_cfg", m_cfg))
            `uvm_fatal("NOC_VSEQR", "Failed to get noc_env_cfg from config_db")
        m_num_masters = m_cfg.num_masters;
    endfunction

    // Execute a single transaction through a specific master
    // The caller specifies master_id; virtual sequencer validates access rights
    task execute_single(noc_unified_transaction txn);
        noc_slave_config slave_cfg;
        noc_master_config mst_cfg;

        // Step 1: Look up slave by address
        slave_cfg = m_cfg.find_slave_by_addr(txn.addr);
        if (slave_cfg == null) begin
            txn.resp  = noc_unified_transaction::RESP_DECERR;
            txn.end_time = $realtime;
            `uvm_warning("NOC_VSEQR", $sformatf("No slave mapped to addr=0x%0h", txn.addr))
            return;
        end

        // Step 2: If master_id is already set by caller, use it directly
        if (txn.master_id >= 0 && txn.master_id < m_num_masters) begin
            mst_cfg = m_cfg.find_master_by_id(txn.master_id);
            if (mst_cfg == null || !mst_cfg.active) begin
                txn.resp = noc_unified_transaction::RESP_DECERR;
                `uvm_warning("NOC_VSEQR", $sformatf("Master[%0d] not found or inactive", txn.master_id))
                return;
            end
        end else begin
            // Step 3: Auto-select first master that can access this slave
            mst_cfg = find_first_accessible_master(slave_cfg);
            if (mst_cfg == null) begin
                txn.resp = noc_unified_transaction::RESP_DECERR;
                `uvm_warning("NOC_VSEQR", $sformatf("No master can access slave '%s' at 0x%0h",
                    slave_cfg.name, txn.addr))
                return;
            end
            txn.master_id = mst_cfg.master_id;
        end

        // Step 4: Verify access via access matrix
        if (!mst_cfg.can_access_slave(slave_cfg)) begin
            txn.resp = noc_unified_transaction::RESP_DECERR;
            `uvm_error("NOC_VSEQR", $sformatf(
                "Access denied: Master[%0d] '%s' cannot access Slave '%s' (addr=0x%0h). Check access matrix.",
                mst_cfg.master_id, mst_cfg.name, slave_cfg.name, txn.addr))
            return;
        end

        // Step 5: Execute
        txn.slave_id   = slave_cfg.slave_id;
        txn.slave_name = slave_cfg.name;
        txn.protocol   = map_proto_str_to_enum(mst_cfg.protocol);
        txn.start_time = $realtime;

        if (m_master_seqr[mst_cfg.master_id] != null) begin
            m_master_seqr[mst_cfg.master_id].wait_for_grant(txn);
        end

        txn.end_time = $realtime;
        `uvm_info("NOC_VSEQR", $sformatf("Routed: M[%0d]%s -> S[%0d]%s addr=0x%0h",
            mst_cfg.master_id, mst_cfg.name,
            slave_cfg.slave_id, slave_cfg.name, txn.addr), UVM_HIGH)
    endtask

    // Find the first master (in ID order) that can access a given slave
    function noc_master_config find_first_accessible_master(noc_slave_config slv);
        for (int i = 0; i < m_num_masters; i++) begin
            noc_master_config mst = m_cfg.find_master_by_id(i);
            if (mst != null && mst.active && mst.can_access_slave(slv))
                return mst;
        end
        return null;
    endfunction

    // Map protocol string to enum for unified transaction
    function noc_unified_transaction::protocol_e map_proto_str_to_enum(string p);
        case (p)
            "AXI4":      return noc_unified_transaction::NOC_AXI4;
            "AXI4Lite":  return noc_unified_transaction::NOC_AXILITE;
            "AHBLite":   return noc_unified_transaction::NOC_AHBLITE;
            "APB4":      return noc_unified_transaction::NOC_APB4;
            "AvalonMM":  return noc_unified_transaction::NOC_AVALON_MM;
            default:     return noc_unified_transaction::NOC_AXI4;
        endcase
    endfunction

    // Execute a list of transactions in parallel across masters
    task execute_parallel(noc_unified_transaction txns[$]);
        fork
            foreach (txns[i])
                execute_single(txns[i]);
        join
    endtask

    // =====================================================
    // Batch operations for auto-generated tests
    // =====================================================

    // Master traversal: one master visits all its accessible slaves
    task execute_master_traverse(int master_id, noc_unified_transaction::direction_e dir);
        noc_slave_config slvs[$];
        noc_api_wrapper api = noc_api_wrapper::get();
        bit [1023:0] rdata;

        m_cfg.find_slaves_for_master(master_id, slvs);
        `uvm_info("NOC_VSEQR", $sformatf("Master[%0d] traversal: %0d slaves", master_id, slvs.size()), UVM_LOW)

        foreach (slvs[i]) begin
            if (dir == noc_unified_transaction::NOC_READ) begin
                api.noc_read(.addr(slvs[i].base_addr), .data(rdata), .size(2), .master_id(master_id));
            end else begin
                api.noc_write(.addr(slvs[i].base_addr), .data(1024'h0), .size(2), .master_id(master_id));
            end
            `uvm_info("NOC_VSEQR", $sformatf("  M[%0d] -> %s: 0x%0h OK", master_id, slvs[i].name, slvs[i].base_addr), UVM_MEDIUM)
        end
    endtask

    // Conflict test: all eligible masters access the same slave concurrently
    task execute_conflict(int slave_id, noc_unified_transaction::direction_e dir);
        noc_slave_config slv = m_cfg.find_slave_by_id(slave_id);
        noc_master_config msts[$];

        if (slv == null) begin
            `uvm_error("NOC_VSEQR", $sformatf("Slave[%0d] not found", slave_id))
            return;
        end

        m_cfg.find_masters_for_slave(slv.name, msts);
        `uvm_info("NOC_VSEQR", $sformatf("Conflict test: %0d masters -> slave '%s'", msts.size(), slv.name), UVM_LOW)

        if (msts.size() == 0) begin
            `uvm_info("NOC_VSEQR", $sformatf("No masters can access slave '%s', skipping", slv.name), UVM_MEDIUM)
            return;
        end

        // Fork parallel: each master issues a transaction to the same slave
        begin
            noc_api_wrapper api = noc_api_wrapper::get();
            bit [1023:0] rdata;
            fork
                foreach (msts[i]) begin
                    automatic int mid = msts[i].master_id;
                    automatic bit [63:0] taddr = slv.base_addr + (mid * 64);
                    if (dir == noc_unified_transaction::NOC_READ) begin
                        api.noc_read(.addr(taddr), .data(rdata), .size(2), .master_id(mid));
                    end else begin
                        api.noc_write(.addr(taddr), .data(1024'h0), .size(2), .master_id(mid));
                    end
                    `uvm_info("NOC_VSEQR", $sformatf("  M[%0d]%s -> %s: concurrent access", mid, msts[i].name, slv.name), UVM_MEDIUM)
                end
            join
        end
    endtask
endclass
